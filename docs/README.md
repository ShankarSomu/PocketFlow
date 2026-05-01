# PocketFlow Documentation Index

This directory contains all technical documentation for the PocketFlow personal finance app.

## 📚 Documentation Organization

### Core Data & Accounting
- **[ACCOUNTING_SYSTEM.md](ACCOUNTING_SYSTEM.md)** - Core accounting logic, balance calculation, and transaction handling
- **[DATABASE.md](DATABASE.md)** - Complete database schema and models reference
- **[DOUBLE_ENTRY_SOLUTION.md](DOUBLE_ENTRY_SOLUTION.md)** - ML-driven transfer detection and double-entry prevention

### Machine Learning System
- **[ML_RESPONSIBILITIES.md](ML_RESPONSIBILITIES.md)** ⭐ **START HERE** - Clear separation of ML vs application logic
- **[ML_ARCHITECTURE_AUDIT.md](ML_ARCHITECTURE_AUDIT.md)** - Architecture audit and current state
- **[ML_SMS_CLASSIFIER_GUIDE.md](ML_SMS_CLASSIFIER_GUIDE.md)** - Training and deployment guide
- **[ML_INTEGRATION_COMPLETE.md](ML_INTEGRATION_COMPLETE.md)** - ML integration completion report
- **[ML_DEPLOYMENT_COMPLETE.md](ML_DEPLOYMENT_COMPLETE.md)** - ML deployment completion report
- **[ML_3CLASS_UPGRADE.md](ML_3CLASS_UPGRADE.md)** - 3-class classifier upgrade guide
- **[CONTINUOUS_LEARNING.md](CONTINUOUS_LEARNING.md)** - Continuous learning system
- **[ENHANCED_FEEDBACK_LEARNING_SYSTEM.md](ENHANCED_FEEDBACK_LEARNING_SYSTEM.md)** - Enhanced feedback system

### Architecture & Design
- **[ARCHITECTURE_QUICK_REFERENCE.md](ARCHITECTURE_QUICK_REFERENCE.md)** - Quick reference for app architecture
- **[ARCHITECTURE_REFACTORING.md](ARCHITECTURE_REFACTORING.md)** - Architecture refactoring decisions and patterns
- **[STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)** - State management patterns and best practices
- **[NAVIGATION_GUARDS.md](NAVIGATION_GUARDS.md)** - Navigation guard implementation
- **[DEEP_LINKING.md](DEEP_LINKING.md)** - Deep linking configuration and usage

### Features & Components
- **[COMPONENT_LIBRARY.md](COMPONENT_LIBRARY.md)** - Reusable component library documentation
- **[FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)** - Feature development roadmap
- **[FEATURE_COMPARISON.md](FEATURE_COMPARISON.md)** - Feature comparison and analysis
- **[DESIGN_FEATURE_COMPARISON.md](DESIGN_FEATURE_COMPARISON.md)** - Design pattern comparisons
- **[UI_UX_ACCESSIBILITY.md](UI_UX_ACCESSIBILITY.md)** - UI/UX and accessibility guidelines
- **[VOICE_INPUT.md](VOICE_INPUT.md)** - Voice input feature documentation
- **[PREMIUM_REDESIGN.md](PREMIUM_REDESIGN.md)** - Premium features design

### SMS Intelligence System
- **[TRANSACTION_SCREEN_UPDATE_COMPLETE.md](TRANSACTION_SCREEN_UPDATE_COMPLETE.md)** ✅ **IMPLEMENTATION COMPLETE** - Transaction detail screen with feedback
  - 7 UI sections (summary, account, SMS intelligence, transfer, feedback, actions, metadata)
  - TransactionFeedbackService with learning algorithms
  - Database v20 migration (3 feedback tables)
  - Transfer confirmation flow
  - Confidence score explanations
  - Ready for testing
