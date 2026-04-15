import { Link } from "react-router";
import { motion } from "motion/react";
import { Wallet, TrendingUp, Target, Calendar, Sparkles, ArrowRight } from "lucide-react";
import { Button } from "../components/ui/button";

const features = [
  { icon: TrendingUp, label: "Smart Analytics", color: "from-emerald-400 to-emerald-600" },
  { icon: Target, label: "Goal Tracking", color: "from-blue-400 to-blue-600" },
  { icon: Calendar, label: "Budget Planning", color: "from-violet-400 to-violet-600" },
  { icon: Wallet, label: "Account Sync", color: "from-amber-400 to-amber-600" },
];

export function WelcomeScreen() {
  return (
    <div className="relative min-h-screen overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950 flex items-center justify-center">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden">
        <motion.div
          animate={{
            scale: [1, 1.2, 1],
            opacity: [0.3, 0.5, 0.3],
          }}
          transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -top-1/2 -left-1/4 w-[500px] h-[500px] bg-emerald-500/20 rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            scale: [1.2, 1, 1.2],
            opacity: [0.2, 0.4, 0.2],
          }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -bottom-1/2 -right-1/4 w-[600px] h-[600px] bg-blue-500/20 rounded-full blur-3xl"
        />
      </div>

      <div className="relative w-full px-6 py-12">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="max-w-lg mx-auto text-center space-y-12"
        >
          {/* Logo */}
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.2, duration: 0.6, type: "spring" }}
            className="flex justify-center"
          >
            <div className="relative">
              <div className="absolute inset-0 bg-gradient-to-br from-emerald-400 to-blue-600 rounded-3xl blur-xl opacity-75" />
              <div className="relative size-24 bg-gradient-to-br from-emerald-500 to-blue-600 rounded-3xl flex items-center justify-center shadow-2xl">
                <Wallet className="size-12 text-white" strokeWidth={1.5} />
              </div>
            </div>
          </motion.div>

          {/* Title */}
          <div className="space-y-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
            >
              <h1 className="text-5xl tracking-tight text-white mb-3 bg-clip-text text-transparent bg-gradient-to-r from-white via-emerald-100 to-blue-100">
                Pocket Flow
              </h1>
              <div className="flex items-center justify-center gap-2 text-emerald-400 mb-3">
                <Sparkles className="size-4" />
                <span className="text-xs uppercase tracking-wider">Premium Finance Manager</span>
              </div>
            </motion.div>
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
              className="text-lg text-slate-300 leading-relaxed px-4"
            >
              Experience financial clarity with intelligent tracking and beautiful insights
            </motion.p>
          </div>

          {/* Features */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.8 }}
            className="grid grid-cols-2 gap-4 max-w-sm mx-auto"
          >
            {features.map((feature, index) => (
              <motion.div
                key={feature.label}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.9 + index * 0.1 }}
                whileTap={{ scale: 0.95 }}
                className="backdrop-blur-xl bg-white/5 border border-white/10 rounded-2xl p-5 active:bg-white/10 transition-all"
              >
                <div className={`size-12 mx-auto bg-gradient-to-br ${feature.color} rounded-xl flex items-center justify-center mb-3 shadow-lg`}>
                  <feature.icon className="size-6 text-white" strokeWidth={2} />
                </div>
                <p className="text-sm text-slate-200">{feature.label}</p>
              </motion.div>
            ))}
          </motion.div>

          {/* CTA */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 1.2 }}
            className="flex flex-col items-center gap-3"
          >
            <Link to="/app" className="w-full max-w-xs">
              <motion.div whileTap={{ scale: 0.95 }}>
                <Button
                  size="lg"
                  className="relative w-full group bg-gradient-to-r from-emerald-500 via-emerald-600 to-blue-600 text-white h-14 text-base rounded-full shadow-2xl shadow-emerald-500/50 border-0 overflow-hidden"
                >
                  <span className="relative z-10 flex items-center justify-center gap-2">
                    Get Started
                    <ArrowRight className="size-5 group-active:translate-x-1 transition-transform" />
                  </span>
                  <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 translate-x-[-100%] group-active:translate-x-[100%] transition-transform duration-1000" />
                </Button>
              </motion.div>
            </Link>
            <p className="text-xs text-slate-400">No credit card required • Free forever</p>
          </motion.div>
        </motion.div>
      </div>
    </div>
  );
}
