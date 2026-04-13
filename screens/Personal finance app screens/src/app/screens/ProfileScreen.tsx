import { Mail, Phone, MapPin, Calendar, Bell, Lock, CreditCard, Download, LogOut, Sparkles, TrendingUp } from "lucide-react";
import { Button } from "../components/ui/button";
import { Switch } from "../components/ui/switch";
import { Separator } from "../components/ui/separator";
import { motion } from "motion/react";

export function ProfileScreen() {
  return (
    <div className="p-8 space-y-8">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <h1 className="text-4xl mb-2 bg-gradient-to-r from-slate-900 to-emerald-800 bg-clip-text text-transparent">Profile</h1>
        <p className="text-neutral-500">Manage your account settings</p>
      </motion.div>

      <div className="grid grid-cols-3 gap-6">
        {/* Profile Info */}
        <div className="col-span-2 space-y-6">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-8 shadow-xl shadow-black/5"
          >
            <h2 className="text-2xl mb-8 text-slate-900">Personal Information</h2>

            <div className="flex items-center gap-8 mb-10">
              <motion.div
                whileHover={{ scale: 1.05, rotate: 5 }}
                className="relative"
              >
                <div className="absolute inset-0 bg-gradient-to-br from-emerald-500 to-blue-600 rounded-full blur-lg opacity-50" />
                <div className="relative size-28 bg-gradient-to-br from-emerald-500 to-blue-600 rounded-full flex items-center justify-center text-white text-4xl shadow-2xl">
                  JD
                </div>
              </motion.div>
              <div>
                <div className="text-3xl mb-2 text-slate-900">John Doe</div>
                <div className="flex items-center gap-2 text-emerald-700 bg-emerald-50 px-4 py-2 rounded-full w-fit">
                  <Sparkles className="size-4" />
                  <span className="text-sm font-medium">Premium Member</span>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              {[
                { icon: Mail, label: "Email", value: "john.doe@email.com" },
                { icon: Phone, label: "Phone", value: "+1 (555) 123-4567" },
                { icon: MapPin, label: "Location", value: "San Francisco, CA" },
                { icon: Calendar, label: "Member Since", value: "January 2024" },
              ].map((item, index) => (
                <motion.div
                  key={item.label}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.3 + index * 0.05 }}
                  whileHover={{ x: 4, backgroundColor: "rgba(16, 185, 129, 0.03)" }}
                  className="flex items-center gap-5 p-5 bg-gradient-to-r from-neutral-50 to-neutral-50/50 rounded-xl transition-all cursor-pointer"
                >
                  <div className="p-3 bg-white rounded-lg shadow-sm">
                    <item.icon className="size-5 text-neutral-600" />
                  </div>
                  <div>
                    <div className="text-xs text-neutral-500 mb-1">{item.label}</div>
                    <div className="text-slate-900 font-medium">{item.value}</div>
                  </div>
                </motion.div>
              ))}
            </div>

            <div className="mt-8">
              <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                <Button variant="outline" className="w-full h-12 border-neutral-300 hover:bg-gradient-to-r hover:from-emerald-50 hover:to-blue-50 hover:border-emerald-300 transition-all">
                  Edit Profile
                </Button>
              </motion.div>
            </div>
          </motion.div>

          {/* Preferences */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.4 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-8 shadow-xl shadow-black/5"
          >
            <h2 className="text-2xl mb-8 text-slate-900">Preferences</h2>

            <div className="space-y-6">
              {[
                { label: "Email Notifications", description: "Receive updates via email", checked: true },
                { label: "Budget Alerts", description: "Alert when approaching budget limit", checked: true },
                { label: "Transaction Notifications", description: "Get notified of all transactions", checked: false },
                { label: "Weekly Reports", description: "Receive weekly financial summary", checked: true },
              ].map((pref, index) => (
                <motion.div
                  key={pref.label}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.5 + index * 0.05 }}
                >
                  <div className="flex items-center justify-between p-4 rounded-xl hover:bg-gradient-to-r hover:from-neutral-50 hover:to-transparent transition-all">
                    <div className="flex items-center gap-4">
                      <div className="p-2 bg-gradient-to-br from-emerald-100 to-blue-100 rounded-lg">
                        <Bell className="size-5 text-emerald-700" />
                      </div>
                      <div>
                        <div className="text-slate-900 font-medium">{pref.label}</div>
                        <div className="text-sm text-neutral-500">{pref.description}</div>
                      </div>
                    </div>
                    <Switch defaultChecked={pref.checked} />
                  </div>
                  {index < 3 && <Separator className="my-2" />}
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>

        {/* Quick Actions */}
        <div className="col-span-1 space-y-6">
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-6 shadow-xl shadow-black/5"
          >
            <h2 className="text-xl mb-6 text-slate-900">Quick Actions</h2>

            <div className="space-y-3">
              {[
                { icon: Lock, label: "Security Settings", color: "hover:bg-blue-50 hover:text-blue-700 hover:border-blue-300" },
                { icon: CreditCard, label: "Payment Methods", color: "hover:bg-violet-50 hover:text-violet-700 hover:border-violet-300" },
                { icon: Download, label: "Export Data", color: "hover:bg-emerald-50 hover:text-emerald-700 hover:border-emerald-300" },
              ].map((action, index) => (
                <motion.div
                  key={action.label}
                  initial={{ opacity: 0, x: 10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.3 + index * 0.05 }}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <Button variant="outline" className={`w-full justify-start h-12 border-neutral-300 transition-all ${action.color}`}>
                    <action.icon className="size-4 mr-3" />
                    {action.label}
                  </Button>
                </motion.div>
              ))}

              <Separator className="my-4" />

              <motion.div
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <Button variant="outline" className="w-full justify-start h-12 text-red-600 hover:text-red-700 hover:bg-red-50 hover:border-red-300 border-neutral-300 transition-all">
                  <LogOut className="size-4 mr-3" />
                  Sign Out
                </Button>
              </motion.div>
            </div>
          </motion.div>

          {/* Stats */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.4 }}
            className="relative overflow-hidden bg-gradient-to-br from-emerald-600 via-emerald-500 to-blue-600 rounded-2xl p-6 text-white shadow-2xl shadow-emerald-500/40"
          >
            <div className="absolute top-0 right-0 w-40 h-40 bg-white/10 rounded-full blur-2xl" />
            <div className="relative">
              <div className="flex items-center gap-2 text-sm opacity-90 mb-3">
                <TrendingUp className="size-4" />
                <span>Account Health</span>
              </div>
              <div className="text-5xl mb-6 font-light">Excellent</div>
              <div className="space-y-3 text-sm">
                {[
                  { label: "Savings Rate", value: "49.9%" },
                  { label: "Budget Compliance", value: "92%" },
                  { label: "Goals on Track", value: "4/4" },
                ].map((stat, index) => (
                  <motion.div
                    key={stat.label}
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.5 + index * 0.1 }}
                    className="flex justify-between items-center p-3 bg-white/10 backdrop-blur-sm rounded-lg"
                  >
                    <span>{stat.label}</span>
                    <span className="font-medium text-lg">{stat.value}</span>
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  );
}
