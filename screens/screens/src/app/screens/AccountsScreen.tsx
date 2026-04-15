import { Plus, TrendingUp, Building2, ArrowUpRight, Eye } from "lucide-react";
import { Button } from "../components/ui/button";
import { motion } from "motion/react";

const accounts = [
  {
    id: 1,
    name: "Checking Account",
    institution: "Chase Bank",
    type: "Checking",
    balance: 8420.42,
    accountNumber: "****4521",
    color: "bg-blue-500",
  },
  {
    id: 2,
    name: "Savings Account",
    institution: "Ally Bank",
    type: "Savings",
    balance: 12500.0,
    accountNumber: "****7832",
    color: "bg-emerald-500",
  },
  {
    id: 3,
    name: "Investment Account",
    institution: "Vanguard",
    type: "Investment",
    balance: 3660.0,
    accountNumber: "****2109",
    color: "bg-violet-500",
  },
  {
    id: 4,
    name: "Credit Card",
    institution: "Visa",
    type: "Credit",
    balance: -1340.0,
    accountNumber: "****8765",
    color: "bg-red-500",
  },
];

export function AccountsScreen() {
  const totalBalance = accounts.reduce((sum, acc) => sum + acc.balance, 0);

  return (
    <div className="min-h-full">
      {/* Header */}
      <div className="bg-gradient-to-br from-blue-600 via-blue-500 to-violet-600 px-5 pt-12 pb-8">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between mb-6"
        >
          <div>
            <h1 className="text-3xl mb-1 text-white">Accounts</h1>
            <p className="text-blue-100">Manage your finances</p>
          </div>
          <motion.button
            whileTap={{ scale: 0.9 }}
            className="p-3 bg-white/20 backdrop-blur-sm rounded-full border border-white/30"
          >
            <Plus className="size-5 text-white" />
          </motion.button>
        </motion.div>

        {/* Total Net Worth Card */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20"
        >
          <div className="flex items-center gap-2 text-blue-100 text-sm mb-3">
            <Eye className="size-4" />
            <span>Total Net Worth</span>
          </div>
          <div className="text-5xl mb-4 text-white font-light">
            ${totalBalance.toLocaleString("en-US", { minimumFractionDigits: 2 })}
          </div>
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1.5 bg-white/20 backdrop-blur-sm px-3 py-1.5 rounded-full">
              <TrendingUp className="size-3.5 text-white" />
              <span className="text-sm text-white">+8.3%</span>
            </div>
            <span className="text-sm text-blue-100">this month</span>
          </div>
        </motion.div>
      </div>

      {/* Accounts List */}
      <div className="px-5 py-6 space-y-4">
        {accounts.map((account, index) => (
          <motion.div
            key={account.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + index * 0.1 }}
            whileTap={{ scale: 0.98 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-4">
                <div className={`size-12 ${account.color} rounded-xl shadow-lg`} />
                <div>
                  <div className="text-base font-medium text-slate-900">{account.name}</div>
                  <div className="text-sm text-neutral-500">{account.institution}</div>
                </div>
              </div>
              <span className="text-xs text-neutral-400 bg-neutral-100 px-2 py-1 rounded-full">{account.accountNumber}</span>
            </div>

            <div className="pt-4 border-t border-neutral-100 flex items-end justify-between">
              <div>
                <div className="text-xs text-neutral-400 mb-1">Current Balance</div>
                <div
                  className={`text-3xl font-light ${account.balance < 0 ? "text-red-600" : "text-slate-900"}`}
                >
                  {account.balance < 0 ? "-" : ""}$
                  {Math.abs(account.balance).toLocaleString("en-US", {
                    minimumFractionDigits: 2,
                  })}
                </div>
              </div>
              <Button variant="outline" size="sm" className="hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-300">
                View
              </Button>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
