# Quick Reference: New Utilities

This guide shows the most impactful new utilities for immediate use.

## 🎯 Top 5 Most Useful Additions

### 1. Currency Formatting (Replaces 60+ NumberFormat instances)

```dart
import 'package:pocket_flow/core/formatters.dart';

// OLD WAY (repeated everywhere):
final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final formatted = fmt.format(amount);

// NEW WAY (one line):
final formatted = CurrencyFormatter.format(amount);
final compact = CurrencyFormatter.formatCompact(1234); // "$1.2K"
final noDecimals = CurrencyFormatter.formatNoDecimals(1234.56); // "$1,234"
```

### 2. Date Formatting (18+ patterns unified)

```dart
import 'package:pocket_flow/core/formatters.dart';

// OLD WAY:
DateFormat('MMM d').format(date)
DateFormat('MMM d, yyyy').format(date)
DateFormat('d MMM, h:mm a').format(date)

// NEW WAY:
DateFormatter.short(date)     // "Jan 5"
DateFormatter.medium(date)    // "Jan 5, 2024"
DateFormatter.dateTime(date)  // "5 Jan, 3:45 PM"
DateFormatter.relative(date)  // "Today", "Yesterday", etc.
```

### 3. Color Opacity (80+ withValues calls simplified)

```dart
import 'package:pocket_flow/core/color_extensions.dart';

// OLD WAY:
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)

// NEW WAY:
color: context.colors.onSurface.subtle     // 60%
color: context.colors.onSurface.faint      // 30%
color: context.colors.onSurface.veryFaint  // 10%
color: context.colors.onSurface.lighter    // 70%
```

### 4. Quick Theme Access

```dart
import 'package:pocket_flow/core/color_extensions.dart';

// OLD WAY:
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
final isDark = Theme.of(context).brightness == Brightness.dark;

// NEW WAY:
final colors = context.colors;
final text = context.textTheme;
final isDark = context.isDarkMode;
```

### 5. Financial Calculations

```dart
import 'package:pocket_flow/utils/calculation_helpers.dart';

// Savings rate
final rate = calculateSavingsRate(5000, 3500); // Returns 0.3 (30%)

// Budget compliance
final compliance = calculateBudgetCompliance(800, 1000); // 0.2 (20% under)

// Progress
final progress = calculateProgress(75, 100); // 0.75 (75%)

// Budget status checks
bool isOver = isBudgetOverLimit(spent, budget);
bool isNearLimit = isBudgetNearLimit(spent, budget); // Within 10%
```

## 📦 New Card Components

```dart
import 'package:pocket_flow/widgets/cards/cards.dart';

// Replace custom Card/Container patterns
StandardCard(child: content)
ElevatedCard(child: content, elevation: 8)
GradientCard.emerald(child: content)
OutlinedCard(child: content, borderColor: Colors.blue)
InfoCard.success(context, message: 'Saved successfully')
```

## 🎨 Color Helpers

```dart
// Darken/Lighten
final darker = color.darken(0.2);   // 20% darker
final lighter = color.lighten(0.1); // 10% lighter

// Get contrasting text color
final textColor = backgroundColor.contrastingColor; // Black or white

// Blend colors
final blended = color1.blend(color2, 0.5); // 50% blend
```

## 📊 Theme Gradients

```dart
import 'package:pocket_flow/theme/app_theme.dart';

// Predefined gradients
AppTheme.emeraldGradient
AppTheme.blueGradient
AppTheme.emeraldBlueGradient
AppTheme.cardDarkGradient

// Create custom gradients
AppTheme.twoColorGradient(Colors.pink, Colors.purple)
AppTheme.verticalGradient(Colors.blue, Colors.cyan)
AppTheme.horizontalGradient(Colors.red, Colors.orange)
```

## 🔢 Number Formatting

```dart
import 'package:pocket_flow/core/formatters.dart';

NumberFormatter.percentage(45.6)        // "45.6%"
NumberFormatter.percentage(45.6, decimals: 0) // "46%"
NumberFormatter.compact(1234567)        // "1.2M"
NumberFormatter.withSeparator(1234567)  // "1,234,567"
NumberFormatter.decimal(123.456, 2)     // "123.46"
```

## ✨ Migration Examples

### Example 1: Transaction Card

```dart
// BEFORE
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: AppTheme.cardShadow,
  ),
  padding: EdgeInsets.all(16),
  child: Row(
    children: [
      Text(
        DateFormat('MMM d').format(transaction.date),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      Text(
        NumberFormat.currency(symbol: '\$').format(transaction.amount),
      ),
    ],
  ),
)

// AFTER
import 'package:pocket_flow/core/formatters.dart';
import 'package:pocket_flow/core/color_extensions.dart';
import 'package:pocket_flow/widgets/cards/cards.dart';

StandardCard(
  child: Row(
    children: [
      Text(
        DateFormatter.short(transaction.date),
        style: TextStyle(color: context.colors.onSurface.subtle),
      ),
      Text(CurrencyFormatter.format(transaction.amount)),
    ],
  ),
)
```

### Example 2: Stats Display

```dart
// BEFORE
final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final savingsRate = income > 0 ? (income - expenses) / income : 0.0;

Text('${(savingsRate * 100).toStringAsFixed(0)}%')
Text(fmt.format(amount))

// AFTER
import 'package:pocket_flow/core/formatters.dart';
import 'package:pocket_flow/utils/calculation_helpers.dart';

final savingsRate = calculateSavingsRate(income, expenses);

Text(NumberFormatter.percentage(savingsRate * 100, decimals: 0))
Text(CurrencyFormatter.formatNoDecimals(amount))
```

### Example 3: Colored Badge

```dart
// BEFORE
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    Icons.check,
    color: Theme.of(context).colorScheme.primary,
  ),
)

// AFTER
import 'package:pocket_flow/core/color_extensions.dart';

Container(
  decoration: BoxDecoration(
    color: context.colors.primary.veryFaint,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    Icons.check,
    color: context.colors.primary,
  ),
)
```

## 📝 Import Checklist

When refactoring a file, add these imports:

```dart
// For currency and date formatting
import 'package:pocket_flow/core/formatters.dart';

// For color helpers and theme extensions
import 'package:pocket_flow/core/color_extensions.dart';

// For card components
import 'package:pocket_flow/widgets/cards/cards.dart';

// For financial calculations
import 'package:pocket_flow/utils/calculation_helpers.dart';
```

## 🎯 Priority Files to Update

Based on duplication analysis, these files will benefit most:

1. **High Impact** (10+ formatter instances):
   - `lib/screens/figma/home/components/interactive_donut.dart`
   - `lib/screens/home/components/monthly_summary_card.dart`
   - `lib/screens/home/components/spending_snapshot.dart`
   - `lib/screens/figma/home/components/budget_progress_page.dart`

2. **Medium Impact** (5-10 instances):
   - `lib/screens/home/components/stats_grid.dart`
   - `lib/screens/figma/home/components/home_stats_row.dart`
   - `lib/screens/profile/components/account_health_card.dart`

3. **All components with color opacity** (80+ files):
   - Any file with `.withValues(alpha:)` patterns

## 💡 Tips

1. **Use Find & Replace carefully**: Search for `NumberFormat.currency` and replace with formatters
2. **Test after migration**: Verify formatting matches previous output
3. **Update gradually**: Start with one component at a time
4. **Keep imports clean**: Remove unused NumberFormat/DateFormat imports after switching

## 📚 Full Documentation

See `COMPONENT_LIBRARY.md` for comprehensive documentation of all 80+ components and utilities.
