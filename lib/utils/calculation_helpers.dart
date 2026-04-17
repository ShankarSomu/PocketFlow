/// Calculation helper utilities
/// Extracted from transaction_helpers and other components
/// Provides reusable calculation logic for financial metrics

/// Calculate savings rate as percentage
/// 
/// [income] - Total income amount
/// [expenses] - Total expense amount
/// Returns savings rate as a value between 0 and 1
double calculateSavingsRate(double income, double expenses) {
  if (income <= 0) return 0.0;
  final savings = income - expenses;
  return (savings / income).clamp(0.0, 1.0);
}

/// Calculate budget compliance percentage
/// 
/// [spent] - Amount spent
/// [budget] - Budget limit
/// Returns compliance as a value between 0 and 1
double calculateBudgetCompliance(double spent, double budget) {
  if (budget <= 0) return 0.0;
  final compliance = 1 - (spent / budget);
  return compliance.clamp(0.0, 1.0);
}

/// Calculate progress percentage
/// 
/// [current] - Current value
/// [target] - Target value
/// Returns progress as a value between 0 and 1
double calculateProgress(double current, double target) {
  if (target <= 0) return 0.0;
  return (current / target).clamp(0.0, 1.0);
}

/// Calculate net worth
/// 
/// [assets] - Total assets
/// [liabilities] - Total liabilities
/// Returns net worth (assets - liabilities)
double calculateNetWorth(double assets, double liabilities) {
  return assets - liabilities;
}

/// Calculate percentage change
/// 
/// [oldValue] - Previous value
/// [newValue] - New value
/// Returns percentage change (can be negative)
double calculatePercentageChange(double oldValue, double newValue) {
  if (oldValue == 0) return 0.0;
  return ((newValue - oldValue) / oldValue) * 100;
}

/// Calculate average of a list of numbers
double calculateAverage(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sum = values.reduce((a, b) => a + b);
  return sum / values.length;
}

/// Calculate total of transaction categories
/// 
/// [categories] - Map of category names to amounts
/// Returns total sum of all category amounts
double calculateCategoryTotal(Map<String, double> categories) {
  if (categories.isEmpty) return 0.0;
  return categories.values.reduce((a, b) => a + b);
}

/// Check if budget is over limit
/// 
/// [spent] - Amount spent
/// [budget] - Budget limit
/// Returns true if over budget
bool isBudgetOverLimit(double spent, double budget) {
  return spent > budget;
}

/// Check if budget is near limit (within 10%)
/// 
/// [spent] - Amount spent
/// [budget] - Budget limit
/// Returns true if within 10% of budget
bool isBudgetNearLimit(double spent, double budget) {
  if (budget <= 0) return false;
  final ratio = spent / budget;
  return ratio >= 0.9 && ratio <= 1.0;
}

/// Calculate remaining budget
/// 
/// [budget] - Total budget
/// [spent] - Amount spent
/// Returns remaining amount (can be negative if over budget)
double calculateRemainingBudget(double budget, double spent) {
  return budget - spent;
}

/// Calculate spending ratio
/// 
/// [amount] - Specific spending amount
/// [total] - Total spending amount
/// Returns ratio as a value between 0 and 1
double calculateSpendingRatio(double amount, double total) {
  if (total <= 0) return 0.0;
  return (amount / total).clamp(0.0, 1.0);
}

/// Check if value is positive (income)
bool isIncome(double amount) => amount > 0;

/// Check if value is negative (expense)
bool isExpense(double amount) => amount < 0;

/// Get absolute value
double getAbsoluteValue(double amount) => amount.abs();

/// Format change with sign
/// Adds + or - prefix to value
String formatChangeWithSign(double value, {int decimals = 1}) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)}';
}

/// Calculate growth rate
/// Returns percentage points change
double calculateGrowthRate(double oldValue, double newValue) {
  if (oldValue == 0) return 0.0;
  return newValue - oldValue;
}

/// Round to nearest multiple
/// Useful for chart scales and axis values
double roundToNearest(double value, double multiple) {
  return (value / multiple).round() * multiple;
}

/// Calculate category percentage
/// Returns formatted percentage string
String calculateCategoryPercentage(double categoryAmount, double totalAmount) {
  if (totalAmount <= 0) return '0%';
  final percentage = (categoryAmount / totalAmount) * 100;
  return '${percentage.toStringAsFixed(1)}%';
}
