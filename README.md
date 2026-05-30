# alcohol.neon

Cross-platform **mobile app (Flutter — iOS + Android)** for the AtomiCloud *alcohol*
product: stake money on your habits; miss one and the stake goes to charity. Companion to:

- **alcohol.zinc** — .NET 8 backend (habit + penalty/charity engine)
- **alcohol.argon** — Next.js web frontend

## Stack

- **Flutter / Dart**, iOS 17+ / Android
- **Logto** auth via `logto_dart_sdk` (uses `flutter_web_auth_2` → ASWebAuthenticationSession on iOS, Custom Tabs on Android)
- Talks to the **zinc** REST API; access tokens are minted for the `alcohol-zinc` API resource
- Tooling installed via **home-manager** (Flutter, CocoaPods, GNU rsync, resvg)

## Getting started

```bash
flutter pub get
flutter run            # add -d <device> to pick a simulator/emulator
flutter analyze        # lints/type-check
flutter test           # unit tests
flutter build ios --debug --simulator   # iOS build
```

### macOS / nixpkgs-Flutter notes (already handled, documented for the record)

- **GNU rsync is required** for iOS builds — macOS's bundled `openrsync` ignores `rsync --chmod`,
  leaving the Nix-store Flutter framework read-only (lipo fails). Installed via home-manager.
- **`path_provider_foundation` is pinned to 2.4.1** (`dependency_overrides`) — newer versions use
  Flutter's experimental native-assets/FFI (`objective_c`), which doesn't build under nixpkgs Flutter.
- If a build complains about read-only files, `chmod -R u+w build ios android` (Nix-store templates
  are copied read-only).

## Configuration

Per-landscape defaults live in `lib/config/app_config.dart`, overridable at build via
`--dart-define` (the Flutter-native way to inject per-build config):

```bash
flutter run \
  --dart-define=NEON_LANDSCAPE=pichu \
  --dart-define=NEON_LOGTO_APP_ID=<native app id> \
  --dart-define=NEON_LOGTO_ENDPOINT=<logto endpoint> \
  --dart-define=NEON_ZINC_RESOURCE=<resource | empty to disable>
```

## ⚠️ Required before sign-in works: a Native Logto app

Sign-in needs a Logto application of type **Native** with redirect URI
`cloud.atomi.alcohol.neon://callback` and access to the `alcohol-zinc` resource. Put its
**App ID** in `AppConfig` (or pass `--dart-define=NEON_LOGTO_APP_ID=...`). Until then the app
builds and runs, but sign-in cannot complete.

## Branding

The logo lives in `assets/brand/` (`logo.svg` source, `logo.png` rasterized via `resvg`). It's
shown on the sign-in screen and used for the launcher icon (`flutter_launcher_icons` — regenerate
with `flutter pub run flutter_launcher_icons`).

## Status

**Foundation + auth** (this iteration): config/landscapes, `Result`/`Problem` errors, `ApiClient`,
Logto sign-in/out, the auth-gated shell, branding (logo + icon). Builds & runs on the iOS
Simulator. Habit features come next — see [docs/app-dev-plan.md](./docs/app-dev-plan.md).
