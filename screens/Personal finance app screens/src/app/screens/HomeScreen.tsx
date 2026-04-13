import { TrendingUp, TrendingDown, DollarSign, CreditCard, Wallet, ArrowUpRight, ArrowDownRight, Sparkles } from "lucide-react";
import { motion } from "motion/react";

const stats = [
  { label: "Total Balance", value: "$24,580.42", change: "+12.5%", trend: "up" },
  { label: "Monthly Income", value: "$8,450.00", change: "+5.2%", trend: "up" },
  { label: "Monthly Expenses", value: "$4,231.89", change: "-2.1%", trend: "down" },
  { label: "Savings Rate", value: "49.9%", change: "+3.4%", trend: "up" },
];

const recentTransactions = [
  { id: 1, description: "Grocery Store", amount: -89.42, category: "Food", date: "Apr 13" },
  { id: 2, description: "Salary Deposit", amount: 8450.0, category: "Income", date: "Apr 12" },
  { id: 3, description: "Electric Bill", amount: -124.56, category: "Utilities", date: "Apr 11" },
  { id: 4, description: "Coffee Shop", amount: -12.5, category: "Food", date: "Apr 10" },
  { id: 5, description: "Gas Station", amount: -65.0, category: "Transportation", date: "Apr 9" },
];

const accounts = [
  { name: "Checking Account", balance: 8420.42, type: "Chase" },
  { name: "Savings Account", balance: 12500.0, type: "Ally Bank" },
  { name: "Credit Card", balance: -1340.0, type: "Visa" },
];

export function HomeScreen() {
  return (
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-emerald-800 bg-clip-text text-transparent">Overview</h1>
          <p className="text-neutral-500">Your financial snapshot</p>
        </div>
        <div className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-emerald-50 to-blue-50 rounded-full border border-emerald-200/50">
          <Sparkles className="size-4 text-emerald-600" />
          <span className="text-sm text-emerald-700">All systems healthy</span>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <div className="grid grid-cols-4 gap-6">
        {stats.map((stat, index) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            whileHover={{ y: -4, scale: 1.02 }}
            className="group relative"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/0 to-blue-500/0 group-hover:from-emerald-500/5 group-hover:to-blue-500/5 rounded-2xl transition-all" />
            <div className="relative bg-white/80 backdrop-blur-sm p-6 rounded-2xl border border-neutral-200/50 shadow-lg shadow-black/5 group-hover:shadow-xl group-hover:shadow-emerald-500/10 transition-all">
              <div className="flex items-start justify-between mb-4">
                <span className="text-sm text-neutral-500">{stat.label}</span>
                <div className={`p-2 rounded-lg ${stat.trend === "up" ? "bg-emerald-100" : "bg-red-100"}`}>
                  {stat.trend === "up" ? (
                    <TrendingUp className="size-4 text-emerald-600" strokeWidth={2.5} />
                  ) : (
                    <TrendingDown className="size-4 text-red-600" strokeWidth={2.5} />
                  )}
                </div>
              </div>
              <div className="text-3xl mb-3 bg-gradient-to-br from-slate-900 to-slate-700 bg-clip-text text-transparent">{stat.value}</div>
              <div className="flex items-center gap-2">
                <div
                  className={`text-sm font-medium ${
                    stat.trend === "up" ? "text-emerald-600" : "text-red-600"
                  }`}
                >
                  {stat.change}
                </div>
                <span className="text-xs text-neutral-400">this month</span>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Accounts */}
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.5 }}
          className="col-span-1 bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-lg shadow-black/5"
        >
          <h2 className="text-xl mb-6">Accounts</h2>
          <div className="space-y-4">
            {accounts.map((account, index) => (
              <motion.div
                key={account.name}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.6 + index * 0.1 }}
                whileHover={{ x: 4 }}
                className="group p-4 rounded-xl hover:bg-gradient-to-r hover:from-emerald-50 hover:to-blue-50 transition-all cursor-pointer"
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-neutral-600 group-hover:text-emerald-700 transition-colors">{account.name}</span>
                  <span
                    className={`text-xl font-medium ${
                      account.balance < 0 ? "text-red-600" : "text-slate-900"
                    }`}
                  >
                    ${Math.abs(account.balance).toLocaleString("en-US", {
                      minimumFractionDigits: 2,
                    })}
                  </span>
                </div>
                <div className="text-xs text-neutral-400">{account.type}</div>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Recent Transactions */}
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.5 }}
          className="col-span-2 bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-lg shadow-black/5"
        >
          <h2 className="text-xl mb-6">Recent Transactions</h2>
          <div className="space-y-1">
            {recentTransactions.map((transaction, index) => (
              <motion.div
                key={transaction.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.6 + index * 0.05 }}
                whileHover={{ x: 4, backgroundColor: "rgba(16, 185, 129, 0.03)" }}
                className="flex items-center justify-between py-4 px-3 rounded-xl transition-all cursor-pointer"
              >
                <div className="flex items-center gap-4">
                  <div
                    className={`size-11 rounded-xl flex items-center justify-center shadow-sm ${
                      transaction.amount > 0 ? "bg-gradient-to-br from-emerald-100 to-emerald-200" : "bg-gradient-to-br from-neutral-100 to-neutral-200"
                    }`}
                  >
                    {transaction.amount > 0 ? (
                      <ArrowDownRight className="size-5 text-emerald-700" strokeWidth={2} />
                    ) : (
                      <ArrowUpRight className="size-5 text-neutral-600" strokeWidth={2} />
                    )}
                  </div>
                  <div>
                    <div className="text-sm font-medium text-slate-900">{transaction.description}</div>
                    <div className="text-xs text-neutral-400">
                      {transaction.category} · {transaction.date}
                    </div>
                  </div>
                </div>
                <div
                  className={`text-lg font-medium ${
                    transaction.amount > 0 ? "text-emerald-600" : "text-slate-900"
                  }`}
                >
                  {transaction.amount > 0 ? "+" : ""}${Math.abs(transaction.amount).toFixed(2)}
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </div>
  );
}
