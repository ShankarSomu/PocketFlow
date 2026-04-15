import { Mail, Phone, MapPin, Calendar, Bell, Lock, CreditCard, Download, LogOut, Sparkles, TrendingUp } from "lucide-react";
import { Button } from "../components/ui/button";
import { Switch } from "../components/ui/switch";
import { Separator } from "../components/ui/separator";
import { motion } from "motion/react";

export function ProfileScreen() {
  return (
    <div className="min-h-full pb-6">
      {/* Header with Profile Card */}
      <div className="bg-gradient-to-br from-emerald-600 via-emerald-500 to-blue-600 px-5 pt-12 pb-32 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative text-center"
        >
          <div className="inline-block relative mb-4">
            <div className="absolute inset-0 bg-white/30 rounded-full blur-xl" />
            <div className="relative size-24 bg-gradient-to-br from-white to-emerald-100 rounded-full flex items-center justify-center text-emerald-700 text-3xl shadow-2xl">
              JD
            </div>
          </div>
          <h1 className="text-3xl text-white mb-1">John Doe</h1>
          <div className="inline-flex items-center gap-2 bg-white/20 backdrop-blur-sm px-4 py-2 rounded-full border border-white/30">
            <Sparkles className="size-4 text-white" />
            <span className="text-sm text-white">Premium Member</span>
          </div>
        </motion.div>
      </div>

      <div className="px-5 -mt-24 space-y-5">
        {/* Personal Info Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5"
        >
          <h3 className="text-lg mb-4 text-slate-900">Personal Information</h3>

          <div className="space-y-3">
            {[
              { icon: Mail, label: "Email", value: "john.doe@email.com" },
              { icon: Phone, label: "Phone", value: "+1 (555) 123-4567" },
              { icon: MapPin, label: "Location", value: "San Francisco, CA" },
              { icon: Calendar, label: "Member Since", value: "January 2024" },
            ].map((item) => (
              <div key={item.label} className="flex items-center gap-3 p-3 bg-neutral-50 rounded-xl">
                <div className="p-2 bg-white rounded-lg">
                  <item.icon className="size-4 text-neutral-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-xs text-neutral-400">{item.label}</div>
                  <div className="text-sm text-slate-900 font-medium truncate">{item.value}</div>
                </div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Account Health */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="relative overflow-hidden bg-gradient-to-br from-emerald-600 via-emerald-500 to-blue-600 rounded-2xl p-5 text-white shadow-xl"
        >
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl" />
          <div className="relative">
            <div className="flex items-center gap-2 text-sm mb-3">
              <TrendingUp className="size-4" />
              <span>Account Health</span>
            </div>
            <div className="text-4xl mb-4 font-light">Excellent</div>
            <div className="space-y-2 text-sm">
              {[
                { label: "Savings Rate", value: "49.9%" },
                { label: "Budget Compliance", value: "92%" },
                { label: "Goals on Track", value: "4/4" },
              ].map((stat) => (
                <div key={stat.label} className="flex justify-between items-center p-2.5 bg-white/10 backdrop-blur-sm rounded-lg">
                  <span>{stat.label}</span>
                  <span className="font-medium text-base">{stat.value}</span>
                </div>
              ))}
            </div>
          </div>
        </motion.div>

        {/* Preferences */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5"
        >
          <h3 className="text-lg mb-4 text-slate-900">Notifications</h3>
          <div className="space-y-4">
            {[
              { label: "Email Notifications", checked: true },
              { label: "Budget Alerts", checked: true },
              { label: "Transaction Alerts", checked: false },
              { label: "Weekly Reports", checked: true },
            ].map((pref, index) => (
              <div key={pref.label}>
                <div className="flex items-center justify-between py-2">
                  <div className="flex items-center gap-3">
                    <div className="p-1.5 bg-emerald-100 rounded-lg">
                      <Bell className="size-4 text-emerald-700" />
                    </div>
                    <span className="text-sm text-slate-900">{pref.label}</span>
                  </div>
                  <Switch defaultChecked={pref.checked} />
                </div>
                {index < 3 && <Separator />}
              </div>
            ))}
          </div>
        </motion.div>

        {/* Quick Actions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="bg-white/80 backdrop-blur-sm rounded-2xl border border-neutral-200/50 p-5 shadow-xl shadow-black/5"
        >
          <h3 className="text-lg mb-4 text-slate-900">Quick Actions</h3>
          <div className="space-y-2">
            {[
              { icon: Lock, label: "Security", color: "hover:bg-blue-50" },
              { icon: CreditCard, label: "Payment Methods", color: "hover:bg-violet-50" },
              { icon: Download, label: "Export Data", color: "hover:bg-emerald-50" },
            ].map((action) => (
              <motion.div key={action.label} whileTap={{ scale: 0.98 }}>
                <Button variant="outline" className={`w-full justify-start h-11 border-neutral-300 transition-all ${action.color}`}>
                  <action.icon className="size-4 mr-3" />
                  {action.label}
                </Button>
              </motion.div>
            ))}
            <Separator className="my-2" />
            <motion.div whileTap={{ scale: 0.98 }}>
              <Button variant="outline" className="w-full justify-start h-11 text-red-600 hover:bg-red-50 border-neutral-300">
                <LogOut className="size-4 mr-3" />
                Sign Out
              </Button>
            </motion.div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
