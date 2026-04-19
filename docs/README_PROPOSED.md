# PocketFlow Documentation (Proposed Index)

This is a proposed, clearer index and contributor guide for the `docs/` folder. It is intentionally created as `README_PROPOSED.md` so maintainers can review before replacing the existing `README.md`.

If you contribute to the docs, please follow the page template in `docs/templates/page-template.md` and update the audit inventory at `docs/audit/INVENTORY.md` for any file you edit or move.

---

## Quick links

- Audit inventory: `docs/audit/INVENTORY.md`
- Page template: `docs/templates/page-template.md`
- Proposed new structure (work in progress):
  - `docs/README.md` (index) — overview + edit guidance
  - `docs/getting-started.md` — short dev quick-start (TODO)
  - `docs/architecture/` — architecture overview and quick reference
  - `docs/guides/` — state management, migration, performance guides
  - `docs/components/` — component library and examples
  - `docs/sms/` — SMS intelligence design, quick-start, status
  - `docs/releases/` — archived phase reports and release notes

## How to edit these docs

1. Update `docs/audit/INVENTORY.md` to mark your planned change (Action and Priority).
2. Create a small branch named `docs/{area}/{short-description}` and a focused PR.
3. Use `docs/templates/page-template.md` for new pages; add `Last-Updated` and `Maintainer` metadata.
4. Run the local checks (see below) before opening a PR.

## Local preview & checks (recommended)

Option 1 — MkDocs (recommended for site preview):

```powershell
python -m pip install --user mkdocs mkdocs-material
mkdocs serve
```

Option 2 — Basic link check (PowerShell):

```powershell
# install markdown-link-check (requires node/npm)
npm install -g markdown-link-check
markdown-link-check docs/**/*.md
```

Optional: validate Dart code snippets by extracting fenced ```dart``` blocks and running `dart format` or `dart analyze` against them. See `scripts/docs/` (planned) for helper scripts.

## Audit & consolidation status

See `docs/audit/INVENTORY.md` for the live audit table. High-priority items being worked on first include:

- `ARCHITECTURE_REFACTORING.md` + `ARCHITECTURE_QUICK_REFERENCE.md` (merge to `docs/architecture/`)
- SMS intelligence docs (restructure to `docs/sms/`)
- `STATE_MANAGEMENT.md` (expand with examples)

## Conventions

- All pages should include a short Summary and Last-Updated date in the top metadata section.
- Keep pages focused: prefer small pages linked from an index rather than very long monolithic files.
- Move historic phase reports into `docs/releases/` and keep a short `releases/summary.md`.

---

**Last Updated:** April 18, 2026  
**Maintained By:** PocketFlow Development Team

