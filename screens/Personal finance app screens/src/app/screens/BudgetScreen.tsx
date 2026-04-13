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
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-violet-800 bg-clip-text text-transparent">Budget</h1>
          <p className="text-neutral-500">Track spending by category</p>
        </div>
        <div className="flex items-center gap-3">
          {overBudgetCount > 0 && (
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              className="flex items-center gap-2 px-4 py-2 bg-red-50 text-red-700 rounded-full border border-red-200"
            >
              <AlertTriangle className="size-4" />
              <span className="text-sm">{overBudgetCount} over budget</span>
            </motion.div>
          )}
          <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
            <Button className="bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700 shadow-lg shadow-violet-500/30">
              <Plus className="size-4 mr-2" />
              Add Budget
            </Button>
          </motion.div>
        </div>
      </motion.div>

      {/* Overall Budget */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="relative overflow-hidden bg-gradient-to-br from-white via-white to-violet-50/50 rounded-3xl border border-neutral-200/50 p-8 shadow-xl shadow-black/5"
      >
        <div className="absolute top-0 right-0 w-96 h-96 bg-violet-500/5 rounded-full blur-3xl" />
        <div className="relative">
          <div className="flex items-center justify-between mb-8">
            <div>
              <div className="text-sm text-neutral-500 mb-2">Total Monthly Budget</div>
              <div className="text-5xl mb-2 bg-gradient-to-br from-slate-900 to-violet-800 bg-clip-text text-transparent font-light">
                ${totalSpent.toLocaleString("en-US", { minimumFractionDigits: 2 })}
                <span className="text-2xl text-neutral-400">
                  {" "}
                  / ${totalLimit.toLocaleString("en-US")}
                </span>
              </div>
            </div>
            <div className="text-right">
              <div className="text-sm text-neutral-500 mb-2">Remaining</div>
              <div className="text-4xl text-emerald-600 font-light">
                ${(totalLimit - totalSpent).toLocaleString("en-US", { minimumFractionDigits: 2 })}
              </div>
            </div>
          </div>
          <div className="space-y-3">
            <Progress value={(totalSpent / totalLimit) * 100} className="h-4 bg-neutral-100" />
            <div className="flex justify-between text-sm text-neutral-500">
              <span>{((totalSpent / totalLimit) * 100).toFixed(1)}% used</span>
              <span>{(100 - ((totalSpent / totalLimit) * 100)).toFixed(1)}% remaining</span>
            </div>
          </div>
        </div>
      </motion.div>

      {/* Budget Categories */}
      <div className="grid grid-cols-2 gap-6">
        {budgets.map((budget, index) => {
          const percentage = (budget.spent / budget.limit) * 100;
          const isOverBudget = percentage > 100;

          return (
            <motion.div
              key={budget.category}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileHover={{ y: -4, scale: 1.02 }}
              className="group relative"
            >
              <div className={`absolute inset-0 rounded-2xl transition-all ${isOverBudget ? "bg-gradient-to-br from-red-500/5 to-red-500/10" : "bg-gradient-to-br from-violet-500/0 to-purple-500/0 group-hover:from-violet-500/5 group-hover:to-purple-500/5"}`} />
              <div className="relative bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-lg shadow-black/5 group-hover:shadow-xl transition-all">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-3">
                    <motion.div
                      whileHover={{ scale: 1.2, rotate: 10 }}
                      className="text-4xl"
                    >
                      {budget.icon}
                    </motion.div>
                    <div>
                      <div className="text-xl text-slate-900">{budget.category}</div>
                      <div className="text-xs text-neutral-400">This month</div>
                    </div>
                  </div>
                  {isOverBudget && (
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      className="p-2 bg-red-100 rounded-lg"
                    >
                      <AlertTriangle className="size-4 text-red-600" />
                    </motion.div>
                  )}
                </div>

                <div className="space-y-4">
                  <div className="flex items-end justify-between">
                    <div>
                      <div className="text-xs text-neutral-500 mb-1">Spent</div>
                      <div className={`text-3xl font-light ${isOverBudget ? "text-red-600" : "text-slate-900"}`}>
                        ${budget.spent.toFixed(2)}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-xs text-neutral-500 mb-1">Budget</div>
                      <div className="text-2xl text-neutral-400 font-light">${budget.limit}</div>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Progress
                      value={Math.min(percentage, 100)}
                      className={`h-3 ${isOverBudget ? "[&>div]:bg-gradient-to-r [&>div]:from-red-500 [&>div]:to-red-600" : "[&>div]:bg-gradient-to-r [&>div]:from-violet-500 [&>div]:to-purple-600"}`}
                    />
                    <div className="flex justify-between text-sm">
                      <span
                        className={`font-medium ${
                          isOverBudget ? "text-red-600" : "text-neutral-600"
                        }`}
                      >
                        {percentage.toFixed(1)}% used
                      </span>
                      <span
                        className={`font-medium ${
                          isOverBudget ? "text-red-600" : "text-emerald-600"
                        }`}
                      >
                        {isOverBudget
                          ? `$${(budget.spent - budget.limit).toFixed(2)} over`
                          : `$${(budget.limit - budget.spent).toFixed(2)} left`}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
