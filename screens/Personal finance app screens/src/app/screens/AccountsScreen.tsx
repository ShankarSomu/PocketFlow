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
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-emerald-800 bg-clip-text text-transparent">Accounts</h1>
          <p className="text-neutral-500">Manage your financial accounts</p>
        </div>
        <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
          <Button className="bg-gradient-to-r from-emerald-600 to-blue-600 hover:from-emerald-700 hover:to-blue-700 shadow-lg shadow-emerald-500/30">
            <Plus className="size-4 mr-2" />
            Add Account
          </Button>
        </motion.div>
      </motion.div>

      {/* Total Balance */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="relative overflow-hidden bg-gradient-to-br from-emerald-600 via-emerald-500 to-blue-600 rounded-3xl p-8 text-white shadow-2xl shadow-emerald-500/30"
      >
        <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        <div className="relative flex items-center justify-between">
          <div>
            <div className="text-sm opacity-90 mb-3 flex items-center gap-2">
              Total Net Worth
              <Eye className="size-4" />
            </div>
            <div className="text-6xl mb-4 font-light">
              ${totalBalance.toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2 bg-white/20 backdrop-blur-sm px-4 py-2 rounded-full">
                <TrendingUp className="size-4" />
                <span className="text-sm font-medium">+8.3% this month</span>
              </div>
              <div className="flex items-center gap-2 bg-white/20 backdrop-blur-sm px-4 py-2 rounded-full">
                <ArrowUpRight className="size-4" />
                <span className="text-sm font-medium">$1,892 growth</span>
              </div>
            </div>
          </div>
          <motion.div
            whileHover={{ scale: 1.1, rotate: 5 }}
            className="size-24 bg-white/10 rounded-3xl backdrop-blur-md flex items-center justify-center border border-white/20"
          >
            <Building2 className="size-12" strokeWidth={1.5} />
          </motion.div>
        </div>
      </motion.div>

      {/* Accounts Grid */}
      <div className="grid grid-cols-2 gap-6">
        {accounts.map((account, index) => (
          <motion.div
            key={account.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + index * 0.1 }}
            whileHover={{ y: -8, scale: 1.02 }}
            className="group relative"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/0 to-blue-500/0 group-hover:from-emerald-500/5 group-hover:to-blue-500/10 rounded-2xl transition-all" />
            <div className="relative bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-lg shadow-black/5 group-hover:shadow-2xl group-hover:shadow-emerald-500/20 transition-all">
              <div className="flex items-start justify-between mb-6">
                <motion.div
                  whileHover={{ scale: 1.1, rotate: 5 }}
                  className={`size-14 ${account.color} rounded-xl shadow-lg`}
                />
                <span className="text-xs text-neutral-400 bg-neutral-100 px-3 py-1 rounded-full">{account.accountNumber}</span>
              </div>

              <div className="space-y-4">
                <div>
                  <div className="text-xl mb-1 text-slate-900">{account.name}</div>
                  <div className="text-sm text-neutral-500">{account.institution}</div>
                </div>

                <div className="pt-4 border-t border-neutral-100">
                  <div className="text-xs text-neutral-400 mb-2">Current Balance</div>
                  <div
                    className={`text-4xl font-light ${account.balance < 0 ? "text-red-600" : "bg-gradient-to-br from-slate-900 to-emerald-800 bg-clip-text text-transparent"}`}
                  >
                    {account.balance < 0 ? "-" : ""}$
                    {Math.abs(account.balance).toLocaleString("en-US", {
                      minimumFractionDigits: 2,
                    })}
                  </div>
                </div>

                <div className="flex gap-2 pt-2">
                  <Button variant="outline" size="sm" className="flex-1 hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-300 transition-colors">
                    View Details
                  </Button>
                  <Button variant="outline" size="sm" className="flex-1 hover:bg-blue-50 hover:text-blue-700 hover:border-blue-300 transition-colors">
                    Transactions
                  </Button>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
