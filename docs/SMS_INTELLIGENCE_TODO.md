# 📋 SMS Intelligence Engine - Implementation TODO

**Project:** SMS-First Personal Finance Intelligence Engine  
**Status:** 🟡 In Progress  
**Started:** April 18, 2026  
**Reference Doc:** [SMS_INTELLIGENCE_ENGINE_DESIGN.md](docs/SMS_INTELLIGENCE_ENGINE_DESIGN.md)

---

## 🎯 Implementation Progress

**Overall Progress:** 9/67 tasks (13.4%)
**Last Updated:** April 18, 2026

### Phase Status
- ✅ Phase 0: Planning & Documentation (COMPLETE)
- ✅ Phase 1: Foundation (9/10) - **90% COMPLETE**
- ⏳ Phase 2: Core Intelligence (0/12)
- ⏳ Phase 3: Advanced Detection (0/12)
- ⏳ Phase 4: Learning System (0/10)
- ⏳ Phase 5: Intelligence Layer (0/11)
- ⏳ Phase 6: Region-Specific Enhancements (0/12)

---

## ✅ Phase 0: Planning & Documentation (COMPLETE)

- [x] Technical design document created
- [x] Architecture diagrams defined
- [x] Data models specified
- [x] Database schema designed
- [x] Implementation phases planned
- [x] Success metrics defined

---

## ✅ Phase 1: Foundation (Week 1-2) - 90% COMPLETE

### Database Schema Migration (Priority: HIGH)

- [x] **1.1** Create migration script for database version 12 ✅ COMPLETED
  - [x] Add `account_candidates` table
  - [x] Add `pending_actions` table
  - [x] Add `recurring_patterns` table
  - [x] Add `sms_templates` table
  - [x] Add `transfer_pairs` table
  - [x] Add `merchant_mappings` table
  - Location: `lib/db/database.dart`
  - ✅ Completed: Database v12 migration with all tables and indexes

- [x] **1.2** Update Account model with new fields ✅ COMPLETED
  - [x] Add `source` field (enum: manual, sms_auto, sms_confirmed, import)
  - [x] Add `confidenceScore` field
  - [x] Add `requiresConfirmation` field
  - [x] Add `createdFromSmsDate` field
  - [x] Update serialization methods
  - Location: `lib/models/account.dart`
  - ✅ Completed: Account model enhanced with SMS intelligence fields

- [x] **1.3** Update Transaction model with new fields ✅ COMPLETED
  - [x] Add `smsId` field for deduplication
  - [x] Add `extractedIdentifier` field
  - [x] Add `extractedInstitution` field
  - [x] Add `linkedTransactionId` field
  - [x] Add `transferReference` field
  - [x] Add `recurringGroupId` field
  - [x] Add `isRecurringCandidate` field
  - [x] Update serialization methods
  - Location: `lib/models/transaction.dart`
  - ✅ Completed: Transaction model enhanced with SMS tracking fields

- [x] **1.4** Create new data models ✅ COMPLETED
  - [x] Create `PendingAction` model
  - [x] Create `AccountCandidate` model
  - [x] Create `RecurringPattern` model
  - [x] Create `SmsTemplate` model
  - [x] Create `TransferPair` model
  - [x] Create supporting enums and types
  - Location: `lib/models/`
  - ✅ Completed: All 5 new models created with full serialization

### Privacy & Security (Priority: HIGH)

- [x] **1.5** Implement Privacy Guard ✅ COMPLETED
  - [x] Create `PrivacyGuard` class
  - [x] Add OTP detection patterns
  - [x] Add password/PIN detection patterns
  - [x] Add SSN/Aadhaar detection
  - [x] Add full card number detection
  - [x] Implement sanitization methods
  - [x] Add data retention policy enforcement
  - Location: `lib/services/privacy_guard.dart`
  - ✅ Completed: Comprehensive privacy filtering with US & India support

### SMS Ingestion (Priority: HIGH)

- [x] **1.6** Enhance SMS Ingestion Service ✅ COMPLETED
  - [x] Create `RawSmsMessage` model
  - [x] Implement privacy filtering
  - [x] Add deduplication logic
  - [x] Add SMS ID tracking
  - [x] Integrate with PrivacyGuard
  - [x] Add bulk processing support
  - Location: `lib/services/sms_intelligence_integration.dart`
  - ✅ Completed: Full SMS intelligence integration with pipeline orchestration

