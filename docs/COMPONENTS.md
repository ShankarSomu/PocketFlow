# COMPONENTS — Reusable UI components

This document lists reusable widgets and UI components found in `lib/widgets/` and describes their purpose, common parameters, and where they are used.

Note: open the files under `lib/widgets/` to inspect public constructors and properties.

1) UI building blocks (`lib/widgets/ui/`)
- `screen_header.dart` — common screen header used across pages; typically accepts title, subtitle and leading/trailing actions.
- `section_title.dart` — small section title with optional action button.
- `time_filter_bar.dart` — time range filter control used in transaction lists and dashboards.
- `progress_bar.dart` — compact progress indicator used in budget/savings UI.
- `panel.dart` — generic card/panel container for grouping content.

2) Interaction widgets
- `speed_dial_fab.dart` — floating action button with expanding actions used on index screens.
- `pull_to_refresh.dart` — pull-to-refresh behavior wrapper.
- `pagination.dart` — pagination controls used in long lists.
- `navigable_page_view.dart` — page view with navigation affordances.

3) Visual / micro-interaction helpers
- `gradient_card.dart`, `icon_circle.dart`, `badge.dart` — stylistic components for status or emphasis.
- `micro_interactions.dart` — small animations/touch responses used across UI.
- `loading_skeleton.dart` — skeleton loader used while content is loading.

4) Buttons & form helpers
- `standard_buttons.dart` — consistent button styles and action variants used throughout the app.
- `form validation` helpers in `lib/core/form_validation.dart` are often used alongside widgets with input fields.

5) Feature-specific small components
- `stats_card.dart` — small card used in dashboard and home components (`lib/screens/home/components/`).
- `transaction_card.dart`, `transaction_list.dart` — transaction-focused components used in `lib/screens/transactions/`.
- Chat components: `message_bubble.dart`, `chat_input_bar.dart`, `chat_suggestions.dart` used in `lib/screens/chat/`.

How to read a component file
1. Open the file under `lib/widgets/` to find the constructor and named parameters.
2. Check usages with an IDE or by searching `lib/screens/` to see typical props passed and state interactions.

Where to add new components
- Add new reusable components under `lib/widgets/` and prefer small, focused widgets. Document new components in `docs/COMPONENTS.md` with examples and common props.

