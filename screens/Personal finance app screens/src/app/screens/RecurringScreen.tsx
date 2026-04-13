import { Plus, Calendar, Pause, Play } from "lucide-react";
import { Button } from "../components/ui/button";
import { Badge } from "../components/ui/badge";
import { motion } from "motion/react";

const recurring = [
  {
    id: 1,
    name: "Netflix Subscription",
    amount: 15.99,
    frequency: "Monthly",
    nextDate: "Apr 15, 2026",
    category: "Entertainment",
    status: "active",
    icon: "📺",
  },
  {
    id: 2,
    name: "Spotify Premium",
    amount: 10.99,
    frequency: "Monthly",
    nextDate: "Apr 18, 2026",
    category: "Entertainment",
    status: "active",
    icon: "🎵",
  },
  {
    id: 3,
    name: "Gym Membership",
    amount: 49.99,
    frequency: "Monthly",
    nextDate: "Apr 20, 2026",
    category: "Health",
    status: "active",
    icon: "💪",
  },
  {
    id: 4,
    name: "Cloud Storage",
    amount: 9.99,
    frequency: "Monthly",
    nextDate: "Apr 22, 2026",
    category: "Technology",
    status: "active",
    icon: "☁️",
  },
  {
    id: 5,
    name: "Internet Bill",
    amount: 79.99,
    frequency: "Monthly",
    nextDate: "Apr 25, 2026",
    category: "Utilities",
    status: "active",
    icon: "📡",
  },
  {
    id: 6,
    name: "Insurance Premium",
    amount: 185.0,
    frequency: "Monthly",
    nextDate: "Apr 28, 2026",
    category: "Insurance",
    status: "active",
    icon: "🛡️",
  },
  {
    id: 7,
    name: "Phone Bill",
    amount: 65.0,
    frequency: "Monthly",
    nextDate: "May 1, 2026",
    category: "Utilities",
    status: "active",
    icon: "📱",
  },
  {
    id: 8,
    name: "Adobe Creative Cloud",
    amount: 54.99,
    frequency: "Monthly",
    nextDate: "May 5, 2026",
    category: "Software",
    status: "paused",
    icon: "🎨",
  },
];

export function RecurringScreen() {
  const activeRecurring = recurring.filter((r) => r.status === "active");
  const totalMonthly = activeRecurring.reduce((sum, r) => sum + r.amount, 0);

  return (
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-blue-800 bg-clip-text text-transparent">Recurring</h1>
          <p className="text-neutral-500">Manage subscriptions and recurring payments</p>
        </div>
        <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
          <Button className="bg-gradient-to-r from-blue-600 to-violet-600 hover:from-blue-700 hover:to-violet-700 shadow-lg shadow-blue-500/30">
            <Plus className="size-4 mr-2" />
            Add Recurring
          </Button>
        </motion.div>
      </motion.div>

      {/* Monthly Total */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="relative overflow-hidden bg-gradient-to-br from-white via-white to-blue-50/50 rounded-3xl border border-neutral-200/50 p-8 shadow-xl shadow-black/5"
      >
        <div className="absolute top-0 right-0 w-96 h-96 bg-blue-500/5 rounded-full blur-3xl" />
        <div className="relative flex items-center justify-between">
          <div>
            <div className="text-sm text-neutral-500 mb-3">Total Monthly Recurring</div>
            <div className="text-6xl mb-4 bg-gradient-to-br from-slate-900 to-blue-800 bg-clip-text text-transparent font-light">
              ${totalMonthly.toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </div>
            <div className="flex items-center gap-3">
              <div className="text-sm text-neutral-600 bg-blue-50 px-4 py-2 rounded-full border border-blue-200">
                {activeRecurring.length} active subscriptions
              </div>
              <div className="text-sm text-neutral-600 bg-neutral-50 px-4 py-2 rounded-full border border-neutral-200">
                {recurring.length - activeRecurring.length} paused
              </div>
            </div>
          </div>
          <motion.div
            whileHover={{ scale: 1.1, rotate: 5 }}
            className="size-24 bg-gradient-to-br from-blue-500 to-violet-600 rounded-3xl flex items-center justify-center text-white shadow-2xl shadow-blue-500/30"
          >
            <Calendar className="size-12" strokeWidth={1.5} />
          </motion.div>
        </div>
      </motion.div>

      {/* Recurring List */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3 }}
        className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 shadow-xl shadow-black/5 overflow-hidden"
      >
        <div className="divide-y divide-neutral-100">
          {recurring.map((item, index) => (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.4 + index * 0.05 }}
              whileHover={{ x: 4, backgroundColor: "rgba(59, 130, 246, 0.02)" }}
              className="p-6 flex items-center justify-between transition-all cursor-pointer"
            >
              <div className="flex items-center gap-5 flex-1">
                <motion.div
                  whileHover={{ scale: 1.2, rotate: 10 }}
                  className="text-5xl"
                >
                  {item.icon}
                </motion.div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <span className="text-lg text-slate-900 font-medium">{item.name}</span>
                    <Badge
                      variant={item.status === "active" ? "default" : "secondary"}
                      className={
                        item.status === "active"
                          ? "bg-emerald-100 text-emerald-700 hover:bg-emerald-100 px-3 py-1"
                          : "px-3 py-1"
                      }
                    >
                      {item.status}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-3 text-sm text-neutral-500">
                    <span className="font-medium">{item.category}</span>
                    <span>•</span>
                    <span>{item.frequency}</span>
                    <span>•</span>
                    <span>Next: {item.nextDate}</span>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-8">
                <div className="text-right">
                  <div className="text-3xl text-slate-900 font-light">${item.amount.toFixed(2)}</div>
                  <div className="text-xs text-neutral-400">per month</div>
                </div>
                <div className="flex gap-2">
                  <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
                    <Button variant="outline" size="sm" className="hover:bg-blue-50 hover:text-blue-700 hover:border-blue-300 transition-colors">
                      Edit
                    </Button>
                  </motion.div>
                  <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
                    <Button
                      variant="outline"
                      size="sm"
                      className={
                        item.status === "paused"
                          ? "border-emerald-300 text-emerald-700 hover:bg-emerald-100 bg-emerald-50 transition-colors"
                          : "hover:bg-amber-50 hover:text-amber-700 hover:border-amber-300 transition-colors"
                      }
                    >
                      {item.status === "active" ? (
                        <>
                          <Pause className="size-3.5 mr-1.5" />
                          Pause
                        </>
                      ) : (
                        <>
                          <Play className="size-3.5 mr-1.5" />
                          Resume
                        </>
                      )}
                    </Button>
                  </motion.div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}