### Classification Layer (Priority: MEDIUM)

- [x] **1.7** Create SMS Classification Service ✅ COMPLETED
  - [x] Create `SmsClassification` model
  - [x] Define `SmsType` enum
  - [x] Implement financial sender detection
  - [x] Implement transaction type classification
  - [x] Add transfer detection
  - [x] Add balance update detection
  - [x] Add confidence scoring
  - Location: `lib/services/sms_classification_service.dart`
  - ✅ Completed: Multi-type SMS classification with confidence scoring

### Entity Extraction (Priority: MEDIUM)

- [x] **1.8** Create Entity Extraction Service ✅ COMPLETED
  - [x] Create `ExtractedEntities` model
  - [x] Implement multi-currency amount extraction
  - [x] Implement account identifier extraction (last4, UPI, etc.)
  - [x] Implement institution name extraction
  - [x] Implement merchant extraction
  - [x] Implement balance extraction
  - [x] Implement reference number extraction
  - [x] Add US bank patterns
  - [x] Add Indian bank patterns
  - Location: `lib/services/entity_extraction_service.dart`
  - ✅ Completed: Comprehensive entity extraction with US & India support

### Testing (Priority: MEDIUM)

- [ ] **1.9** Create unit tests for Phase 1
  - [ ] Test privacy filtering
  - [ ] Test SMS classification
  - [ ] Test entity extraction
  - [ ] Test amount parsing (US formats)
  - [ ] Test amount parsing (Indian formats)
  - Location: `test/services/`
  - Estimated Time: 2 hours

- [ ] **1.10** Integration testing
  - [ ] Test database migrations
  - [ ] Test model serialization
  - [ ] Test privacy guard with real SMS samples
  - Estimated Time: 2 hours

**Phase 1 Total Estimated Time:** 23 hours

---

## ⏳ Phase 2: Core Intelligence (Week 3-4)

### Account Resolution Engine (Priority: HIGH)

- [ ] **2.1** Create Account Resolution Engine
  - [ ] Create `AccountResolution` result model
  - [ ] Implement exact identifier matching
  - [ ] Implement institution + partial matching
  - [ ] Implement SMS keyword matching
  - [ ] Implement historical pattern matching
  - [ ] Account candidate creation logic
  - [ ] Confidence scoring algorithm
  - Location: `lib/services/account_resolution_engine.dart`
  - Estimated Time: 4 hours

- [ ] **2.2** Create Account Candidate Manager
  - [ ] Database CRUD operations
  - [ ] Duplicate detection
  - [ ] Merge candidate logic
  - [ ] Auto-promotion to account
  - Location: `lib/services/account_candidate_manager.dart`
  - Estimated Time: 3 hours

### Pending Action System (Priority: HIGH)

- [ ] **2.3** Create Pending Action Service
  - [ ] Database CRUD operations
  - [ ] Action creation methods by type
  - [ ] Priority management
  - [ ] Resolution tracking
  - [ ] User feedback collection
  - Location: `lib/services/pending_action_service.dart`
  - Estimated Time: 3 hours

- [ ] **2.4** Implement SMS Pipeline Executor
  - [ ] Create `SmsPipelineExecutor` class
  - [ ] Integrate all layers (ingestion → classification → extraction → resolution)
  - [ ] Error handling and graceful degradation
  - [ ] Transaction creation with confidence scoring
  - [ ] Auto pending action creation
  - Location: `lib/services/sms_pipeline_executor.dart`
  - Estimated Time: 4 hours

### Confidence Scoring System (Priority: MEDIUM)

- [ ] **2.5** Create Confidence Scoring Service
  - [ ] Account match confidence calculation
  - [ ] Transaction extraction confidence
  - [ ] Transfer detection confidence
  - [ ] Recurring pattern confidence
  - [ ] Threshold definitions
  - Location: `lib/services/confidence_scoring.dart`
  - Estimated Time: 2 hours

### UI Components (Priority: HIGH)

