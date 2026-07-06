# Development Environment

All binaries, tools, and PATH are managed by **Nix**. Do not install tools manually or modify PATH outside of the nix configuration.

## Prerequisites

1. **[Nix](https://nixos.org/download)** — package manager
2. **[Docker](https://docs.docker.com/get-docker)** — container runtime
3. **[direnv](https://direnv.net/docs/installation.html)** — auto-loads the nix shell on `cd`

## Getting Started

```bash
direnv allow    # first time only — loads the nix dev shell
```

Once allowed, direnv automatically loads the development environment whenever you enter the project directory.

## Nix Configuration

See [docs/developer/standard/nix.md](docs/developer/standard/nix.md) for the full guide on:

- File structure (`flake.nix`, `nix/`, `.envrc`)
- Adding/removing packages
- Environment groups and shells
- Formatters and pre-commit hooks
- Adding registries

<!-- ───────────────────────────────────────────────────────────────────────
     Project-specific content (alcohol.neon). Appended below the template
     above so upstream template pulls stay conflict-free.
─────────────────────────────────────────────────────────────────────────── -->

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

## Getting started (app)

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

Per-landscape defaults live in `lib/config/app_config.dart`. Each landscape ships as its own app
(bundle-id-as-marker): the running binary picks its landscape from its **own bundle id**
(`…neon.pichu` / `.pikachu` / base `…neon`). A `--dart-define` override still wins for local dev:

```bash
flutter run --flavor pichu \
  --dart-define=NEON_LANDSCAPE=pichu \
  --dart-define=NEON_LOGTO_APP_ID=<native app id> \
  --dart-define=NEON_LOGTO_ENDPOINT=<logto endpoint> \
  --dart-define=NEON_ZINC_RESOURCE=<resource | empty to disable>
```

## ⚠️ Required before sign-in works: a Native Logto app

Sign-in needs a Logto application of type **Native** with redirect URI
`cloud.atomi.<landscape>.alcohol.neon://callback` and access to the `alcohol-zinc` resource. Put its
**App ID** in `AppConfig` (or pass `--dart-define=NEON_LOGTO_APP_ID=...`). Until then the app
builds and runs, but sign-in cannot complete.

## Branding

The logo lives in `assets/brand/` (`logo.svg` source, `logo.png` rasterized via `resvg`). It's
shown on the sign-in screen and used for the launcher icon (`flutter_launcher_icons` — regenerate
with `flutter pub run flutter_launcher_icons`).

## Release

3 channels map to AtomiCloud landscapes — pichu (dev), pikachu (stage), raichu (prod). See
[docs/release-strategy.md](./docs/release-strategy.md) and [docs/codemagic-setup.md](./docs/codemagic-setup.md).

## Status

**Foundation + auth**: config/landscapes, `Result`/`Problem` errors, `ApiClient`,
Logto sign-in/out, the auth-gated shell, branding (logo + icon). Builds & runs on the iOS
Simulator. Habit features come next — see [docs/app-dev-plan.md](./docs/app-dev-plan.md).
