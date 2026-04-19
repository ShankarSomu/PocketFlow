# ARCHIVE — Candidate documentation for cleanup

Purpose: this file lists documentation files in `docs/` that are historic, duplicated, or scheduled for archival. Because the repository retains history, these files can be removed or moved to an `archived/` folder in a dedicated cleanup PR. The list below is a recommended starting point — please review each file before removal.

Recommended action: create a branch `docs/archive/*` and a PR that moves the files in the list to `docs/archived/` or deletes them if they are truly obsolete. Update `docs/README.md` with a short note pointing to the archive index.

Files recommended for archival (review each before action):
- `PHASE_1_COMPLETE.md`
- `PHASE_1_COMPLETE_SMS_INTELLIGENCE.md`
- `PHASE_2_COMPLETE.md`
- `PHASE_2_COMPLETE_CORE_INTELLIGENCE.md`
- `PHASE_2_FINAL.md`
- `PHASE_3_COMPLETE_INTELLIGENCE_UI.md`
- `PROGRESS_SUMMARY.md`
- `COMPLETE_SUMMARY.md`
- `IMPLEMENTATION_SUMMARY.md`
- `REFACTORING_SUMMARY.md`
- `ARCHITECTURE_REFACTORING.md`
- `FEATURE_ROADMAP.md` (if roadmap is stale — consider consolidating into `docs/releases/`)
- `FEATURE_COMPARISON.md`
- `DESIGN_FEATURE_COMPARISON.md`
- `HYBRID_TRANSACTION_MAPPING_IMPLEMENTATION.md` (move under `docs/hybrid/` if still relevant)
- `HYBRID_TRANSACTION_MAPPING_SYSTEM.md` (review for consolidation)

Notes and guidance before removing files
- Inspect each file and confirm it doesn't contain unique implementation guidance or migration instructions that should remain discoverable.
- If a file documents a completed phase but contains useful lessons or migration notes, move it to `docs/releases/` and add a short summary file linking to it.
- Update the audit inventory `docs/audit/INVENTORY.md` to mark any moved or removed docs and the reason.

If you want, I can prepare the cleanup PR by copying the listed files into `docs/archived/` and adding a one-line header to the originals that points to the archived copy. Because deleting files is restricted in this environment, the PR would perform moves/renames instead of permanent deletions.