- [ ] **2.6** Create Pending Actions Screen
  - [ ] Action list view
  - [ ] Filter by type/priority
  - [ ] Action detail view
  - [ ] Resolve/dismiss actions
  - [ ] Feedback collection UI
  - Location: `lib/screens/pending_actions_screen.dart`
  - Estimated Time: 5 hours

- [ ] **2.7** Create Account Candidate Review Screen
  - [ ] Candidate list view
  - [ ] Candidate details
  - [ ] Confirm as new account
  - [ ] Merge with existing account
  - [ ] Reject candidate
  - [ ] Bulk actions
  - Location: `lib/screens/account_candidate_screen.dart`
  - Estimated Time: 4 hours

- [ ] **2.8** Update Transaction List UI
  - [ ] Add confidence indicator
  - [ ] Add source badge
  - [ ] Add review flag indicator
  - [ ] Filter by needs_review
  - Location: `lib/screens/transactions/transactions_screen.dart`
  - Estimated Time: 2 hours

- [ ] **2.9** Update SMS Settings UI
  - [ ] Add auto-import toggle
  - [ ] Add scan range selector
  - [ ] Add last scan indicator
  - [ ] Add manual scan trigger
  - [ ] Add processed count display
  - Location: Settings screen
  - Estimated Time: 2 hours

### Testing (Priority: MEDIUM)

- [ ] **2.10** Unit tests for Phase 2
  - [ ] Test account resolution
  - [ ] Test pipeline executor
  - [ ] Test confidence scoring
  - Estimated Time: 3 hours

- [ ] **2.11** Integration tests
  - [ ] Test full SMS pipeline end-to-end
  - [ ] Test pending action workflow
  - [ ] Test account candidate workflow
  - Estimated Time: 3 hours

- [ ] **2.12** UI testing
  - [ ] Test pending actions screen
  - [ ] Test candidate review screen
  - Estimated Time: 2 hours

**Phase 2 Total Estimated Time:** 37 hours

---

## ⏳ Phase 3: Advanced Detection (Week 5-6)

### Transfer Detection Engine (Priority: HIGH)

- [ ] **3.1** Create Transfer Detection Engine
  - [ ] Amount-time correlation algorithm
  - [ ] Debit-credit pair matching
  - [ ] Time window analysis (±2 hours)
  - [ ] Reference number matching
  - [ ] UPI transfer pattern detection
  - [ ] Confidence scoring
  - Location: `lib/services/transfer_detection_engine.dart`
  - Estimated Time: 5 hours

- [ ] **3.2** Create Transfer Pair Manager
  - [ ] Database CRUD operations
  - [ ] Pair creation and linking
  - [ ] Status management (detected/confirmed/rejected)
  - [ ] Auto-linking transactions
  - Location: `lib/services/transfer_pair_manager.dart`
  - Estimated Time: 3 hours

- [ ] **3.3** Implement Scheduled Transfer Detection
  - [ ] Background job for detection
  - [ ] Periodic scanning (daily)
  - [ ] Performance optimization
  - Location: `lib/services/transfer_detection_scheduler.dart`
  - Estimated Time: 2 hours

### Recurring Pattern Detection (Priority: HIGH)

- [ ] **3.4** Create Recurring Pattern Engine
  - [ ] Merchant grouping algorithm
  - [ ] Time interval analysis
  - [ ] Amount consistency detection
  - [ ] Frequency determination
  - [ ] Statistical analysis (std dev, CV)
  - [ ] Next occurrence prediction
  - Location: `lib/services/recurring_pattern_engine.dart`
  - Estimated Time: 5 hours

- [ ] **3.5** Create Recurring Pattern Manager
  - [ ] Database CRUD operations
  - [ ] Pattern status management
  - [ ] Transaction linking
  - [ ] Pattern update on new transactions
  - Location: `lib/services/recurring_pattern_manager.dart`
  - Estimated Time: 3 hours

- [ ] **3.6** Implement Scheduled Pattern Detection
  - [ ] Background job for detection
  - [ ] Weekly pattern analysis
  - [ ] Pattern evolution tracking
  - Location: `lib/services/pattern_detection_scheduler.dart`
  - Estimated Time: 2 hours

### UI Components (Priority: HIGH)

