# PocketFlow Component Library

A comprehensive guide to all reusable widgets, utilities, and helpers in the PocketFlow app.

## Table of Contents

1. [Shared Widgets](#shared-widgets)
2. [Card Variants](#card-variants)
3. [Utilities](#utilities)
4. [Formatters](#formatters)
5. [Extensions](#extensions)
6. [Screen Components](#screen-components)

---

## Shared Widgets

### Error Handling

#### `ErrorBoundary`
Wraps widgets to catch and handle errors gracefully.

```dart
ErrorBoundary(
  child: YourWidget(),
  onError: (error, stackTrace) {
    // Custom error handling
  },
)
```

#### `ErrorStateWidget`
Displays error state with retry option.

```dart
ErrorStateWidget(
  message: 'Failed to load data',
  onRetry: () => loadData(),
)
```

#### `CompactErrorWidget`
Minimal error display for tight spaces.

```dart
CompactErrorWidget(
  message: 'Error occurred',
)
```

### Loading States

#### `LoadingIndicator`
Standard circular progress indicator.

```dart
LoadingIndicator(message: 'Loading...')
```

#### `ShimmerLoading`
Animated shimmer effect for loading states.

```dart
ShimmerLoading(
  child: SkeletonListTile(),
)
```

#### Skeleton Components
Pre-built skeleton loaders:
- `SkeletonBox` - Rectangular placeholder
- `SkeletonLine` - Line placeholder
- `SkeletonCircle` - Circular placeholder
- `SkeletonListTile` - List item skeleton
- `SkeletonCard` - Card skeleton
- `TransactionListSkeleton` - Transaction list skeleton
- `StatsCardsSkeleton` - Stats cards skeleton
- `ProfileSkeleton` - Profile screen skeleton

```dart
TransactionListSkeleton(itemCount: 5)
```

### Empty States

#### `EmptyState`
Standard empty state display.

```dart
EmptyState(
  icon: Icons.inbox,
  title: 'No transactions',
  subtitle: 'Start by adding your first transaction',
  actionText: 'Add Transaction',
  onActionTap: () => addTransaction(),
)
```

#### `IllustratedEmptyState`
Empty state with custom illustration.

```dart
IllustratedEmptyState(
  illustration: CustomIllustration.noData,
  title: 'No data available',
  message: 'Check back later',
)
```

### Buttons

#### `PrimaryButton`
Main action button.

```dart
PrimaryButton(
  text: 'Save',
  onPressed: () => save(),
  icon: Icons.save,
)
```

#### `SecondaryButton`
Secondary action button.

```dart
SecondaryButton(
  text: 'Cancel',
  onPressed: () => cancel(),
)
```

#### `TertiaryButton`
Tertiary/text button.

```dart
TertiaryButton(
  text: 'Skip',
  onPressed: () => skip(),
)
```

#### `DestructiveButton`
Dangerous action button (delete, remove).

```dart
DestructiveButton(
  text: 'Delete',
  onPressed: () => delete(),
)
```

#### `StandardIconButton`
Icon-only button.

```dart
StandardIconButton(
  icon: Icons.edit,
  onPressed: () => edit(),
)
```

#### `StandardFAB`
Floating action button.

```dart
StandardFAB(
  icon: Icons.add,
  onPressed: () => add(),
)
```

### Common UI

#### `SectionHeader`
Reusable section header with optional action.

```dart
SectionHeader(
  title: 'Recent Transactions',
  subtitle: 'Last 7 days',
  actionText: 'View All',
  onActionTap: () => viewAll(),
)
```

#### `StatsCard`
Display statistics with icon.

```dart
StatsCard(
  title: 'Balance',
  value: '\$1,234',
  icon: Icons.account_balance_wallet,
  trend: StatsCard.trendUp,
)
```

#### `StatsGrid`
Grid of stat cards.

```dart
StatsGrid(
  stats: [
    StatData('Income', '\$5,000', Icons.arrow_downward),
    StatData('Expenses', '\$3,500', Icons.arrow_upward),
  ],
)
```

#### `GlassCard`
Frosted glass effect card.

```dart
GlassCard(
  blur: 10,
  opacity: 0.2,
  child: YourContent(),
)
```

#### `GradientText`
Text with gradient fill.

```dart
GradientText(
  'Premium Feature',
  gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
)
```

### Pagination

#### `PaginatedListView`
List with pagination support.

```dart
PaginatedListView<Transaction>(
  itemBuilder: (context, transaction) => TransactionTile(transaction),
  loadMore: () => loadMoreTransactions(),
  hasMore: true,
)
```

#### `SliverPaginatedList`
Sliver variant for CustomScrollView.

```dart
SliverPaginatedList<Item>(
  itemBuilder: (context, item) => ItemTile(item),
  loadMore: () => loadMore(),
)
```

#### `PaginatedGridView`
Grid with pagination.

```dart
PaginatedGridView<Item>(
  itemBuilder: (context, item) => ItemCard(item),
  crossAxisCount: 2,
)
```

### Animations

#### `MicroInteraction`
Subtle scale animation on tap.

```dart
MicroInteraction(
  child: YourButton(),
  onTap: () => action(),
)
```

#### `RippleAnimation`
Expanding ripple effect.

```dart
RippleAnimation(
  child: Icon(Icons.favorite),
)
```

#### `ShakeAnimation`
Shake effect (for errors).

```dart
ShakeAnimation(
  child: ErrorWidget(),
)
```

#### `PulseAnimation`
Pulsing scale animation.

```dart
PulseAnimation(
  child: NotificationBadge(),
)
```

#### `SlideInAnimation`
Slide in from direction.

```dart
SlideInAnimation(
  direction: SlideDirection.left,
  child: YourWidget(),
)
```

#### `FadeInAnimation`
Fade in effect.

```dart
FadeInAnimation(
  child: YourWidget(),
  duration: Duration(milliseconds: 300),
)
```

### Dialogs

#### `ConfirmationDialog`
Standard confirmation dialog.

```dart
ConfirmationDialog.show(
  context,
  title: 'Delete Transaction?',
  message: 'This action cannot be undone',
  confirmText: 'Delete',
  onConfirm: () => delete(),
)
```

#### `DetailedConfirmationDialog`
Confirmation with additional details.

```dart
DetailedConfirmationDialog.show(
  context,
  title: 'Export Data',
  details: '100 transactions will be exported',
  onConfirm: () => export(),
)
```

### Navigation

#### `NavigablePageView`
Page view with navigation arrows.

```dart
NavigablePageView(
  children: [Page1(), Page2(), Page3()],
)
```

### Refresh

#### `PullToRefreshWrapper`
Wraps content with pull-to-refresh.

```dart
PullToRefreshWrapper(
  onRefresh: () async => await refresh(),
  child: YourScrollableContent(),
)
```

---

## Card Variants

All cards support optional `onTap` for interactivity.

### `StandardCard`
Basic Material card.

```dart
StandardCard(
  child: Text('Content'),
  padding: EdgeInsets.all(16),
  backgroundColor: Colors.white,
  elevation: 2,
  onTap: () => navigate(),
)
```

### `ElevatedCard`
Card with custom shadow elevation.

```dart
ElevatedCard(
  child: Text('Content'),
  elevation: 8,
)
```

### `GradientCard`
Card with gradient background.

```dart
// Using predefined gradients
GradientCard.emerald(
  child: Text('Success'),
)

GradientCard.blue(
  child: Text('Info'),
)

// Custom gradient
GradientCard.twoColor(
  startColor: Colors.pink,
  endColor: Colors.purple,
  child: Text('Custom'),
)
```

### `OutlinedCard`
Card with border.

```dart
OutlinedCard(
  child: Text('Content'),
  borderColor: Colors.blue,
  borderWidth: 2,
)
```

### `CompactCard`
Minimal padding card.

```dart
CompactCard(
  child: ListTile(title: Text('Item')),
)
```

### `InfoCard`
Status message card with icon.

```dart
// Info variant
InfoCard.info(
  message: 'Your data is synced',
)

// Warning variant
InfoCard.warning(context,
  message: 'Budget limit approaching',
)

// Error variant
InfoCard.error(context,
  message: 'Failed to sync',
)

// Success variant
InfoCard.success(context,
  message: 'Transaction saved',
)
```

---

## Utilities

### Calculation Helpers (`lib/utils/calculation_helpers.dart`)

#### Financial Calculations

```dart
// Calculate savings rate
double rate = calculateSavingsRate(income: 5000, expenses: 3500);
// Returns: 0.3 (30%)

// Calculate budget compliance
double compliance = calculateBudgetCompliance(spent: 800, budget: 1000);
// Returns: 0.2 (20% under budget)

// Calculate progress
double progress = calculateProgress(current: 75, target: 100);
// Returns: 0.75 (75%)

// Calculate net worth
double netWorth = calculateNetWorth(assets: 50000, liabilities: 20000);
// Returns: 30000

// Calculate percentage change
double change = calculatePercentageChange(oldValue: 100, newValue: 150);
// Returns: 50.0 (50% increase)

// Calculate average
double avg = calculateAverage([100, 200, 300]);
// Returns: 200.0

// Check budget status
bool isOver = isBudgetOverLimit(spent: 1100, budget: 1000);
bool isNear = isBudgetNearLimit(spent: 950, budget: 1000);

// Calculate remaining
double remaining = calculateRemainingBudget(budget: 1000, spent: 750);
// Returns: 250

// Calculate spending ratio
double ratio = calculateSpendingRatio(amount: 500, total: 2000);
// Returns: 0.25 (25%)
```

---

## Formatters

### Currency Formatter (`lib/core/formatters.dart`)

```dart
import 'package:pocket_flow/core/formatters.dart';

// Standard format: $1,234.56
String formatted = CurrencyFormatter.format(1234.56);

// Compact format: $1.2K
String compact = CurrencyFormatter.formatCompact(1234);

// No decimals: $1,234
String noDecimals = CurrencyFormatter.formatNoDecimals(1234.56);

// Custom decimals
String custom = CurrencyFormatter.format(1234.5678, decimals: 3);
// Returns: $1,234.568
```

### Date Formatter

```dart
import 'package:pocket_flow/core/formatters.dart';

DateTime date = DateTime.now();

// Short: "Jan 5"
String short = DateFormatter.short(date);

// Medium: "Jan 5, 2024"
String medium = DateFormatter.medium(date);

// With time: "5 Jan, 3:45 PM"
String dateTime = DateFormatter.dateTime(date);

// Full: "Jan 5, 2024 3:45 PM"
String full = DateFormatter.full(date);

// Time only: "3:45 PM"
String time = DateFormatter.timeOnly(date);

// Year and month: "January 2024"
String yearMonth = DateFormatter.yearMonth(date);

// For CSV: "2024-01-05"
String csv = DateFormatter.csv(date);

// For filenames: "20240105_1545"
String filename = DateFormatter.filename(date);

// Relative: "Today", "Yesterday", or date
String relative = DateFormatter.relative(date);

// Custom pattern
String custom = DateFormatter.custom(date, 'EEE, MMM d');
// Returns: "Mon, Jan 5"
```

### Number Formatter

```dart
import 'package:pocket_flow/core/formatters.dart';

// Percentage: "45.6%"
String pct = NumberFormatter.percentage(45.6);

// Compact: "1.2K", "45M"
String compact = NumberFormatter.compact(1234);

// With separator: "1,234,567"
String separated = NumberFormatter.withSeparator(1234567);

// Fixed decimals: "123.46"
String decimal = NumberFormatter.decimal(123.456, 2);
```

---

## Extensions

### Color Extensions (`lib/core/color_extensions.dart`)

```dart
import 'package:pocket_flow/core/color_extensions.dart';

Color primary = Colors.blue;

// Opacity helpers
Color subtle = primary.subtle;        // 60% opacity
Color lighter = primary.lighter;      // 70% opacity
Color medium = primary.medium;        // 50% opacity
Color faint = primary.faint;         // 30% opacity
Color veryFaint = primary.veryFaint; // 10% opacity

// Lighten/darken
Color darker = primary.darken(0.2);   // 20% darker
Color brighter = primary.lighten(0.1); // 10% lighter

// Get contrasting color
Color textColor = primary.contrastingColor; // Black or white

// Blend colors
Color blended = primary.blend(Colors.red, 0.5); // 50% blend
```

### Theme Context Extension

```dart
import 'package:pocket_flow/core/color_extensions.dart';

// In a widget's build method:
@override
Widget build(BuildContext context) {
  // Quick access to colors
  Color primary = context.colors.primary;
  Color surface = context.colors.surface;
  
  // Quick access to text theme
  TextStyle headline = context.textTheme.headlineMedium;
  
  // Check theme mode
  bool isDark = context.isDarkMode;
  bool isLight = context.isLightMode;
  
  return Container(
    color: context.colors.surface,
    child: Text('Hello', style: context.textTheme.bodyLarge),
  );
}
```

### Predefined Opacity Constants

```dart
import 'package:pocket_flow/core/color_extensions.dart';

// Use in your code
opacity: AppOpacity.high,       // 0.87
opacity: AppOpacity.medium,     // 0.6
opacity: AppOpacity.disabled,   // 0.38
opacity: AppOpacity.subtle,     // 0.5
opacity: AppOpacity.faint,      // 0.3
opacity: AppOpacity.veryFaint,  // 0.1
opacity: AppOpacity.overlay,    // 0.16
opacity: AppOpacity.hover,      // 0.08
```

---

## Screen Components

### Home Screen Components (`lib/screens/home/components/`)

All home screen components are exported from `home_components.dart`:

```dart
import 'package:pocket_flow/screens/home/components/home_components.dart';
```

**Available Components:**
- `NetWorthCard` - Displays total net worth with trend
- `BalanceCard` - Shows current balance
- `MonthlySummaryCard` - Monthly income/expense summary
- `StatCard` - Individual stat display
- `StatsGrid` - Grid of multiple stats
- `RecurringOverviewCard` - Recurring transactions overview
- `BudgetOverviewCard` - Budget summary
- `SavingsOverviewCard` - Savings goals overview
- `SpendingCard` - Spending breakdown
- `RecentCard` - Recent transactions
- `QuickActions` - Quick action buttons
- `SpendingSnapshot` - Visual spending breakdown
- `BudgetCards` - Budget progress cards
- `RecentTransactions` - Transaction list
- `AlertsInsights` - Smart insights
- `AccountsQuickView` - Account balances
- `TopBar` - Home screen app bar

### Figma Home Components (`lib/screens/figma/home/components/`)

```dart
import 'package:pocket_flow/screens/figma/home/components/home_components.dart';
```

**Available Components:**
- `InteractiveDonut` - Interactive donut chart
- `BudgetProgressPage` - Budget progress visualization
- `HomeHeader` - Figma-style header
- `HomeStatsRow` - Statistics row
- `HomeRecentTransactions` - Transaction list
- `HomeSmartInsights` - AI insights
- `HomeAccountsOverview` - Account summary
- `HomeTransactionItem` - Individual transaction
- `CarouselArrow` - Navigation arrow

### Chat Components (`lib/screens/chat/components/`)

```dart
import 'package:pocket_flow/screens/chat/components/chat_components.dart';
```

**Available Components:**
- `MessageBubble` - Chat message bubble
- `ChatInputBar` - Message input field
- `TypingIndicator` - "AI is typing..." indicator
- `ChatSuggestions` - Quick suggestion chips
- `TransactionTile` - Transaction in chat
- `ApiKeySetup` - API key configuration

### Profile Components (`lib/screens/profile/components/`)

```dart
import 'package:pocket_flow/screens/profile/components/profile_components.dart';
```

**Available Components:**
- `ProfileHeader` - User profile header
- `AccountHealthCard` - Account health metrics
- `BackupSection` - Backup settings
- `PreferencesSection` - User preferences
- `SmsMonitoringSection` - SMS monitoring settings
- `DataManagementSection` - Data management options
- `ProfileDialogs` - Various profile dialogs

### Settings Components (`lib/screens/figma/settings/components/`)

```dart
import 'package:pocket_flow/screens/figma/settings/components/settings_components.dart';
```

**Available Components:**
- `AITab` - AI configuration tab
- `BackupTab` - Backup settings tab
- `PreferencesTab` - Preferences tab
- `AppearanceSection` - Theme & appearance
- `SettingsCard` - Standard settings card
- `SettingsWidgets` - Reusable settings widgets
- `BackupWidgets` - Backup UI components

### Transaction Components (`lib/screens/figma/transactions/components/`)

```dart
import 'package:pocket_flow/screens/figma/transactions/components/transactions_components.dart';
```

**Available Components:**
- `TransactionCard` - Individual transaction card
- `TransactionList` - List of transactions
- `TransactionSummaryCard` - Summary statistics
- `AccountCarousel` - Account selector carousel
- `AccountChip` - Account filter chip
- `TransactionHelpers` - Helper functions

### Figma Shared Widgets (`lib/widgets/figma/`)

```dart
import 'package:pocket_flow/widgets/figma/figma_widgets.dart';
```

**Available Components:**
- `TimeFilterBar` - Time period filter
- `ScreenHeader` - Standard screen header
- `GlobalFilterButton` - Global filter button
- `FigmaSectionTitle` - Section title
- `FigmaGradientCard` - Gradient card
- `FigmaPanel` - Panel container
- `FigmaProgressBar` - Progress indicator
- `FigmaBadge` - Status badge
- `FigmaIconCircle` - Circular icon
- `CalendarFab` - Calendar FAB
- `SpeedDialFab` - Speed dial FAB

---

## Best Practices

### Using Formatters

❌ **Don't:**
```dart
final fmt = NumberFormat.currency(symbol: '\$');
final formatted = fmt.format(amount);
```

✅ **Do:**
```dart
import 'package:pocket_flow/core/formatters.dart';

final formatted = CurrencyFormatter.format(amount);
```

### Using Color Extensions

❌ **Don't:**
```dart
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
```

✅ **Do:**
```dart
import 'package:pocket_flow/core/color_extensions.dart';

color: context.colors.onSurface.subtle
```

### Using Cards

❌ **Don't:**
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(...)],
  ),
  padding: EdgeInsets.all(16),
  child: myContent,
)
```

✅ **Do:**
```dart
import 'package:pocket_flow/widgets/cards/cards.dart';

StandardCard(
  child: myContent,
)
```

### Using Calculations

❌ **Don't:**
```dart
final rate = income > 0 ? (income - expenses) / income : 0.0;
```

✅ **Do:**
```dart
import 'package:pocket_flow/utils/calculation_helpers.dart';

final rate = calculateSavingsRate(income, expenses);
```

---

## Component Checklist

When creating new components:

- [ ] Use theme colors via `context.colors` or `Theme.of(context).colorScheme`
- [ ] Support both light and dark themes
- [ ] Add comprehensive documentation
- [ ] Include usage examples
- [ ] Make components reusable with parameters
- [ ] Use formatters for currency/dates
- [ ] Use color extensions for opacity
- [ ] Add barrel export if in dedicated directory
- [ ] Consider responsive design
- [ ] Add appropriate animations

---

## Getting Help

- **Widget not documented?** Check the source file for inline documentation
- **Need a new component?** Follow existing patterns in similar widgets
- **Found a bug?** Check the error handling widgets for proper error display
- **Need custom styling?** Use theme extensions and color helpers

---

**Last Updated:** April 17, 2026  
**Component Count:** 80+ reusable widgets and utilities
