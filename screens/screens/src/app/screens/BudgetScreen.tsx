import { Plus, AlertTriangle } from "lucide-react";
import { Button } from "../components/ui/button";
import { Progress } from "../components/ui/progress";
import { motion } from "motion/react";

const budgets = [
  {
    category: "Food & Dining",
    spent: 542.89,
    limit: 800,
    color: "bg-emerald-500",
    icon: "🍔",
  },
  {
    category: "Transportation",
    spent: 245.5,
    limit: 400,
    color: "bg-blue-500",
    icon: "🚗",
  },
  {
    category: "Shopping",
    spent: 890.23,
    limit: 600,
    color: "bg-violet-500",
    icon: "🛍️",
  },
  {
    category: "Entertainment",
    spent: 156.0,
    limit: 300,
    color: "bg-pink-500",
    icon: "🎬",
  },
  {
    category: "Utilities",
    spent: 234.67,
    limit: 350,
    color: "bg-amber-500",
    icon: "⚡",
  },
  {
    category: "Healthcare",
    spent: 89.0,
    limit: 200,
    color: "bg-red-500",
    icon: "🏥",
  },
];

export function BudgetScreen() {
  const totalSpent = budgets.reduce((sum, b) => sum + b.spent, 0);
  const totalLimit = budgets.reduce((sum, b) => sum + b.limit, 0);
  const overBudgetCount = budgets.filter(b => (b.spent / b.limit) > 1).length;

  return (
    <div className="min-h-full">
      {/* Header */}
      <div className="bg-gradient-to-br from-violet-600 via-purple-600 to-fuchsia-600 px-5 pt-12 pb-8">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between mb-6"
        >
          <div>
            <h1 className="text-3xl mb-1 text-white">Budget</h1>
            <p className="text-violet-100">Track your spending</p>
          </div>
          <motion.button
            whileTap={{ scale: 0.9 }}
            className="p-3 bg-white/20 backdrop-blur-sm rounded-full border border-white/30"
          >
            <Plus className="size-5 text-white" />
          </motion.button>
        </motion.div>

        {/* Budget Summary */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20"
        >
          <div className="text-violet-100 text-sm mb-2">Monthly Budget</div>
          <div className="flex items-end gap-2 mb-4">
            <div className="text-4xl text-white font-light">
              ${totalSpent.toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </div>
            <div className="text-lg text-violet-200 mb-1">
              / ${totalLimit.toLocaleString("en-US")}
            </div>
          </div>
          <Progress value={(totalSpent / totalLimit) * 100} className="h-3 bg-white/20 [&>div]:bg-white mb-3" />
          <div className="flex items-center justify-between text-sm">
            <span className="text-violet-100">{((totalSpent / totalLimit) * 100).toFixed(1)}% spent</span>
            <span className="text-white font-medium">${(totalLimit - totalSpent).toFixed(2)} left</span>
          </div>
          {overBudgetCount > 0 && (
            <div className="mt-4 flex items-center gap-2 bg-red-500/20 px-3 py-2 rounded-full border border-red-400/30">
              <AlertTriangle className="size-4 text-red-200" />
              <span className="text-sm text-red-100">{overBudgetCount} categories over budget</span>
            </div>
          )}
        </motion.div>
      </div>

      {/* Budget Categories */}
      <div className="px-5 py-6 space-y-4">
        {budgets.map((budget, index) => {
          const percentage = (budget.spent / budget.limit) * 100;
          const isOverBudget = percentage > 100;

          return (
            <motion.div
              key={budget.category}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileTap={{ scale: 0.98 }}
              className={`bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5 ${isOverBudget ? "border-red-200" : ""}`}
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="text-3xl">{budget.icon}</div>
                  <div>
                    <div className="text-base font-medium text-slate-900">{budget.category}</div>
                    <div className="text-xs text-neutral-400">This month</div>
                  </div>
                </div>
                {isOverBudget && (
                  <div className="p-1.5 bg-red-100 rounded-lg">
                    <AlertTriangle className="size-4 text-red-600" />
                  </div>
                )}
              </div>

              <div className="space-y-3">
                <div className="flex items-end justify-between">
                  <div>
                    <div className="text-xs text-neutral-400 mb-1">Spent</div>
                    <div className={`text-2xl font-light ${isOverBudget ? "text-red-600" : "text-slate-900"}`}>
                      ${budget.spent.toFixed(2)}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-neutral-400 mb-1">Budget</div>
                    <div className="text-xl text-neutral-500 font-light">${budget.limit}</div>
                  </div>
                </div>

                <Progress
                  value={Math.min(percentage, 100)}
                  className={`h-2.5 ${isOverBudget ? "[&>div]:bg-gradient-to-r [&>div]:from-red-500 [&>div]:to-red-600" : "[&>div]:bg-gradient-to-r [&>div]:from-violet-500 [&>div]:to-purple-600"}`}
                />

                <div className="flex justify-between text-xs">
                  <span className={`font-medium ${isOverBudget ? "text-red-600" : "text-neutral-600"}`}>
                    {percentage.toFixed(1)}% used
                  </span>
                  <span className={`font-medium ${isOverBudget ? "text-red-600" : "text-emerald-600"}`}>
                    {isOverBudget
                      ? `$${(budget.spent - budget.limit).toFixed(2)} over`
                      : `$${(budget.limit - budget.spent).toFixed(2)} left`}
                  </span>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
