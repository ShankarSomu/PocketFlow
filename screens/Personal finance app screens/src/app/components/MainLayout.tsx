import { Outlet, Link, useLocation } from "react-router";
import { Home, Wallet, PieChart, Target, Repeat, Receipt, User, Bell, Settings } from "lucide-react";
import { motion } from "motion/react";

const navItems = [
  { path: "/app", label: "Home", icon: Home },
  { path: "/app/accounts", label: "Accounts", icon: Wallet },
  { path: "/app/budget", label: "Budget", icon: PieChart },
  { path: "/app/goals", label: "Goals", icon: Target },
  { path: "/app/recurring", label: "Recurring", icon: Repeat },
  { path: "/app/transactions", label: "Transactions", icon: Receipt },
  { path: "/app/profile", label: "Profile", icon: User },
];

export function MainLayout() {
  const location = useLocation();

  return (
    <div className="flex h-screen bg-gradient-to-br from-slate-50 via-white to-emerald-50/30">
      {/* Sidebar */}
      <aside className="w-72 bg-white/80 backdrop-blur-xl border-r border-neutral-200/50 flex flex-col shadow-2xl shadow-black/5">
        <div className="p-6 pb-8">
          <motion.div
            whileHover={{ scale: 1.02 }}
            className="flex items-center gap-3 cursor-pointer"
          >
            <div className="relative">
              <div className="absolute inset-0 bg-gradient-to-br from-emerald-500 to-blue-600 rounded-xl blur-md opacity-60" />
              <div className="relative size-11 bg-gradient-to-br from-emerald-500 to-blue-600 rounded-xl flex items-center justify-center shadow-lg">
                <Wallet className="size-6 text-white" strokeWidth={2} />
              </div>
            </div>
            <div>
              <span className="text-xl tracking-tight">Pocket Flow</span>
              <div className="text-xs text-emerald-600">Premium</div>
            </div>
          </motion.div>
        </div>

        <nav className="flex-1 px-4 space-y-2">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path}>
                <motion.div
                  whileHover={{ x: 4 }}
                  whileTap={{ scale: 0.98 }}
                  className={`relative flex items-center gap-4 px-4 py-3.5 rounded-xl transition-all ${
                    isActive
                      ? "text-white"
                      : "text-neutral-600 hover:bg-neutral-50"
                  }`}
                >
                  {isActive && (
                    <motion.div
                      layoutId="activeNav"
                      className="absolute inset-0 bg-gradient-to-r from-emerald-500 to-blue-600 rounded-xl shadow-lg shadow-emerald-500/30"
                      transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                    />
                  )}
                  <Icon className={`size-5 relative z-10 ${isActive ? "" : "stroke-[1.5]"}`} strokeWidth={isActive ? 2 : 1.5} />
                  <span className={`relative z-10 ${isActive ? "font-medium" : ""}`}>{item.label}</span>
                </motion.div>
              </Link>
            );
          })}
        </nav>

        <div className="p-4 space-y-3 border-t border-neutral-200/50">
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-neutral-600 hover:bg-neutral-50 transition-colors"
          >
            <Bell className="size-5" strokeWidth={1.5} />
            <span>Notifications</span>
            <span className="ml-auto size-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">3</span>
          </motion.button>
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-neutral-600 hover:bg-neutral-50 transition-colors"
          >
            <Settings className="size-5" strokeWidth={1.5} />
            <span>Settings</span>
          </motion.button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
