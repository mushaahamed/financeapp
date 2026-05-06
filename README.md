# Paisa — Personal Finance & Investment Tracker

A fully local, offline-first Android app for tracking cash, expenses, and investments. No cloud, no account, no data leaves your phone.

---

## Features

- **Cash dashboard** — track current cash balance, quick-add expenses
- **Expenses** — full list with filters (today / week / month), edit and delete
- **Investments** — portfolio with buy/sell transactions, P&L, return %
- **Gemini AI prices** — optional weekly auto-update of asset prices via Gemini API
- **100% offline** — SQLite on-device, Gemini key stored in Android Keystore

---

## Requirements

- Flutter SDK **3.22+** ([install](https://docs.flutter.dev/get-started/install))
- Android SDK with a device or emulator running Android **6.0+** (API 23+)
- Java 17+ (for Gradle)

---

## Build & Install

### 1. Install Flutter dependencies

```bash
cd paisa
flutter pub get
```

### 2. Set up `android/local.properties`

Copy the example file and fill in your paths:

```bash
cp android/local.properties.example android/local.properties
```

Edit `android/local.properties`:

```
sdk.dir=C:\Users\YourName\AppData\Local\Android\Sdk
flutter.sdk=C:\src\flutter
flutter.versionName=1.0.0
flutter.versionCode=1
```

> **Windows tip:** Use double backslashes `\\` or forward slashes `/` in paths.

### 3. Build the APK

```bash
flutter build apk --release
```

The APK will be at:

```
build/app/outputs/flutter-apk/app-release.apk
```

### 4. Install on device

Enable **"Install from unknown sources"** on your Android phone, then:

```bash
flutter install
# OR copy the APK to your phone and tap to install
```

---

## First Launch

1. Open **Paisa**
2. Enter your **current cash balance**
3. Optionally paste your **Gemini API key** (for automatic investment price updates)
4. Tap **Get Started**

---

## Getting a Gemini API Key (Free)

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Sign in with your Google account
3. Click **Get API key** → **Create API key**
4. Copy the key (starts with `AIza...`)
5. Paste it in the app on first launch, or later via **Settings** (gear icon on Dashboard)

The free tier (Gemini 2.0 Flash) allows ~1500 requests/day, far more than the app ever needs.

---

## Changing the Gemini Model

In the app go to **Settings** (gear icon) → **Model** field. Valid model strings:

| Model | Notes |
|---|---|
| `gemini-2.0-flash` | Default. Free tier, fast. |
| `gemini-2.5-flash` | More accurate, free tier. |
| `gemini-1.5-flash` | Stable fallback. |

---

## Auto Price Updates

- Enable in **Settings → Auto Price Update**
- Runs once a week in the background (Android best-effort timing)
- Requires a valid Gemini API key and network access
- You can also tap the **↻ refresh** button on the Investments screen anytime

---

## Project Structure

```
paisa/
  lib/
    core/               Constants, theme, formatters
    data/
      database/         SQLite helper (sqflite, no codegen)
      models/           Dart data classes
      repositories/     DB access + cash adjustment logic
      services/         Gemini HTTP client, WorkManager background job
    providers/          All Riverpod StateNotifiers and providers
    presentation/
      screens/
        onboarding/     First-launch screen
        dashboard/      Cash overview + quick-add
        expenses/       Expense list + add/edit sheets
        investments/    Portfolio + asset detail + transactions
        settings/       All app settings
      widgets/          Reusable UI components
  android/              Native Android project
```

---

## How Cash Auto-Deduction Works

| Action | Effect on Cash |
|---|---|
| Add expense | Cash **decreases** by expense amount |
| Delete expense | Cash **increases** (refund) |
| Edit expense | Cash adjusted by the **difference** |
| Buy investment | Cash **decreases** by units × price |
| Sell investment | Cash **increases** by units × price |
| Delete transaction | Cash impact is **reversed** |

---

## Troubleshooting

**`flutter.sdk not set in local.properties`**
→ Create `android/local.properties` from the example file.

**Gradle build fails with "Could not resolve..."**
→ Run with VPN off if you're behind a proxy. Or run `flutter clean` then retry.

**Prices not updating**
→ Check your Gemini API key in Settings. Ensure the device has internet. Try the manual refresh button (↻).

**App crashes on launch**
→ Run `flutter run` to see the full error log.

---

## Customisation

All visual constants are in [`lib/core/constants.dart`](lib/core/constants.dart):

```dart
const kPrimary = Color(0xFF2563EB);  // accent color
```

Change `kPrimary` to any color you like and rebuild.
