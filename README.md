# OpenHealth

**Free your health data.** OpenHealth is an open-source iOS app that reads, displays, and exports your Apple Health data — no subscriptions, no paywalls, no vendor lock-in.

## Why?

Your iPhone collects detailed health data every day, but accessing and using that data often requires paid third-party apps. OpenHealth gives you full control: view your metrics on a clean dashboard, export them in standard formats, and optionally sync them to your own server. Your data belongs to you.

## Features

- **Tile-based Dashboard** — At-a-glance view of all active health sensors as a grid of tiles, each showing the latest value and a mini sparkline chart for trends
- **10 HealthKit data types** — Steps, weight, heart rate, resting heart rate, blood pressure (systolic & diastolic), oxygen saturation, active energy burned, sleep analysis, respiratory rate
- **Detailed sensor views** — Tap any tile to see a full detail view with interactive charts (line charts, bar charts), historical data, and summary statistics
- **Blood pressure insights** — Combined systolic/diastolic chart with automatic pulse pressure calculation, BP classification (Normal/Elevated/High Stage 1/High Stage 2), and paired readings display
- **Flexible time ranges** — View data for 7 days, 30 days, 90 days, 6 months, or 1 year on any detail page
- **Configurable data types** — Enable/disable individual health data types in settings with persistent toggle state
- **Export to JSON or CSV** — Generate export files filtered by time range (today, week, month, year, or all)
- **Share anywhere** — Use the native iOS share sheet to send exports via AirDrop, Mail, Files, or any other app
- **API sync (in progress)** — Configure a server URL and API key to push data to your own backend
- **Privacy-first** — All data is stored locally on your device. Nothing leaves your phone unless you explicitly export or sync it
- **German-localized UI** — Interface fully in German

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Charts | Swift Charts |
| Data persistence | SwiftData |
| Health data | HealthKit |
| Language | Swift 5.9+ |
| IDE | Xcode 15.0+ |
| Target | iOS 17+ |

No external dependencies — the app is built entirely on Apple frameworks.

## Getting Started

1. Clone the repository
2. Open `OpenHealth.xcodeproj` in Xcode 15 or later
3. Select a physical device as the build target (HealthKit is not available in the Simulator)
4. Build and run
5. Grant HealthKit permissions when prompted

## Supported Health Data

| Type | Unit | Description |
|------|------|-------------|
| Steps | count | Daily step count |
| Weight | kg | Body mass |
| Heart Rate | bpm | Current heart rate |
| Resting Heart Rate | bpm | Resting heart rate |
| Blood Pressure (sys) | mmHg | Systolic blood pressure |
| Blood Pressure (dia) | mmHg | Diastolic blood pressure |
| Oxygen Saturation | % | Blood oxygen level |
| Active Energy | kcal | Calories burned through activity |
| Sleep | hours | Sleep analysis |
| Respiratory Rate | breaths/min | Breathing rate |

## Roadmap

- [ ] Server-side companion project (Laravel API) to receive and store health data
- [ ] Web-based dashboard for viewing synced data
- [x] Detailed statistics and trend analysis
- [ ] AI-powered health data insights
- [ ] Automatic background sync to self-hosted server
- [ ] Secure API key storage via Keychain

## Project Structure

```
OpenHealth/
├── OpenHealthApp.swift          # App entry point
├── ContentView.swift            # Tab-based navigation
├── Managers/
│   └── HealthKitManager.swift   # HealthKit integration
├── Models/
│   └── HealthDataItem.swift     # Data model & type definitions
└── Views/
    ├── DashboardView.swift      # Tile-based health metrics dashboard
    ├── SensorDetailView.swift   # Detail view with charts & time ranges
    ├── ExportView.swift         # Export & API sync
    └── SettingsView.swift       # App configuration
```

## Contributing

Contributions are welcome! This project is about making health data accessible to everyone. Feel free to open issues or submit pull requests.

## License

TBD
