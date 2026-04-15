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
    <div className="min-h-full">
      {/* Header */}
      <div className="bg-gradient-to-br from-blue-600 via-blue-500 to-violet-600 px-5 pt-12 pb-8">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between mb-6"
        >
          <div>
            <h1 className="text-3xl mb-1 text-white">Recurring</h1>
            <p className="text-blue-100">Manage subscriptions</p>
          </div>
          <motion.button
            whileTap={{ scale: 0.9 }}
            className="p-3 bg-white/20 backdrop-blur-sm rounded-full border border-white/30"
          >
            <Plus className="size-5 text-white" />
          </motion.button>
        </motion.div>

        {/* Monthly Total */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20"
        >
          <div className="text-blue-100 text-sm mb-2">Monthly Total</div>
          <div className="text-5xl mb-3 text-white font-light">
            ${totalMonthly.toLocaleString("en-US", { minimumFractionDigits: 2 })}
          </div>
          <div className="flex items-center gap-2 text-sm">
            <div className="bg-white/20 px-3 py-1.5 rounded-full">
              <span className="text-white">{activeRecurring.length} active</span>
            </div>
            <div className="bg-white/10 px-3 py-1.5 rounded-full">
              <span className="text-blue-100">{recurring.length - activeRecurring.length} paused</span>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Recurring List */}
      <div className="px-5 py-6 space-y-3">
        {recurring.map((item, index) => (
          <motion.div
            key={item.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + index * 0.05 }}
            whileTap={{ scale: 0.98 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-4 shadow-lg shadow-black/5"
          >
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <div className="text-3xl shrink-0">{item.icon}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-medium text-slate-900 truncate">{item.name}</span>
                    <Badge
                      variant={item.status === "active" ? "default" : "secondary"}
                      className={`shrink-0 text-xs ${
                        item.status === "active"
                          ? "bg-emerald-100 text-emerald-700"
                          : ""
                      }`}
                    >
                      {item.status}
                    </Badge>
                  </div>
                  <div className="text-xs text-neutral-400">
                    {item.category} · Next: {item.nextDate}
                  </div>
                </div>
              </div>
              <div className="text-right shrink-0">
                <div className="text-2xl text-slate-900 font-light">${item.amount.toFixed(2)}</div>
                <div className="text-xs text-neutral-400">/month</div>
              </div>
            </div>
            <div className="flex gap-2 pt-3 border-t border-neutral-100">
              <Button variant="outline" size="sm" className="flex-1 hover:bg-blue-50">
                Edit
              </Button>
              <Button
                variant="outline"
                size="sm"
                className={`flex-1 ${
                  item.status === "paused"
                    ? "bg-emerald-50 text-emerald-700 hover:bg-emerald-100"
                    : "hover:bg-amber-50"
                }`}
              >
                {item.status === "active" ? (
                  <>
                    <Pause className="size-3 mr-1" />
                    Pause
                  </>
                ) : (
                  <>
                    <Play className="size-3 mr-1" />
                    Resume
                  </>
                )}
              </Button>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
