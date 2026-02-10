# 🧘 Zen Focus

A minimalist Pomodoro-style focus timer built with Flutter. Designed to help you stay focused, distraction-free, and productive.

> **Offline-first. No ads. No tracking. Just focus.**

---

## ✨ Features

- ⏱️ **Pomodoro Timer** — Customizable focus sessions (5, 15, 25, 30, 45, 60 minutes)
- 🎯 **Circular Progress Ring** — Beautiful animated countdown indicator
- 🔔 **Completion Chime** — Soft audio notification when your session ends
- 📊 **Daily Stats** — Track your total focus time today
- 🌙 **Dark & Light Mode** — Auto-detects your system theme
- 💾 **Persistent Settings** — Remembers your last timer duration and preferences
- 📱 **Lifecycle-Aware** — Timer stays accurate even when app is backgrounded
- 🔒 **Zero Permissions** — No internet, no camera, no location. 100% offline.

---

## 📸 Screenshots

| Light Mode | Dark Mode |
|:---:|:---:|
| *Coming soon* | *Coming soon* |

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # Entry point, Material 3 theming, Provider setup
├── providers/
│   └── timer_provider.dart      # Timer state management (ChangeNotifier)
├── screens/
│   └── home_screen.dart         # Main UI with circular timer & controls
└── services/
    └── settings_service.dart    # SharedPreferences wrapper for persistence
```

### Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (latest stable) |
| **State Management** | Provider (ChangeNotifier) |
| **Local Storage** | SharedPreferences |
| **Audio** | audioplayers |
| **Typography** | Inter (locally bundled) |
| **Design System** | Material 3 |

---

## 🛡️ ANR Prevention

This app is engineered to prevent **App Not Responding (ANR)** errors:

1. **Timestamp-based timer** — Uses `DateTime` wall-clock calculations instead of decrementing an integer. The timer stays accurate even if the OS throttles or skips ticks.
2. **Lifecycle-aware** — Implements `WidgetsBindingObserver` to pause the ticker when backgrounded and recalculate from wall-clock time when resumed.
3. **Async I/O only** — All SharedPreferences operations are non-blocking.
4. **Scoped rebuilds** — Uses `Consumer<TimerProvider>` to rebuild only timer-dependent widgets, keeping frame times well under 16ms.
5. **Platform-thread audio** — The completion chime plays on the native platform thread, never blocking the Dart isolate.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio / VS Code
- Android device or emulator

### Installation

```bash
# Clone the repository
git clone https://github.com/mifune96/zen_focus.git
cd zen_focus

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

---

## 📋 Google Play Store Compliance

This app is designed to be **fully compliant** with Google Play policies:

- ✅ No dangerous permissions
- ✅ No internet access required
- ✅ No user data collection
- ✅ No third-party SDKs or trackers
- ✅ Offline-first architecture
- ✅ Clean, modular codebase
- ✅ ProGuard/R8 configured for release builds
- ✅ Proper application ID (`com.aliimran.zenfocus`)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to open an issue or submit a pull request.

---

<p align="center">
  Made with ❤️ and Flutter
</p>
