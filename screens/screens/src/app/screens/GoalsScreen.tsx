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
    <div className="min-h-full">
      {/* Header */}
      <div className="bg-gradient-to-br from-violet-600 via-purple-600 to-fuchsia-600 px-5 pt-12 pb-8">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between mb-6"
        >
          <div>
            <h1 className="text-3xl mb-1 text-white">Goals</h1>
            <p className="text-violet-100">Track your progress</p>
          </div>
          <motion.button
            whileTap={{ scale: 0.9 }}
            className="p-3 bg-white/20 backdrop-blur-sm rounded-full border border-white/30"
          >
            <Plus className="size-5 text-white" />
          </motion.button>
        </motion.div>

        {/* Overall Progress */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20"
        >
          <div className="flex items-center gap-2 text-violet-100 text-sm mb-3">
            <Trophy className="size-4" />
            <span>Total Progress</span>
          </div>
          <div className="text-5xl mb-2 text-white font-light">
            ${totalCurrent.toLocaleString("en-US")}
          </div>
          <div className="text-lg text-violet-100 mb-4">
            of ${totalTarget.toLocaleString("en-US")} target
          </div>
          <Progress
            value={(totalCurrent / totalTarget) * 100}
            className="h-3 bg-white/20 [&>div]:bg-white mb-3"
          />
          <div className="flex items-center justify-between text-sm">
            <span className="text-violet-100">{((totalCurrent / totalTarget) * 100).toFixed(1)}% complete</span>
            <span className="text-white font-medium">${(totalTarget - totalCurrent).toLocaleString("en-US")} left</span>
          </div>
        </motion.div>
      </div>

      {/* Goals List */}
      <div className="px-5 py-6 space-y-4">
        {goals.map((goal, index) => {
          const percentage = (goal.current / goal.target) * 100;
          const remaining = goal.target - goal.current;

          return (
            <motion.div
              key={goal.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileTap={{ scale: 0.98 }}
              className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5"
            >
              <div className="flex items-center gap-3 mb-4">
                <div className="text-4xl">{goal.icon}</div>
                <div className="flex-1">
                  <div className="text-base font-medium text-slate-900 mb-1">{goal.name}</div>
                  <div className="text-xs text-neutral-400">Due {goal.deadline}</div>
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-end justify-between">
                  <div>
                    <div className="text-xs text-neutral-400 mb-1">Current</div>
                    <div className="text-3xl font-light text-emerald-600">
                      ${goal.current.toLocaleString("en-US")}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-neutral-400 mb-1">Target</div>
                    <div className="text-2xl text-neutral-500 font-light">
                      ${goal.target.toLocaleString("en-US")}
                    </div>
                  </div>
                </div>

                <Progress
                  value={percentage}
                  className="h-2.5 [&>div]:bg-gradient-to-r [&>div]:from-violet-500 [&>div]:to-purple-600"
                />

                <div className="flex items-center justify-between text-xs">
                  <span className="text-neutral-600 font-medium">
                    {percentage.toFixed(1)}% complete
                  </span>
                  <span className="text-emerald-600 font-medium">
                    ${remaining.toLocaleString("en-US")} to go
                  </span>
                </div>

                <div className="pt-3 border-t border-neutral-100 flex items-center gap-2">
                  <div className="p-1 bg-emerald-100 rounded-lg">
                    <TrendingUp className="size-3 text-emerald-600" />
                  </div>
                  <span className="text-xs text-neutral-600">On track to reach goal</span>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
