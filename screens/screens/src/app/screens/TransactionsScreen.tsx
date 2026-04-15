import { Search, Filter, Download, ArrowUpRight, ArrowDownRight, SlidersHorizontal } from "lucide-react";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { motion } from "motion/react";

const transactions = [
  {
    id: 1,
    description: "Grocery Store",
    amount: -89.42,
    category: "Food & Dining",
    date: "Apr 13, 2026",
    time: "10:23 AM",
    account: "Chase Checking",
    status: "completed",
  },
  {
    id: 2,
    description: "Salary Deposit",
    amount: 8450.0,
    category: "Income",
    date: "Apr 12, 2026",
    time: "12:00 AM",
    account: "Chase Checking",
    status: "completed",
  },
  {
    id: 3,
    description: "Electric Bill",
    amount: -124.56,
    category: "Utilities",
    date: "Apr 11, 2026",
    time: "3:45 PM",
    account: "Chase Checking",
    status: "completed",
  },
  {
    id: 4,
    description: "Coffee Shop",
    amount: -12.5,
    category: "Food & Dining",
    date: "Apr 10, 2026",
    time: "8:15 AM",
    account: "Visa Credit",
    status: "completed",
  },
  {
    id: 5,
    description: "Gas Station",
    amount: -65.0,
    category: "Transportation",
    date: "Apr 9, 2026",
    time: "6:30 PM",
    account: "Visa Credit",
    status: "completed",
  },
  {
    id: 6,
    description: "Online Shopping",
    amount: -234.99,
    category: "Shopping",
    date: "Apr 8, 2026",
    time: "2:00 PM",
    account: "Visa Credit",
    status: "pending",
  },
  {
    id: 7,
    description: "Restaurant",
    amount: -87.34,
    category: "Food & Dining",
    date: "Apr 7, 2026",
    time: "7:45 PM",
    account: "Chase Checking",
    status: "completed",
  },
  {
    id: 8,
    description: "Freelance Payment",
    amount: 1500.0,
    category: "Income",
    date: "Apr 6, 2026",
    time: "9:00 AM",
    account: "Chase Checking",
    status: "completed",
  },
  {
    id: 9,
    description: "Gym Membership",
    amount: -49.99,
    category: "Health",
    date: "Apr 5, 2026",
    time: "12:30 PM",
    account: "Visa Credit",
    status: "completed",
  },
  {
    id: 10,
    description: "Movie Tickets",
    amount: -32.0,
    category: "Entertainment",
    date: "Apr 4, 2026",
    time: "6:00 PM",
    account: "Visa Credit",
    status: "completed",
  },
];

export function TransactionsScreen() {
  return (
    <div className="min-h-full pb-6">
      {/* Header */}
      <div className="bg-gradient-to-br from-blue-600 via-blue-500 to-cyan-600 px-5 pt-12 pb-6">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6"
        >
          <h1 className="text-3xl mb-1 text-white">Transactions</h1>
          <p className="text-blue-100">All financial activity</p>
        </motion.div>

        {/* Search */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="relative"
        >
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-neutral-400" />
          <Input
            placeholder="Search transactions..."
            className="pl-12 h-12 bg-white/95 backdrop-blur-sm border-0 shadow-xl"
          />
        </motion.div>
      </div>

      {/* Transactions List */}
      <div className="px-5 space-y-3 -mt-4">
        {transactions.map((transaction, index) => (
          <motion.div
            key={transaction.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + index * 0.05 }}
            whileTap={{ scale: 0.98 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-4 shadow-lg shadow-black/5"
          >
            <div className="flex items-center gap-3">
              <div
                className={`size-11 rounded-xl flex items-center justify-center ${
                  transaction.amount > 0
                    ? "bg-gradient-to-br from-emerald-100 to-emerald-200"
                    : "bg-gradient-to-br from-neutral-100 to-neutral-200"
                }`}
              >
                {transaction.amount > 0 ? (
                  <ArrowDownRight className="size-5 text-emerald-700" strokeWidth={2.5} />
                ) : (
                  <ArrowUpRight className="size-5 text-neutral-600" strokeWidth={2.5} />
                )}
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-sm font-medium text-slate-900 truncate">{transaction.description}</span>
                  {transaction.status === "pending" && (
                    <span className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full shrink-0">
                      Pending
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-2 text-xs text-neutral-500">
                  <span>{transaction.category}</span>
                  <span>•</span>
                  <span>{transaction.date}</span>
                </div>
              </div>

              <div className="text-right shrink-0">
                <div
                  className={`text-lg font-medium ${
                    transaction.amount > 0 ? "text-emerald-600" : "text-slate-900"
                  }`}
                >
                  {transaction.amount > 0 ? "+" : ""}$
                  {Math.abs(transaction.amount).toFixed(2)}
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
