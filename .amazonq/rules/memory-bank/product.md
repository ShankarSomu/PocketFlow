# PocketFlow — Product Overview

## Purpose
PocketFlow is a local-first personal finance tracker built with Flutter. All data is stored on-device using SQLite — no cloud account or internet required for core functionality.

## Key Features
- **Transaction tracking** — log income and expenses with category, note, date, and account
- **Account management** — supports checking, savings, credit, and cash account types with running balance calculation
- **Account transfers** — move money between accounts (e.g. pay credit card from checking)
- **Budget tracking** — set monthly spending limits per category; auto-creates budget entries when expenses are logged
- **Savings goals** — create named goals with a target amount and track contributions
- **Chat/command interface** — enter financial data via natural-language-style text commands (e.g. `expense 45 food lunch @checking`)
- **Local REST API** — embedded HTTP server (port 8080) exposes all data via JSON endpoints for external tools or automation
- **QR code connect** — share the local API server address via QR code for easy connection from other devices on the same network
- **Charts** — spending visualizations via fl_chart

## Supported Commands (Chat Screen)
| Command | Syntax |
|---|---|
| Log expense | `expense <amount> <category> [note] [@account]` |
| Log income | `income <amount> <category> [note] [@account]` |
| Set budget | `budget <category> <amount>` |
| Create savings goal | `savings <name> <target>` |
| Contribute to goal | `contribute <name> <amount>` |
| Add account | `account <name> <type> [balance]` |
| Transfer funds | `transfer <from> <to> <amount> [note]` |

## Target Users
- Individuals who want full control of their financial data without cloud services
- Users who prefer a simple command-driven or mobile-first finance tracker
- Developers/power users who want to automate finance logging via the local REST API

## Platforms
Flutter multi-platform: Android (primary), iOS, Web (Chrome/Edge), Windows, macOS, Linux
