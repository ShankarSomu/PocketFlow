# DATABASE — schema and persistence notes

This document summarizes the local persistence layer used by PocketFlow (models, tables, key relationships, and lifecycle notes).

1) Database engine
- PocketFlow uses a local SQLite database accessed via the adapter in `lib/db/database.dart` and repositories in `lib/repositories/impl/`.

2) Primary domain models → tables
- `Transaction` (`lib/models/transaction.dart`) — stores transaction records detected from SMS or manual entry. Key fields: id, accountId, amount, date, merchant, categoryId, metadata.
- `Account` (`lib/models/account.dart`) — account records with identifiers, balance hints and matching metadata.
- `Category` (`lib/models/category.dart`) — category definitions used for transaction labeling.
- `Budget` (`lib/models/budget.dart`) — budget definitions with target amounts and ranges.
- `RecurringTransaction` / `RecurringPattern` (`lib/models/recurring_transaction.dart`, `lib/models/recurring_pattern.dart`) — store detected recurring rules and derived recurring transactions.
- `PendingAction` (`lib/models/pending_action.dart`) — deferred user actions (e.g., suggested matching) stored until resolved.
- `TransferPair` (`lib/models/transfer_pair.dart`) — suggested transfer pairs detected from transaction pairs.

3) Relationships
- Transactions reference `Account` and optionally `Category` via foreign keys (repository layer enforces links).
- Recurring patterns reference a source transaction or a set of transactions used to infer the pattern.

4) Migrations and lifecycle
- Migrations and DB upgrade helpers are implemented in `lib/services/database_migration.dart`.
- Seed and demo data lives in `lib/services/seed_data.dart` and is applied on fresh installs (or when requested).

5) Key queries & repository responsibilities
- Repositories encapsulate raw SQL or ORM queries; examine `lib/repositories/impl/transaction_repository_impl.dart` for common queries (filters, pagination, time-range queries, aggregation for summaries).
- Aggregation queries for dashboards and budget calculations are implemented in repositories and reused by services (e.g., intelligence engines).

6) Data retention & privacy
- Privacy decisions are coordinated by `lib/services/privacy_guard.dart` — ensure that any export or sync path respects user privacy settings.

7) Tips for extending DB
- Add models under `lib/models/` and then implement repository interfaces in `lib/repositories/` and a backing implementation in `lib/repositories/impl/` that uses `lib/db/database.dart`.
- Add migration steps in `lib/services/database_migration.dart` to update existing installations safely.