- **[SMS_SCAN_FLOW_COMPLETE.md](SMS_SCAN_FLOW_COMPLETE.md)** 🎓 **USER LEARNING FLOW** - Complete scan journey with feedback loop
  - Step-by-step user flow from scan to review
  - Machine learning & confidence scoring
  - User feedback learning system
  - Fix for numeric sender IDs (692484, 227898, etc.)
  - Expected: 2000+ imports vs current 3
- **[TRANSACTION_FEEDBACK_SYSTEM.md](TRANSACTION_FEEDBACK_SYSTEM.md)** 💬 **FEEDBACK UI** - Complete feedback system implementation
  - Granular feedback (thumbs up/down per field)
  - Learning database tables
  - Confidence explanation system
  - 6-8 hour implementation plan
- **[SMS_PARSING_FLOW.md](SMS_PARSING_FLOW.md)** ⭐ **TECHNICAL REFERENCE** - Current SMS parsing architecture
  - 5-layer processing pipeline
  - 40+ regex patterns with examples
  - Edge cases + known issues
- **[SMS_RULE_IMPROVEMENTS_PLAN.md](SMS_RULE_IMPROVEMENTS_PLAN.md)** 🚀 **ACTIVE DEVELOPMENT** - Rule-based enhancement plan
  - Transfer rules expansion (88%→95% accuracy)
  - Account type grouping (Asset vs Liability)
  - Weighted confidence scoring (multi-signal matching)
  - 4-week roadmap (22 hours total effort)
- **[SMS_INTELLIGENCE_ENGINE_DESIGN.md](SMS_INTELLIGENCE_ENGINE_DESIGN.md)** - Complete SMS intelligence engine architecture
- **[SMS_INTELLIGENCE_QUICK_START.md](SMS_INTELLIGENCE_QUICK_START.md)** - Quick start guide for SMS features
- **[SMS_ENGINE_STATUS.md](SMS_ENGINE_STATUS.md)** - Current SMS engine implementation status
- **[SMS_INTELLIGENCE_PROGRESS.md](SMS_INTELLIGENCE_PROGRESS.md)** - SMS intelligence progress tracking
- **[SMS_INTELLIGENCE_TODO.md](SMS_INTELLIGENCE_TODO.md)** - SMS intelligence TODO list

### Hybrid Transaction Mapping
- **[HYBRID_TRANSACTION_MAPPING_SYSTEM.md](HYBRID_TRANSACTION_MAPPING_SYSTEM.md)** - Hybrid transaction mapping system design
- **[HYBRID_TRANSACTION_MAPPING_IMPLEMENTATION.md](HYBRID_TRANSACTION_MAPPING_IMPLEMENTATION.md)** - Implementation details

### Screen Documentation
- **[ACCOUNTS_SCREEN.md](ACCOUNTS_SCREEN.md)** - Accounts screen implementation guide

### Implementation Summaries
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Reusability & modularity improvements
- **[COMPLETE_SUMMARY.md](COMPLETE_SUMMARY.md)** - Complete implementation summary
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Code refactoring summary

### Phase Completion Reports
- **[PHASE_1_COMPLETE.md](PHASE_1_COMPLETE.md)** - Phase 1 completion report
- **[PHASE_1_COMPLETE_SMS_INTELLIGENCE.md](PHASE_1_COMPLETE_SMS_INTELLIGENCE.md)** - SMS Intelligence Phase 1
- **[PHASE_2_COMPLETE.md](PHASE_2_COMPLETE.md)** - Phase 2 completion report
- **[PHASE_2_COMPLETE_CORE_INTELLIGENCE.md](PHASE_2_COMPLETE_CORE_INTELLIGENCE.md)** - Core Intelligence Phase 2
- **[PHASE_2_FINAL.md](PHASE_2_FINAL.md)** - Phase 2 final summary
- **[PHASE_2_PROGRESS.md](PHASE_2_PROGRESS.md)** - Phase 2 progress tracking
- **[PHASE_3_COMPLETE_INTELLIGENCE_UI.md](PHASE_3_COMPLETE_INTELLIGENCE_UI.md)** - Intelligence UI Phase 3