- [ ] **3.7** Create Transfer Pairs Screen
  - [ ] Detected pairs list
  - [ ] Pair detail view
  - [ ] Confirm/reject actions
  - [ ] Manual pair creation
  - [ ] Filter by status
  - Location: `lib/screens/transfer_pairs_screen.dart`
  - Estimated Time: 4 hours

- [ ] **3.8** Create Recurring Patterns Screen
  - [ ] Pattern list view
  - [ ] Pattern details with statistics
  - [ ] Confirm/reject patterns
  - [ ] View member transactions
  - [ ] Next occurrence indicator
  - Location: `lib/screens/recurring_patterns_screen.dart`
  - Estimated Time: 4 hours

- [ ] **3.9** Add Transfer Indicator to Transaction Details
  - [ ] Show linked transaction
  - [ ] Navigate to paired transaction
  - [ ] Transfer pair badge
  - Location: Transaction detail screen
  - Estimated Time: 1 hour

- [ ] **3.10** Add Recurring Badge to Transactions
  - [ ] Show pattern membership
  - [ ] Navigate to pattern details
  - [ ] Next occurrence preview
  - Location: Transaction list/detail
  - Estimated Time: 1 hour

### Testing (Priority: MEDIUM)

- [ ] **3.11** Unit tests for Phase 3
  - [ ] Test transfer detection algorithm
  - [ ] Test recurring pattern detection
  - [ ] Test statistical calculations
  - Estimated Time: 3 hours

- [ ] **3.12** Integration tests
  - [ ] Test transfer pair workflow
  - [ ] Test recurring pattern workflow
  - [ ] Test scheduled jobs
  - Estimated Time: 3 hours

**Phase 3 Total Estimated Time:** 36 hours

---

## ⏳ Phase 4: Learning System (Week 7-8)

### SMS Template Learning (Priority: MEDIUM)

- [ ] **4.1** Create SMS Template Service
  - [ ] Template storage and retrieval
  - [ ] Pattern matching using templates
  - [ ] Template creation from confirmed SMS
  - [ ] Accuracy tracking
  - [ ] Template ranking
  - Location: `lib/services/sms_template_service.dart`
  - Estimated Time: 4 hours

- [ ] **4.2** Implement Template Learning Engine
  - [ ] Auto-generate templates from user confirmations
  - [ ] Extract regex patterns
  - [ ] Update match counts
  - [ ] Accuracy calculation
  - Location: `lib/services/template_learning_engine.dart`
  - Estimated Time: 4 hours

### Merchant Mapping (Priority: MEDIUM)

- [ ] **4.3** Create Merchant Mapping Service
  - [ ] Database CRUD operations
  - [ ] Merchant name normalization
  - [ ] Variation detection
  - [ ] Auto-correction
  - Location: `lib/services/merchant_mapping_service.dart`
  - Estimated Time: 3 hours

### Confidence Adjustment (Priority: MEDIUM)

- [ ] **4.4** Create Learning Engine
  - [ ] Learn from account confirmations
  - [ ] Learn from merchant corrections
  - [ ] Boost institution confidence
  - [ ] Pattern refinement
  - [ ] Confidence score updates
  - Location: `lib/services/learning_engine.dart`
  - Estimated Time: 4 hours

### Feedback Loop Integration (Priority: HIGH)

- [ ] **4.5** Implement Feedback Collectors
  - [ ] Account confirmation feedback
  - [ ] Transaction correction feedback
  - [ ] Merchant name feedback
  - [ ] Transfer confirmation feedback
  - [ ] Pattern confirmation feedback
  - Location: `lib/services/feedback_collector.dart`
  - Estimated Time: 3 hours

- [ ] **4.6** Create Analytics Service
  - [ ] Track accuracy metrics
  - [ ] Track confidence trends
  - [ ] Track user correction rates
  - [ ] Generate improvement reports
  - Location: `lib/services/accuracy_analytics.dart`
  - Estimated Time: 2 hours

### UI Components (Priority: LOW)

- [ ] **4.7** Create SMS Templates Management Screen
  - [ ] Template list view
  - [ ] Template editor
  - [ ] Test template against SMS
  - [ ] Enable/disable templates
  - [ ] Accuracy statistics
  - Location: `lib/screens/sms_templates_screen.dart`
  - Estimated Time: 4 hours

