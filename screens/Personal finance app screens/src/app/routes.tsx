import { createBrowserRouter } from "react-router";
import { WelcomeScreen } from "./screens/WelcomeScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { AccountsScreen } from "./screens/AccountsScreen";
import { BudgetScreen } from "./screens/BudgetScreen";
import { GoalsScreen } from "./screens/GoalsScreen";
import { RecurringScreen } from "./screens/RecurringScreen";
import { TransactionsScreen } from "./screens/TransactionsScreen";
import { ProfileScreen } from "./screens/ProfileScreen";
import { MainLayout } from "./components/MainLayout";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: WelcomeScreen,
  },
  {
    path: "/app",
    Component: MainLayout,
    children: [
      { index: true, Component: HomeScreen },
      { path: "accounts", Component: AccountsScreen },
      { path: "budget", Component: BudgetScreen },
      { path: "goals", Component: GoalsScreen },
      { path: "recurring", Component: RecurringScreen },
      { path: "transactions", Component: TransactionsScreen },
      { path: "profile", Component: ProfileScreen },
    ],
  },
]);
