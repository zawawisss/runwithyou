# runwithyou

Flutter fitness + task manager app for a teacher with a busy schedule. Android-first, Bahasa Indonesia.

Full project spec: [`docs/alur.md`](docs/alur.md)

## Key commands

- `flutter pub get` — install dependencies
- `flutter analyze` — lint (uses `package:flutter_lints/flutter.yaml`)
- `flutter test` — run widget tests in `test/`
- `flutter run -d web-server --web-port=8080` — run in browser (for remote dev)
- `flutter build apk` — build Android APK

## Tech stack

- **State management:** Riverpod
- **Local DB:** Hive
- **Charts:** fl_chart
- **HTTP:** Dio
- **Routing:** go_router
- **Health integration:** Huawei Health Kit (coming soon)
- **AI backend:** OpenRouter (coming soon)

## Project structure

```
lib/
├── main.dart                    # App entrypoint
├── utils/
│   └── theme.dart               # Colors & theme (pink/teal)
├── screens/
│   ├── dashboard_screen.dart    # Home dashboard
│   ├── tasks_screen.dart        # Task manager
│   ├── jogging_screen.dart      # Jogging tracker
│   ├── progress_screen.dart     # Stats & history
│   └── profile_screen.dart      # User profile
├── widgets/                     # Reusable components
├── models/                      # Data models
├── providers/                   # Riverpod providers
└── services/                    # API, Huawei Health, AI
```

## Design constraints

- **Primary color:** Soft Pink `#FF8A9B`
- **Accent:** Teal `#4ECDC4`
- **Style:** Feminine, clean, calming, sporty
- **Dark mode:** Required
- App language is Bahasa Indonesia

## Notes

- Preview UI via Chrome: `flutter run -d web-server` then open `http://localhost:8080`
- Android build uses Kotlin/Gradle (`build.gradle.kts`)
- Placeholder screens created — ready for feature implementation