- [ ] **4.8** Create Merchant Mappings Screen
  - [ ] Mapping list view
  - [ ] Add new mappings
  - [ ] Edit/delete mappings
  - [ ] Bulk import
  - Location: `lib/screens/merchant_mappings_screen.dart`
  - Estimated Time: 3 hours

### Testing (Priority: MEDIUM)

- [ ] **4.9** Unit tests for Phase 4
  - [ ] Test template matching
  - [ ] Test merchant normalization
  - [ ] Test learning algorithms
  - Estimated Time: 3 hours

- [ ] **4.10** Integration tests
  - [ ] Test full learning cycle
  - [ ] Test accuracy improvements
  - Estimated Time: 2 hours

**Phase 4 Total Estimated Time:** 32 hours

---

## ⏳ Phase 5: Intelligence Layer (Week 9-10)

### Financial Analytics (Priority: HIGH)

- [ ] **5.1** Create Financial Intelligence Service
  - [ ] Merchant trend analysis
  - [ ] Category spending analysis
  - [ ] Income vs expense analytics
  - [ ] Savings rate calculation
  - [ ] Time period comparisons
  - Location: `lib/services/financial_intelligence_service.dart`
  - Estimated Time: 4 hours

- [ ] **5.2** Implement Subscription Detection
  - [ ] Filter recurring patterns for subscriptions
  - [ ] Subscription-specific metrics
  - [ ] Cost analysis
  - [ ] Renewal predictions
  - Location: `lib/services/subscription_detector.dart`
  - Estimated Time: 3 hours

- [ ] **5.3** Create Spending Behavior Analyzer
  - [ ] Identify spending patterns
  - [ ] Anomaly detection
  - [ ] Budget adherence tracking
  - [ ] Merchant frequency analysis
  - Location: `lib/services/spending_behavior_analyzer.dart`
  - Estimated Time: 4 hours

### Dashboard & Visualization (Priority: HIGH)

- [ ] **5.4** Create SMS Intelligence Dashboard
  - [ ] Overview cards (transactions, accounts, patterns)
  - [ ] Confidence metrics
  - [ ] Pending action summary
  - [ ] Recent SMS imports
  - [ ] Quick actions
  - Location: `lib/screens/sms_intelligence_dashboard.dart`
  - Estimated Time: 5 hours

- [ ] **5.5** Create Merchant Trends Screen
  - [ ] Top merchants chart
  - [ ] Spending by merchant
  - [ ] Transaction count by merchant
  - [ ] Time series visualization
  - [ ] Filter by date range
  - Location: `lib/screens/merchant_trends_screen.dart`
  - Estimated Time: 4 hours

- [ ] **5.6** Create Subscriptions Dashboard
  - [ ] Active subscriptions list
  - [ ] Monthly cost breakdown
  - [ ] Next renewal dates
  - [ ] Subscription timeline
  - [ ] Cost trends
  - Location: `lib/screens/subscriptions_screen.dart`
  - Estimated Time: 4 hours

- [ ] **5.7** Create Insights Screen
  - [ ] Behavioral insights
  - [ ] Spending patterns
  - [ ] Anomalies
  - [ ] Recommendations
  - [ ] Comparison charts
  - Location: `lib/screens/insights_screen.dart`
  - Estimated Time: 5 hours

### Reports & Export (Priority: MEDIUM)

- [ ] **5.8** Create Report Generator
  - [ ] Monthly summary reports
  - [ ] SMS intelligence reports
  - [ ] Accuracy reports
  - [ ] PDF export
  - [ ] CSV export
  - Location: `lib/services/report_generator.dart`
  - Estimated Time: 3 hours

### Notifications (Priority: LOW)

- [ ] **5.9** Implement Smart Notifications
  - [ ] Pending action alerts
  - [ ] New subscription detected
  - [ ] Unusual spending alert
  - [ ] Transfer detected
  - [ ] Pattern detected
  - Location: `lib/services/smart_notifications.dart`
  - Estimated Time: 2 hours

### Testing (Priority: MEDIUM)

- [ ] **5.10** Unit tests for Phase 5
  - [ ] Test analytics calculations
  - [ ] Test subscription detection
  - [ ] Test behavior analysis
  - Estimated Time: 3 hours

- [ ] **5.11** Integration tests
  - [ ] Test dashboard data
  - [ ] Test report generation
  - Estimated Time: 2 hours

