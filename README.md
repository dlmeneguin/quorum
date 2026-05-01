# Quórum — Personal Finance

> **Local-first** personal finance management app for **Windows** and **Android**, built with Flutter/Dart.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Android](https://img.shields.io/badge/Android-API%2021+-3DDC84?logo=android)
![Windows](https://img.shields.io/badge/Windows-10%2B-0078D4?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📱 About the project

Quórum is a personal finance manager that runs **100% on your device** — no external servers, no mandatory cloud account. Your data stays where it belongs: with you.

Device sync is optional via Google Drive. Manual JSON backup is also available for those who prefer full control.

---

## ✨ Features

### 💳 Accounts & Wallets
- Multiple account types: checking, savings, cash wallet, credit card
- Configurable initial balance per account
- Real-time balance, reactively calculated
- Transfers between accounts with balance validation
- Account detail screen with history, charts, and linked goals

### 💸 Transactions
- Income and expense tracking
- Transfers between accounts
- Recurring transactions (monthly)
- Installment payments (generates N monthly entries)
- Filters by period, category, and payment method
- Fuzzy search with tolerance for typos and accents

### 📊 Dashboard
- Consolidated net worth
- Monthly summary: income, expenses, and balance
- Net worth distribution (donut chart)
- Net worth evolution (line chart — 6 months)
- Spending by category (interactive donut chart)
- Upcoming entries: future recurring transactions and installments

### 🎯 Financial Goals
- Create goals with target amount, date, and linked account
- Manual contributions and withdrawals with balance validation
- Projected completion date based on historical pace
- Status: active, paused, or completed

### 📋 Monthly Budget
- Spending limits per category
- Progress bars with visual alerts (80% and 100%)
- Monthly summary with total spent vs. limit
- Month-by-month navigation

### ⚙️ Settings
- Customizable categories (name, color with RGB picker, type)
- Themes: Light, Dark, System, and Alberto 🐾
- Manual backup (JSON export/import)
- Automatic sync via Google Drive
- Automatic transaction import via [Pluggy](https://pluggy.ai) (Open Finance)

### 🟪 Pix
- Generate Pix QR Codes for any key type (CPF, CNPJ, phone, email, or random key)
- Pix copia e cola (copy-and-paste Pix payload) ready to share
- Preset amount shortcuts for faster payment generation

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI + Logic | Flutter + Dart |
| Database | SQLite via [Drift](https://drift.simonbinder.eu/) |
| State management | [flutter_riverpod](https://riverpod.dev/) |
| Charts | [fl_chart](https://pub.dev/packages/fl_chart) |
| Typography | DM Sans + Spline Sans (Google Fonts) |
| Sync | Google Drive API |
| Open Finance | Pluggy API |
| Backup | file_picker + share_plus |
| Formatting | intl (pt-BR) |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x
- Android Studio (for Android emulator) or a physical device
- Visual Studio Build Tools (for Windows build)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/quorum.git
cd quorum

# Install dependencies
flutter pub get

# Generate database code (Drift)
dart run build_runner build --delete-conflicting-outputs
```

### Environment variables

Create a `.env` file at the project root:

```env
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
```

> Google credentials are only required for the Drive sync feature. The app works fully without them.

### Running the app

```bash
# Android
flutter run

# Windows
flutter run -d windows

# Release
flutter build apk --release       # Android
flutter build windows --release   # Windows
```

---

## 📁 Project Structure

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── database/          # Drift: tables, DAOs, migrations
│   ├── models/            # Pure domain models
│   ├── services/          # Business logic (sync, backup, merge)
│   └── utils/             # Formatting, validation, fuzzy search
│
├── features/
│   ├── dashboard/         # Main screen with summaries and charts
│   ├── transactions/      # Transaction CRUD
│   ├── accounts/          # Accounts and account detail screens
│   ├── budget/            # Monthly budget
│   ├── goals/             # Financial goals
│   ├── settings/          # Settings, categories, themes
│   ├── pluggy/            # Open Finance integration
│   └── pix/               # Pix QR Code & copy-paste payload generator
│
└── shared/
    ├── theme/             # Colors, typography, themes
    └── widgets/           # Reusable widgets
```

---

## 🗄️ Database

SQLite schema managed by Drift with soft delete on all tables:

- `accounts` — accounts and wallets
- `categories` — transaction categories
- `transactions` — entries (income, expenses, transfers)
- `budgets` — monthly limits per category
- `goals` — financial goals
- `goal_contributions` — contribution history for goals

Device sync uses `updatedAt`-based merging with last-write-wins conflict resolution.

---

## ☁️ Sync

Quórum offers optional sync via Google Drive:

- Automatic upload after each change (10s debounce)
- Periodic check for remote changes (every 30s)
- Smart merge: local and remote records are merged by `updatedAt`
- Reset signal: when all data is deleted, other devices are notified
- SHA-256 content hash prevents unnecessary uploads

---

## 🔌 Open Finance (Pluggy)

Quórum integrates with [Pluggy](https://pluggy.ai) to automatically import transactions from Brazilian financial institutions:

1. Connect your bank at [meu.pluggy.ai](https://meu.pluggy.ai)
2. Create an Application at [dashboard.pluggy.ai](https://dashboard.pluggy.ai)
3. Set up credentials in **Settings → Open Finance**

Credentials are stored locally with XOR obfuscation — they are never sent to any external servers.

---

## 🎨 Themes

| Theme | Description |
|---|---|
| **Light** | Light interface with emerald green as the primary color |
| **Dark** | Dark background (#0F1117) for nighttime use |
| **System** | Follows the operating system preference |
| **Alberto** | Special pink theme featuring the app mascot 🐾 |

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues and pull requests.

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

*Quórum — because at the very least, you should know your own finances.*
