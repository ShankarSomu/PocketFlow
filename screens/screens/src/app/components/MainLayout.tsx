import { Outlet, Link, useLocation } from "react-router";
import { Home, Wallet, PieChart, Target, Receipt, User } from "lucide-react";
import { motion } from "motion/react";

const navItems = [
  { path: "/app", label: "Home", icon: Home },
  { path: "/app/accounts", label: "Accounts", icon: Wallet },
  { path: "/app/budget", label: "Budget", icon: PieChart },
  { path: "/app/goals", label: "Goals", icon: Target },
  { path: "/app/transactions", label: "Transactions", icon: Receipt },
  { path: "/app/profile", label: "Profile", icon: User },
];

export function MainLayout() {
  const location = useLocation();

  return (
    <div className="flex flex-col h-screen bg-gradient-to-br from-slate-50 via-white to-emerald-50/30">
      {/* Main content */}
      <main className="flex-1 overflow-auto pb-20">
        <Outlet />
      </main>

      {/* Bottom Navigation - Mobile */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white/95 backdrop-blur-xl border-t border-neutral-200/50 shadow-2xl shadow-black/10 safe-area-bottom">
        <div className="flex items-center justify-around px-2 py-3 max-w-screen-xl mx-auto">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path} className="flex-1 max-w-[100px]">
                <motion.div
                  whileTap={{ scale: 0.9 }}
                  className="flex flex-col items-center gap-1 py-2"
                >
                  <div className={`relative p-2 rounded-xl transition-all ${
                    isActive ? "bg-gradient-to-r from-emerald-500 to-blue-600" : ""
                  }`}>
                    {isActive && (
                      <motion.div
                        layoutId="activeNavMobile"
                        className="absolute inset-0 bg-gradient-to-r from-emerald-500 to-blue-600 rounded-xl"
                        transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                      />
                    )}
                    <Icon
                      className={`size-5 relative z-10 ${isActive ? "text-white" : "text-neutral-600"}`}
                      strokeWidth={isActive ? 2.5 : 2}
                    />
                  </div>
                  <span className={`text-xs ${isActive ? "text-emerald-600 font-medium" : "text-neutral-500"}`}>
                    {item.label}
                  </span>
                </motion.div>
              </Link>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