**Phase 5 Total Estimated Time:** 39 hours

---

## ⏳ Phase 6: Region-Specific Enhancements (Week 11-12)

### US Bank Support (Priority: HIGH)

- [ ] **6.1** Add US Bank Templates
  - [ ] Chase Bank patterns
  - [ ] Bank of America patterns
  - [ ] Wells Fargo patterns
  - [ ] Citibank patterns
  - [ ] Capital One patterns
  - [ ] American Express patterns
  - [ ] Discover patterns
  - [ ] US Bank patterns
  - Location: `lib/data/us_bank_templates.dart`
  - Estimated Time: 4 hours

- [ ] **6.2** US-Specific Merchant Categories
  - [ ] Major US retailers
  - [ ] US restaurant chains
  - [ ] US service providers
  - [ ] US utilities
  - Location: `lib/data/us_merchant_categories.dart`
  - Estimated Time: 2 hours

- [ ] **6.3** US Transaction Patterns
  - [ ] ACH transfer detection
  - [ ] Check deposit patterns
  - [ ] Wire transfer patterns
  - Location: Entity extraction service
  - Estimated Time: 2 hours

### Indian Bank Support (Priority: HIGH)

- [ ] **6.4** Add Indian Bank Templates
  - [ ] HDFC Bank patterns
  - [ ] ICICI Bank patterns
  - [ ] State Bank of India patterns
  - [ ] Axis Bank patterns
  - [ ] Kotak Mahindra patterns
  - [ ] Punjab National Bank patterns
  - [ ] Yes Bank patterns
  - [ ] IDFC First Bank patterns
  - Location: `lib/data/indian_bank_templates.dart`
  - Estimated Time: 4 hours

- [ ] **6.5** UPI Transaction Support
  - [ ] UPI ID extraction
  - [ ] VPA parsing
  - [ ] UPI reference number
  - [ ] UPI merchant detection
  - Location: Entity extraction service
  - Estimated Time: 3 hours

- [ ] **6.6** Indian Payment Methods
  - [ ] IMPS transfer detection
  - [ ] NEFT transfer detection
  - [ ] RTGS transfer detection
  - [ ] Wallet transactions (Paytm, PhonePe, Google Pay)
  - Location: Entity extraction service
  - Estimated Time: 3 hours

- [ ] **6.7** Indian-Specific Merchant Categories
  - [ ] Major Indian retailers
  - [ ] Indian service providers
  - [ ] Indian utilities
  - [ ] Indian transport
  - Location: `lib/data/indian_merchant_categories.dart`
  - Estimated Time: 2 hours

### Multi-Currency Support (Priority: MEDIUM)

- [ ] **6.8** Enhance Currency Handling
  - [ ] Currency detection
  - [ ] Currency conversion tracking
  - [ ] Multi-currency accounts
  - [ ] Currency symbols (₹, $, €, £, etc.)
  - Location: Entity extraction service
  - Estimated Time: 3 hours

### Localization (Priority: LOW)

- [ ] **6.9** Add Localization Support
  - [ ] English (US)
  - [ ] English (India)
  - [ ] Date format localization
  - [ ] Number format localization
  - Location: `lib/l10n/`
  - Estimated Time: 3 hours

### Testing (Priority: HIGH)

- [ ] **6.10** Real-World SMS Testing
  - [ ] Collect US SMS samples (anonymized)
  - [ ] Collect Indian SMS samples (anonymized)
  - [ ] Create test dataset (1000+ messages)
  - Estimated Time: 4 hours

- [ ] **6.11** Accuracy Validation
  - [ ] Test US bank SMS accuracy
  - [ ] Test Indian bank SMS accuracy
  - [ ] Test UPI transactions
  - [ ] Test transfer detection
  - [ ] Validate against manual classification
  - Estimated Time: 4 hours

- [ ] **6.12** Cross-Region Testing
  - [ ] Test multi-region accounts
  - [ ] Test currency handling
  - [ ] Test localization
  - Estimated Time: 2 hours

**Phase 6 Total Estimated Time:** 36 hours

---

## 🔧 Maintenance & Optimization

### Performance Optimization (Ongoing)