### Progress & Updates
- **[PROGRESS_SUMMARY.md](PROGRESS_SUMMARY.md)** - Overall progress summary
- **[RECENT_UPDATES.md](RECENT_UPDATES.md)** - Recent updates and changes

### Quick References
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference guide
- **[PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md)** - Performance optimization techniques
- **[CONNECT.md](CONNECT.md)** - Connection and integration documentation

---

## 🔍 Finding What You Need

### For New Developers
1. Start with **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** or **[ARCHITECTURE_QUICK_REFERENCE.md](ARCHITECTURE_QUICK_REFERENCE.md)**
2. Review **[ACCOUNTING_SYSTEM.md](ACCOUNTING_SYSTEM.md)** to understand transaction logic and balance calculations
3. Check **[DATABASE.md](DATABASE.md)** for complete schema reference
4. Review **[COMPONENT_LIBRARY.md](COMPONENT_LIBRARY.md)** for reusable components
5. Check **[STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)** for state patterns

### For Understanding Data & Transactions
1. **[ACCOUNTING_SYSTEM.md](ACCOUNTING_SYSTEM.md)** - How transactions, balances, and transfers work
2. **[DATABASE.md](DATABASE.md)** - Complete database schema and relationships
3. **[DOUBLE_ENTRY_SOLUTION.md](DOUBLE_ENTRY_SOLUTION.md)** - Transfer detection and double-counting prevention

### For Machine Learning & SMS Classification
1. **[ML_RESPONSIBILITIES.md](ML_RESPONSIBILITIES.md)** ⭐ **START HERE** - What ML does (and doesn't do)
2. **[ML_ARCHITECTURE_AUDIT.md](ML_ARCHITECTURE_AUDIT.md)** - Current implementation state
3. **[ML_SMS_CLASSIFIER_GUIDE.md](ML_SMS_CLASSIFIER_GUIDE.md)** - Training and deployment
4. **[ENHANCED_FEEDBACK_LEARNING_SYSTEM.md](ENHANCED_FEEDBACK_LEARNING_SYSTEM.md)** - Continuous learning

### For SMS Intelligence Features
1. **[SMS_SCAN_FLOW_COMPLETE.md](SMS_SCAN_FLOW_COMPLETE.md)** 🎓 **START HERE FOR LEARNING SYSTEM** - Complete user journey
2. **[SMS_PARSING_FLOW.md](SMS_PARSING_FLOW.md)** ⭐ **TECHNICAL REFERENCE** - Complete reference with examples
3. **[SMS_RULE_IMPROVEMENTS_PLAN.md](SMS_RULE_IMPROVEMENTS_PLAN.md)** 🚀 **IMPLEMENTATION PLAN** - Rule-based enhancements
4. **[SMS_INTELLIGENCE_ENGINE_DESIGN.md](SMS_INTELLIGENCE_ENGINE_DESIGN.md)** - Complete design
3. **[SMS_INTELLIGENCE_QUICK_START.md](SMS_INTELLIGENCE_QUICK_START.md)** - Quick start guide
4. **[SMS_ENGINE_STATUS.md](SMS_ENGINE_STATUS.md)** - Current status

### For Feature Development
1. **[FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)** - Planned features
2. **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Implementation patterns
3. **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Code quality guidelines

### For UI/UX Work
1. **[UI_UX_ACCESSIBILITY.md](UI_UX_ACCESSIBILITY.md)** - UI/UX guidelines
2. **[COMPONENT_LIBRARY.md](COMPONENT_LIBRARY.md)** - Component library
3. **[PREMIUM_REDESIGN.md](PREMIUM_REDESIGN.md)** - Premium design patterns

---

## Archived / legacy docs
Some documents in this folder are historic (phase reports, progress summaries, refactor notes) and are kept for reference. We recommend consolidating or removing truly deprecated files as part of a docs cleanup PR.

- See `docs/ARCHIVE.md` for the maintained list of files recommended for archival and suggested next steps.

---

**Last Updated:** April 23, 2026  
**Maintained By:** PocketFlow Development Team
