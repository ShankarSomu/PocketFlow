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
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-blue-800 bg-clip-text text-transparent">Transactions</h1>
          <p className="text-neutral-500">View all financial activity</p>
        </div>
        <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
          <Button variant="outline" className="shadow-lg border-neutral-300 hover:bg-neutral-50">
            <Download className="size-4 mr-2" />
            Export
          </Button>
        </motion.div>
      </motion.div>

      {/* Search and Filters */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2 }}
        className="flex gap-4"
      >
        <div className="relative flex-1">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-neutral-400" />
          <Input
            placeholder="Search transactions..."
            className="pl-12 h-12 bg-white/80 backdrop-blur-sm border-neutral-300 shadow-lg focus:ring-2 focus:ring-blue-500/20"
          />
        </div>
        <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
          <Button variant="outline" className="h-12 px-6 shadow-lg border-neutral-300 hover:bg-neutral-50">
            <SlidersHorizontal className="size-4 mr-2" />
            Filters
          </Button>
        </motion.div>
      </motion.div>

      {/* Transactions Table */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3 }}
        className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 shadow-xl shadow-black/5 overflow-hidden"
      >
        <div className="divide-y divide-neutral-100">
          {transactions.map((transaction, index) => (
            <motion.div
              key={transaction.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.4 + index * 0.03 }}
              whileHover={{ x: 4, backgroundColor: "rgba(16, 185, 129, 0.02)" }}
              className="p-6 flex items-center justify-between cursor-pointer transition-all"
            >
              <div className="flex items-center gap-5 flex-1">
                <motion.div
                  whileHover={{ scale: 1.1, rotate: 5 }}
                  className={`size-14 rounded-xl flex items-center justify-center shadow-md ${
                    transaction.amount > 0
                      ? "bg-gradient-to-br from-emerald-100 to-emerald-200"
                      : "bg-gradient-to-br from-neutral-100 to-neutral-200"
                  }`}
                >
                  {transaction.amount > 0 ? (
                    <ArrowDownRight className="size-6 text-emerald-700" strokeWidth={2.5} />
                  ) : (
                    <ArrowUpRight className="size-6 text-neutral-600" strokeWidth={2.5} />
                  )}
                </motion.div>

                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <span className="text-lg text-slate-900 font-medium">{transaction.description}</span>
                    {transaction.status === "pending" && (
                      <span className="text-xs bg-amber-100 text-amber-700 px-3 py-1 rounded-full font-medium">
                        Pending
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-3 text-sm text-neutral-500">
                    <span className="font-medium">{transaction.category}</span>
                    <span>•</span>
                    <span>{transaction.account}</span>
                    <span>•</span>
                    <span>
                      {transaction.date} at {transaction.time}
                    </span>
                  </div>
                </div>
              </div>

              <div className="text-right">
                <div
                  className={`text-2xl font-medium ${
                    transaction.amount > 0 ? "text-emerald-600" : "text-slate-900"
                  }`}
                >
                  {transaction.amount > 0 ? "+" : ""}$
                  {Math.abs(transaction.amount).toFixed(2)}
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}