- [ ] **M.1** Optimize database queries
  - [ ] Add indexes for common queries
  - [ ] Optimize join operations
  - [ ] Cache frequently accessed data
  - Estimated Time: 3 hours

- [ ] **M.2** Optimize SMS processing
  - [ ] Batch processing
  - [ ] Parallel entity extraction
  - [ ] Template caching
  - Estimated Time: 3 hours

- [ ] **M.3** Memory optimization
  - [ ] Reduce object allocations
  - [ ] Optimize regex patterns
  - [ ] Lazy loading for large datasets
  - Estimated Time: 2 hours

### Documentation (Ongoing)

- [ ] **M.4** Update API documentation
  - [ ] Document all new services
  - [ ] Add code examples
  - [ ] Update design document
  - Estimated Time: 4 hours

- [ ] **M.5** Create user guide
  - [ ] SMS import guide
  - [ ] Pending actions guide
  - [ ] Pattern management guide
  - Location: `docs/USER_GUIDE.md`
  - Estimated Time: 3 hours

### Security Audit (Before Launch)

- [ ] **M.6** Privacy compliance review
  - [ ] Verify OTP filtering
  - [ ] Verify data sanitization
  - [ ] Review retention policies
  - Estimated Time: 2 hours

- [ ] **M.7** Security testing
  - [ ] SQL injection testing
  - [ ] Input validation testing
  - [ ] Permission handling testing
  - Estimated Time: 3 hours

**Maintenance Total Estimated Time:** 20 hours

---

## 📊 Summary

### Time Estimates by Phase

| Phase | Tasks | Estimated Hours | Status |
|-------|-------|-----------------|--------|
| Phase 0 | 6 | - | ✅ Complete |
| Phase 1 | 10 | 23h | ⏳ Not Started |
| Phase 2 | 12 | 37h | ⏳ Not Started |
| Phase 3 | 12 | 36h | ⏳ Not Started |
| Phase 4 | 10 | 32h | ⏳ Not Started |
| Phase 5 | 11 | 39h | ⏳ Not Started |
| Phase 6 | 12 | 36h | ⏳ Not Started |
| Maintenance | 7 | 20h | ⏳ Not Started |
| **TOTAL** | **80** | **223h** | **0% Complete** |

### Estimated Timeline

- **Phase 1:** 3 days (Week 1)
- **Phase 2:** 5 days (Week 2-3)
- **Phase 3:** 5 days (Week 4-5)
- **Phase 4:** 4 days (Week 6)
- **Phase 5:** 5 days (Week 7-8)
- **Phase 6:** 5 days (Week 9-10)
- **Testing & Polish:** 3 days (Week 11)

**Total Project Timeline:** ~11-12 weeks (part-time development)

---

## 🎯 Success Criteria

### Accuracy Targets
- [ ] Transaction extraction accuracy > 95%
- [ ] Account resolution accuracy > 90%
- [ ] Transfer detection accuracy > 85%
- [ ] Recurring pattern detection accuracy > 80%

### Performance Targets
- [ ] SMS processing < 500ms per message
- [ ] Bulk import: 1000 SMS in < 30 seconds
- [ ] Zero crashes on malformed SMS
- [ ] App launch time impact < 100ms

### User Experience Targets
- [ ] Pending action resolution rate > 80%
- [ ] False positive rate < 5%
- [ ] User confirmation required < 10% of transactions
- [ ] 4.5+ star user rating

---

## 📝 Notes

### Current System State (April 18, 2026)
- ✅ Hybrid Transaction Mapping System implemented
- ✅ Basic SMS parsing (sms_service.dart)
- ✅ Account matching service exists
- ✅ Database schema v11 with enhanced fields
- ✅ Transaction model supports SMS fields

### Key Decisions Made
- Using SQLite for all data storage
- Confidence threshold: 0.70 for auto-approval
- Privacy-first: No OTP/password storage
- User can always override system decisions
- Learning from user feedback is core feature

### Technical Debt to Address
- None identified yet (fresh implementation)

---

## 🔄 Change Log

| Date | Phase | Changes |
|------|-------|---------|
| Apr 18, 2026 | Phase 0 | Initial TODO list created |

---

**Last Updated:** April 18, 2026  
**Maintained By:** Development Team  
**Status:** 🟡 Active Development
