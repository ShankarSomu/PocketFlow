import { TrendingUp, TrendingDown, DollarSign, CreditCard, Wallet, ArrowUpRight, ArrowDownRight, Sparkles, Bell } from "lucide-react";
import { motion } from "motion/react";
import { LineChart, Line, AreaChart, Area, PieChart, Pie, Cell, ResponsiveContainer, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts";

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

const spendingData = [
  { month: "Oct", amount: 3200 },
  { month: "Nov", amount: 3800 },
  { month: "Dec", amount: 4100 },
  { month: "Jan", amount: 3500 },
  { month: "Feb", amount: 3900 },
  { month: "Mar", amount: 4231 },
];

const categoryData = [
  { name: "Food", value: 542, color: "#10b981" },
  { name: "Transport", value: 245, color: "#3b82f6" },
  { name: "Shopping", value: 890, color: "#8b5cf6" },
  { name: "Bills", value: 359, color: "#f59e0b" },
  { name: "Other", value: 195, color: "#6b7280" },
];

const accounts = [
  { name: "Checking Account", balance: 8420.42, type: "Chase" },
  { name: "Savings Account", balance: 12500.0, type: "Ally Bank" },
  { name: "Credit Card", balance: -1340.0, type: "Visa" },
];

export function HomeScreen() {
  return (
    <div className="min-h-full">
      {/* Header */}
      <div className="bg-gradient-to-br from-emerald-600 via-emerald-500 to-blue-600 px-5 pt-12 pb-32 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        <div className="relative">
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-center justify-between mb-8"
          >
            <div>
              <p className="text-emerald-100 text-sm mb-1">Welcome back</p>
              <h1 className="text-3xl text-white">John Doe</h1>
            </div>
            <motion.button
              whileTap={{ scale: 0.9 }}
              className="relative p-3 bg-white/10 backdrop-blur-sm rounded-full border border-white/20"
            >
              <Bell className="size-5 text-white" />
              <span className="absolute top-1 right-1 size-2 bg-red-500 rounded-full border-2 border-white" />
            </motion.button>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.2 }}
            className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl"
          >
            <p className="text-emerald-100 text-sm mb-2">Total Balance</p>
            <h2 className="text-5xl text-white mb-4 font-light">$24,580.42</h2>
            <div className="flex items-center gap-2">
              <div className="flex items-center gap-1 bg-white/20 px-3 py-1.5 rounded-full">
                <TrendingUp className="size-4 text-white" />
                <span className="text-sm text-white">+12.5%</span>
              </div>
              <span className="text-sm text-emerald-100">this month</span>
            </div>
          </motion.div>
        </div>
      </div>

      {/* Content */}
      <div className="px-5 -mt-20 space-y-5 pb-6">
        {/* Quick Stats */}
        <div className="grid grid-cols-2 gap-4">
          {[
            { label: "Income", value: "$8,450", change: "+5.2%", trend: "up", color: "from-emerald-500 to-emerald-600" },
            { label: "Expenses", value: "$4,231", change: "-2.1%", trend: "down", color: "from-blue-500 to-blue-600" },
          ].map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileTap={{ scale: 0.98 }}
              className="bg-white/80 backdrop-blur-sm rounded-2xl p-5 shadow-xl shadow-black/5 border border-neutral-200/50"
            >
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-neutral-500">{stat.label}</span>
                <div className={`p-1.5 rounded-lg bg-gradient-to-br ${stat.color}`}>
                  {stat.trend === "up" ? (
                    <TrendingUp className="size-3.5 text-white" strokeWidth={2.5} />
                  ) : (
                    <TrendingDown className="size-3.5 text-white" strokeWidth={2.5} />
                  )}
                </div>
              </div>
              <div className="text-2xl mb-2 text-slate-900">{stat.value}</div>
              <div className={`text-xs font-medium ${stat.trend === "up" ? "text-emerald-600" : "text-blue-600"}`}>
                {stat.change} vs last month
              </div>
            </motion.div>
          ))}
        </div>

        {/* Spending Chart */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl p-5 shadow-xl shadow-black/5 border border-neutral-200/50"
        >
          <h3 className="text-lg mb-4 text-slate-900">Spending Trend</h3>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={spendingData}>
              <defs>
                <linearGradient id="colorAmount" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} stroke="#9ca3af" />
              <YAxis tick={{ fontSize: 12 }} stroke="#9ca3af" />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'rgba(255, 255, 255, 0.95)',
                  border: '1px solid #e5e7eb',
                  borderRadius: '12px',
                  boxShadow: '0 10px 15px -3px rgba(0, 0, 0, 0.1)'
                }}
              />
              <Area
                type="monotone"
                dataKey="amount"
                stroke="#10b981"
                strokeWidth={3}
                fill="url(#colorAmount)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Category Breakdown */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl p-5 shadow-xl shadow-black/5 border border-neutral-200/50"
        >
          <h3 className="text-lg mb-4 text-slate-900">Spending by Category</h3>
          <div className="flex items-center gap-6">
            <ResponsiveContainer width={140} height={140}>
              <PieChart>
                <Pie
                  data={categoryData}
                  cx="50%"
                  cy="50%"
                  innerRadius={45}
                  outerRadius={65}
                  paddingAngle={2}
                  dataKey="value"
                >
                  {categoryData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div className="flex-1 space-y-2">
              {categoryData.map((cat) => (
                <div key={cat.name} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="size-3 rounded-full" style={{ backgroundColor: cat.color }} />
                    <span className="text-sm text-neutral-600">{cat.name}</span>
                  </div>
                  <span className="text-sm font-medium text-slate-900">${cat.value}</span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>

        {/* Recent Transactions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl p-5 shadow-xl shadow-black/5 border border-neutral-200/50"
        >
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg text-slate-900">Recent Activity</h3>
            <button className="text-sm text-emerald-600 font-medium">See All</button>
          </div>
          <div className="space-y-1">
            {recentTransactions.slice(0, 4).map((transaction, index) => (
              <motion.div
                key={transaction.id}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.8 + index * 0.05 }}
                whileTap={{ scale: 0.98 }}
                className="flex items-center justify-between py-3 px-3 rounded-xl active:bg-emerald-50/50 transition-all"
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`size-10 rounded-xl flex items-center justify-center ${
                      transaction.amount > 0 ? "bg-gradient-to-br from-emerald-100 to-emerald-200" : "bg-gradient-to-br from-neutral-100 to-neutral-200"
                    }`}
                  >
                    {transaction.amount > 0 ? (
                      <ArrowDownRight className="size-4 text-emerald-700" strokeWidth={2.5} />
                    ) : (
                      <ArrowUpRight className="size-4 text-neutral-600" strokeWidth={2.5} />
                    )}
                  </div>
                  <div>
                    <div className="text-sm font-medium text-slate-900">{transaction.description}</div>
                    <div className="text-xs text-neutral-400">{transaction.date}</div>
                  </div>
                </div>
                <div
                  className={`text-base font-medium ${
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
