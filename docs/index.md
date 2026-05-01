# PocketFlow Documentation

Welcome to the PocketFlow documentation. This guide will help you understand, use, and contribute to PocketFlow.

## 📚 Documentation Navigation

### 🚀 Getting Started
- [Installation](getting-started/installation.md) - Setup Flutter and dependencies
- [Quick Start](getting-started/quick-start.md) - Run the app in 5 minutes
- [Configuration](getting-started/configuration.md) - Environment and settings

### 🏗️ Architecture
- [System Overview](architecture/overview.md) - High-level architecture
- [Components](architecture/components.md) - Core components and their roles
- [Database](architecture/database.md) - SQLite schema and data layer
- [State Management](architecture/state-management.md) - State patterns and ViewModels
- [Services](architecture/services.md) - Business logic and service layer

### ✨ Features

#### SMS Intelligence
- [Overview](features/sms-intelligence/overview.md) - SMS processing pipeline
- [Classification](features/sms-intelligence/classification.md) - Transaction type detection
- [Entity Extraction](features/sms-intelligence/entity-extraction.md) - Parsing amounts, merchants, accounts
- [Account Resolution](features/sms-intelligence/account-resolution.md) - Matching SMS to accounts
- [Transfer Detection](features/sms-intelligence/transfer-detection.md) - Identifying money transfers
- [Recurring Patterns](features/sms-intelligence/recurring-patterns.md) - Subscription and salary detection

#### Machine Learning
- [Overview](features/machine-learning/overview.md) - ML architecture
- [Classifier Guide](features/machine-learning/classifier-guide.md) - Using the SMS classifier
- [Continuous Learning](features/machine-learning/continuous-learning.md) - Feedback and model improvement
- [Model Deployment](features/machine-learning/model-deployment.md) - TFLite model integration

#### Accounting System
- [System Overview](features/accounting/system-overview.md) - Financial tracking approach
- [Double-Entry Solution](features/accounting/double-entry.md) - Avoiding duplicate transactions
- [Feedback & Learning](features/accounting/feedback-system.md) - User correction system
- [Transaction Mapping](features/accounting/transaction-mapping.md) - Category and account mapping

#### UI Features
- [Accounts Screen](features/ui-features/accounts-screen.md) - Account management UI
- [Navigation](features/ui-features/navigation.md) - App navigation and deep linking
- [Accessibility](features/ui-features/accessibility.md) - UI/UX and accessibility features
- [Component Library](features/ui-features/component-library.md) - Reusable UI components

### 🔧 Development
- [Developer Guide](development/developer-guide.md) - Contribution guidelines
- [Performance](development/performance.md) - Optimization strategies
- [Testing](development/testing.md) - Unit and widget tests
- [Contributing](development/contributing.md) - How to contribute

### 📖 Reference
- [Quick Reference](reference/quick-reference.md) - Common tasks and patterns
- [API Reference](reference/api-reference.md) - Core APIs and interfaces
- [Troubleshooting](reference/troubleshooting.md) - Common issues and solutions
- [FAQ](reference/faq.md) - Frequently asked questions

---

## 🎯 Quick Links

- **New Developer?** Start with [Quick Start](getting-started/quick-start.md)
- **Understanding the System?** Check [Architecture Overview](architecture/overview.md)
- **Working on SMS Features?** See [SMS Intelligence](features/sms-intelligence/overview.md)
- **Need Help?** Check [Troubleshooting](reference/troubleshooting.md)

## 📦 Project Structure

```
lib/
├── core/           # App initialization and dependencies
├── models/         # Data models
├── db/             # Database layer
├── repositories/   # Data access layer
├── services/       # Business logic
├── viewmodels/     # Presentation logic
├── screens/        # UI screens
├── widgets/        # Reusable UI components
└── theme/          # App theming
```

## 📝 Documentation Standards

All documentation follows these principles:
- **Focused**: Each file covers one topic
- **Concise**: Under 500 lines per file
- **Hierarchical**: Organized by category
- **Up-to-date**: Regularly reviewed and updated

---

*Last updated: April 23, 2026*
