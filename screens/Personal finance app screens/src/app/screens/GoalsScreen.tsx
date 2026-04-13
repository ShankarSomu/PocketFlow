import { Plus, Target, TrendingUp, Trophy } from "lucide-react";
import { Button } from "../components/ui/button";
import { Progress } from "../components/ui/progress";
import { motion } from "motion/react";

const goals = [
  {
    id: 1,
    name: "Emergency Fund",
    target: 15000,
    current: 12500,
    deadline: "Dec 2026",
    color: "bg-emerald-500",
    icon: "🛡️",
  },
  {
    id: 2,
    name: "New Car",
    target: 35000,
    current: 18200,
    deadline: "Jun 2027",
    color: "bg-blue-500",
    icon: "🚗",
  },
  {
    id: 3,
    name: "Vacation Fund",
    target: 8000,
    current: 4350,
    deadline: "Aug 2026",
    color: "bg-violet-500",
    icon: "✈️",
  },
  {
    id: 4,
    name: "Home Down Payment",
    target: 60000,
    current: 23400,
    deadline: "Jan 2028",
    color: "bg-amber-500",
    icon: "🏡",
  },
];

export function GoalsScreen() {
  const totalTarget = goals.reduce((sum, g) => sum + g.target, 0);
  const totalCurrent = goals.reduce((sum, g) => sum + g.current, 0);

  return (
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div>
          <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-violet-800 bg-clip-text text-transparent">Goals</h1>
          <p className="text-neutral-500">Track your financial goals</p>
        </div>
        <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>
          <Button className="bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700 shadow-lg shadow-violet-500/30">
            <Plus className="size-4 mr-2" />
            Add Goal
          </Button>
        </motion.div>
      </motion.div>

      {/* Overall Progress */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="relative overflow-hidden bg-gradient-to-br from-violet-600 via-purple-600 to-fuchsia-600 rounded-3xl p-8 text-white shadow-2xl shadow-violet-500/40"
      >
        <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        <div className="relative flex items-center justify-between">
          <div>
            <div className="text-sm opacity-90 mb-3 flex items-center gap-2">
              Total Goal Progress
              <Trophy className="size-4" />
            </div>
            <div className="text-6xl mb-4 font-light">
              ${totalCurrent.toLocaleString("en-US")}
            </div>
            <div className="text-xl opacity-90 font-light">
              of ${totalTarget.toLocaleString("en-US")} target
            </div>
          </div>
          <motion.div
            whileHover={{ scale: 1.1, rotate: 5 }}
            className="size-24 bg-white/10 rounded-3xl backdrop-blur-md flex items-center justify-center border border-white/20"
          >
            <Target className="size-12" strokeWidth={1.5} />
          </motion.div>
        </div>
        <div className="mt-8">
          <Progress
            value={(totalCurrent / totalTarget) * 100}
            className="h-4 bg-white/20 [&>div]:bg-white"
          />
          <div className="mt-3 text-sm flex items-center justify-between">
            <span>{((totalCurrent / totalTarget) * 100).toFixed(1)}% complete</span>
            <span>${(totalTarget - totalCurrent).toLocaleString("en-US")} remaining</span>
          </div>
        </div>
      </motion.div>

      {/* Goals Grid */}
      <div className="grid grid-cols-2 gap-6">
        {goals.map((goal, index) => {
          const percentage = (goal.current / goal.target) * 100;
          const remaining = goal.target - goal.current;

          return (
            <motion.div
              key={goal.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileHover={{ y: -6, scale: 1.02 }}
              className="group relative"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-violet-500/0 to-purple-500/0 group-hover:from-violet-500/5 group-hover:to-purple-500/10 rounded-2xl transition-all" />
              <div className="relative bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-lg shadow-black/5 group-hover:shadow-2xl group-hover:shadow-violet-500/20 transition-all">
                <div className="flex items-start justify-between mb-6">
                  <div className="flex items-center gap-4">
                    <motion.div
                      whileHover={{ scale: 1.2, rotate: 10 }}
                      className="text-5xl"
                    >
                      {goal.icon}
                    </motion.div>
                    <div>
                      <div className="text-xl text-slate-900 mb-1">{goal.name}</div>
                      <div className="text-sm text-neutral-400">Due {goal.deadline}</div>
                    </div>
                  </div>
                </div>

                <div className="space-y-5">
                  <div>
                    <div className="flex items-end justify-between mb-3">
                      <div>
                        <div className="text-xs text-neutral-500 mb-1">Current</div>
                        <div className="text-4xl font-light bg-gradient-to-br from-emerald-600 to-emerald-700 bg-clip-text text-transparent">
                          ${goal.current.toLocaleString("en-US")}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-xs text-neutral-500 mb-1">Target</div>
                        <div className="text-3xl text-neutral-400 font-light">
                          ${goal.target.toLocaleString("en-US")}
                        </div>
                      </div>
                    </div>

                    <Progress
                      value={percentage}
                      className="h-3 [&>div]:bg-gradient-to-r [&>div]:from-violet-500 [&>div]:to-purple-600"
                    />

                    <div className="flex items-center justify-between mt-3">
                      <span className="text-sm text-neutral-600 font-medium">
                        {percentage.toFixed(1)}% complete
                      </span>
                      <span className="text-sm text-emerald-600 font-medium">
                        ${remaining.toLocaleString("en-US")} to go
                      </span>
                    </div>
                  </div>

                  <div className="pt-4 border-t border-neutral-100 flex items-center gap-2 text-sm">
                    <div className="p-1.5 bg-emerald-100 rounded-lg">
                      <TrendingUp className="size-3.5 text-emerald-600" />
                    </div>
                    <span className="text-neutral-600">On track to reach goal</span>
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
