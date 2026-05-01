# SMS Intelligence Overview

PocketFlow's SMS Intelligence Engine automatically processes SMS messages from financial institutions, extracts structured transaction data, and maintains accurate financial records with minimal user intervention.

## What is SMS Intelligence?

SMS Intelligence is a comprehensive system that:

- **Reads** SMS messages from financial institutions
- **Classifies** messages by type (transaction, balance update, payment reminder)
- **Extracts** structured data (amount, merchant, account, date)
- **Resolves** transactions to the correct accounts
- **Detects** transfers between accounts to avoid double-counting
- **Identifies** recurring patterns (subscriptions, salaries, EMIs)
- **Learns** from user corrections to improve accuracy

## Key Capabilities

### 1. Automatic Transaction Detection

The system automatically identifies financial SMS messages and extracts:
- **Transaction amount** (supports multiple currencies)
- **Merchant/sender name**
- **Account identifier** (last 4 digits, account name, etc.)
- **Transaction date and time**
- **Transaction type** (debit/credit)

### 2. Smart Account Matching

Matches transactions to accounts using:
- Account identifier patterns (e.g., "****1234")
- Institution name recognition
- SMS sender ID patterns
- Historical transaction patterns
- Machine learning confidence scoring

### 3. Transfer Detection

Prevents double-counting of transfers by:
- Matching debit-credit pairs across accounts
- Analyzing amount and timing patterns
- Identifying common transfer keywords
- Cross-referencing account relationships

### 4. Recurring Pattern Recognition

Automatically detects:
- **Subscriptions**: Netflix, Spotify, gym memberships
- **Salaries**: Monthly or bi-weekly income
- **EMIs**: Loan payments with consistent amounts
- **Bills**: Utilities, rent, insurance

### 5. Continuous Learning

The system improves over time by:
- Learning from user corrections
- Building SMS template patterns
- Refining confidence scores
- Adapting to new message formats

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       SMS Data Source                            │
│              (Android SMS Inbox - Read-Only)                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    1. INGESTION LAYER                            │
│  • SMS Reader • Deduplication • Privacy Filter                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                 2. CLASSIFICATION LAYER                          │
│  • Financial SMS Detection • Type Classification                 │
│  • Transaction/Transfer/Balance/Reminder                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              3. ENTITY EXTRACTION LAYER                          │
│  • Amount • Merchant • Account • Institution • Date              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│           4. ACCOUNT RESOLUTION ENGINE                           │
│  • Pattern Matching • Confidence Scoring                         │
│  • Auto-Create Accounts (if high confidence)                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│         5. TRANSFER DETECTION ENGINE                             │
│  • Debit-Credit Pair Matching • Cross-Account Analysis           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│       6. RECURRING PATTERN DETECTION                             │
│  • Frequency Analysis • Amount Pattern Recognition               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│            7. STORAGE & USER REVIEW                              │
│  • Store Transaction • Queue Low-Confidence Items                │
│  • User Feedback Loop                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
SMS → Privacy Filter → Financial Detection → Classification 
  → Entity Extraction → Account Resolution → Transfer Detection 
  → Recurring Detection → Storage → User Review → Learning
```

## Privacy & Security

### Privacy-First Design

- **No Cloud Processing**: All SMS processing happens locally
- **OTP Filtering**: OTPs and verification codes are never stored
- **Password Protection**: Any password-related SMS is filtered out
- **Local Storage**: All data stays on your device
- **No Tracking**: No analytics or usage tracking

### What Gets Stored

- Financial transaction details only
- Merchant names and amounts
- Account identifiers (last 4 digits only)
- Transaction categories and dates

### What's Never Stored

- Complete account numbers
- CVV/PIN codes
- OTP codes
- Login credentials
- Personal messages
- Non-financial SMS

## Supported SMS Types

### Transaction Messages
```
✅ "Your A/c XX1234 debited by Rs.500.00 on 15-Apr-26 at Amazon.in"
✅ "Your HDFC Card ending 5678 credited with Rs.10000.00 salary"
✅ "Spent Rs.299 at Netflix using Card ending 9876"
```

### Balance Updates
```
✅ "Your account XX1234 balance is Rs.5000.00"
✅ "Available credit limit: Rs.45000.00"
```

### Payment Reminders
```
✅ "Credit card payment of Rs.5000 due on 20-Apr-26"
✅ "Your loan EMI of Rs.2500 is due tomorrow"
```

### Transfers
```
✅ "Rs.1000 transferred from Savings XX1234 to XX5678"
✅ "UPI-Dr Rs.500 sent to user@bank"
```

## Confidence Scoring

Each transaction receives a confidence score (0.0 - 1.0):

- **0.9 - 1.0**: High confidence - Auto-accept
- **0.7 - 0.89**: Medium confidence - Auto-accept with review flag
- **< 0.7**: Low confidence - Requires user confirmation

Factors affecting confidence:
- Pattern match strength
- Account resolution clarity
- Amount format consistency
- Known merchant recognition
- Historical pattern alignment

## Learning System

The system continuously improves by:

1. **User Corrections**: When you fix a transaction, the system learns
2. **Pattern Building**: Creates SMS templates from confirmed matches
3. **Confidence Adjustment**: Refines scoring based on accuracy
4. **Template Learning**: Builds institution-specific patterns

## Quick Start

See detailed guides for:
- [Classification](classification.md) - How SMS messages are classified
- [Entity Extraction](entity-extraction.md) - Parsing transaction details
- [Account Resolution](account-resolution.md) - Matching transactions to accounts
- [Transfer Detection](transfer-detection.md) - Identifying transfers
- [Recurring Patterns](recurring-patterns.md) - Subscription detection

## Technical Implementation

The SMS Intelligence Engine is implemented across several services:

- **SMSPipelineExecutor**: Orchestrates the entire pipeline
- **SMSClassifier**: Determines message type
- **EntityExtractor**: Parses transaction details
- **AccountResolver**: Matches to accounts
- **TransferDetector**: Identifies transfer pairs
- **RecurringDetector**: Finds patterns
- **FeedbackLearner**: Learns from corrections

See [Architecture Overview](../../architecture/overview.md) for implementation details.

## Performance

- **Processing Time**: < 100ms per SMS message
- **Accuracy**: 95%+ for common bank formats
- **Memory**: Lightweight, minimal battery impact
- **Offline**: Works completely offline

## Supported Regions

### India
- Major banks (HDFC, ICICI, SBI, Axis, etc.)
- UPI transactions
- Credit cards
- Digital wallets (Paytm, PhonePe, etc.)

### United States
- Major banks (Chase, Bank of America, Wells Fargo, etc.)
- Credit cards (Visa, Mastercard, Amex)
- Digital payment platforms (Venmo, Zelle, Cash App)

### Extensibility
New bank formats can be added through:
- SMS template patterns
- User feedback learning
- Community contributions

---

*For implementation details, see the technical guides in this section.*
