# Changelog

## 1.0.0 — 2026-05-15

Initial public release.

### Features
- SwiftUI main window with tabs: Status, Servers, Settings, About
- Multiple server profiles (add/edit/delete, switch active server)
- Auto-detection and auto-disconnect of conflicting VPNs (system VPNs via `scutil`, known processes via root helper)
- Connection state machine with proper UI feedback (Disconnected / Connecting / Connected / Error)
- Connection duration timer
- Menu bar status item with quick toggle
- Privileged helper script with strict CLI for route management
- Programmatic app icon generation
- Persistent settings via UserDefaults
- Migration from earlier prototype's settings keys
- **Universal binary** (arm64 + x86_64) via `lipo`
- **Localization**: English (base) and Russian (`Resources/en.lproj/Localizable.strings`, `Resources/ru.lproj/Localizable.strings`). Auto-selects based on system language; can be overridden via `defaults write com.dnstunnel.app AppleLanguages -array "en"`.
