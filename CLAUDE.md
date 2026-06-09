# CI/CD

This project uses GitHub Actions for CI/CD. The base CI runs pre-commit hooks using nscloud runners. See [docs/developer/standard/ci-cd.md](docs/developer/standard/ci-cd.md) for details.

# Conventional Commits

All commits must follow the conventional commits specification. Use `sg` for linting commit messages. See [docs/developer/standard/conventional-commits.md](docs/developer/standard/conventional-commits.md) for details.

# Development Environment

All binaries, tools, and PATH are managed by **Nix**. Do not install tools manually or modify PATH outside of the nix configuration.

## Prerequisites

1. **Nix** — package manager ([install](https://nixos.org/download))
2. **Docker** — container runtime ([install](https://docs.docker.com/get-docker))
3. **direnv** — auto-loads the nix shell on `cd` ([install](https://direnv.net/docs/installation.html))

## Getting Started

```bash
direnv allow    # first time only — loads the nix dev shell
```

## Nix Configuration

See **[docs/developer/standard/nix.md](docs/developer/standard/nix.md)** for the full guide on:

- File structure (`flake.nix`, `nix/`, `.envrc`)
- Adding/removing packages
- Environment groups and shells
- Formatters and pre-commit hooks
- Adding registries

# Linting

Pre-commit hooks enforce code quality via treefmt, shellcheck, gitlint, and infisical. See [docs/developer/standard/linting.md](docs/developer/standard/linting.md) for details.

# Secret Management

This project uses Infisical for secret management. Use `pls setup` to authenticate
and fetch secrets. See [docs/developer/standard/infisical.md](docs/developer/standard/infisical.md)
for details.

# Semantic Release

This project uses semantic-release for automated versioning. Version bumps are determined by commit types. See [docs/developer/standard/semantic-release.md](docs/developer/standard/semantic-release.md) for details.

# Service Tree

Services are identified by platform and service name. Configuration uses `alcohol` and `neon` variables. See [docs/developer/standard/service-tree.md](docs/developer/standard/service-tree.md) for details.

# Shell Conventions

All shell scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`. See [docs/developer/standard/shell-scripts.md](docs/developer/standard/shell-scripts.md) for details.

# Taskfile Conventions

Use `pls setup` to set up the repository and `pls lint` to run pre-commit hooks. See [docs/developer/standard/taskfile.md](docs/developer/standard/taskfile.md) for details.

<!-- ───────────────────────────────────────────────────────────────────────
     Project-specific guidance (alcohol.neon). Appended below the AtomiCloud
     template above so upstream template pulls stay conflict-free.
─────────────────────────────────────────────────────────────────────────── -->

# Project: alcohol.neon

The Flutter mobile app (iOS + Android) for the AtomiCloud _alcohol_ product. Companions:
**alcohol.zinc** (.NET backend), **alcohol.argon** (Next.js web).

## Stack — use this, not conventional defaults

- **Flutter / Dart**, iOS 17+ / Android.
- **Logto** auth via `logto_dart_sdk` (`signIn(redirectUri)`, `getAccessToken(resource:)`,
  `idTokenClaims`). It uses the system auth session, not an embedded webview.
- Talks to the **zinc** REST API; bearer = Logto access token for the `alcohol-zinc` resource.
- Tooling via **home-manager** (`~/.config/home-manager`, apply with `hms`): flutter, cocoapods,
  rsync (GNU — required for iOS), resvg (SVG→PNG). Don't `brew install`.

## Core patterns (mirror argon's discipline, in idiomatic Dart)

- **Errors:** `Result<T>` (`Ok`/`Err`) carrying a `Problem` (RFC 7807) — `lib/core/problem.dart`.
  Convert all failures (network/decoding/auth/HTTP non-2xx) to `Problem` at the boundary; never
  throw to widgets. Match with `switch (result) { case Ok(:final value): … }`.
- **Networking:** `ApiClient` (`lib/networking/api_client.dart`) — async, `Result<T>`, lazy bearer
  via a token provider. Get one from `AuthService.makeApiClient()`.
- **Auth:** `AuthService` (`lib/auth/auth_service.dart`) — a `ChangeNotifier` wrapping `LogtoClient`;
  `status` drives `RootView`. Provided at the root via `provider`.
- **Config:** `AppConfig` (`lib/config/app_config.dart`) — per-`Landscape` defaults selected at
  runtime from the app's **own bundle id** (bundle-id-as-marker), with `--dart-define` overrides
  (`NEON_LANDSCAPE`/`NEON_LOGTO_ENDPOINT`/`NEON_LOGTO_APP_ID`/`NEON_ZINC_URL`/`NEON_ZINC_RESOURCE`).
  `main()` awaits `AppConfig.load()`. `apiResources` is empty when no resource is set — requesting a
  resource a Logto tenant lacks **breaks the authorize request** (blank bounce-back).
- **Features:** one folder per feature under `lib/features/` (Root, Auth, Home, …). Use `provider`
  for state; grow into repositories (one per zinc domain) as features land — see the plan.

## Build / run

```bash
flutter pub get
flutter run -d <device> --flavor pichu
flutter analyze && flutter test
flutter build ios --debug --simulator --flavor pichu
flutter pub run flutter_launcher_icons   # regenerate launcher icons from assets/brand/logo.png
```

## Do / Don't

- ✅ `Result<T>` for anything fallible; convert at boundaries.
- ✅ all zinc calls through `ApiClient` + the Logto token provider.
- ✅ read `AppConfig`; never hardcode landscape URLs in features.
- ✅ install tools via home-manager (+ `hms`), not brew.
- ❌ don't throw to widgets or `catch`-and-ignore real errors.
- ❌ don't use `flutter_svg` for the brand logo — that SVG's fills are CSS-class based and render
  black; use the rasterized `assets/brand/logo.png` instead.
- ❌ don't bump `path_provider_foundation` past 2.4.x (native-assets/objective_c won't build on nix).

## Toolchain gotchas (macOS + nixpkgs Flutter)

- iOS builds need **GNU rsync** (macOS openrsync ignores `--chmod` → read-only framework → lipo
  fails). Installed via home-manager.
- Nix-store template files are copied read-only — if a build errors on permissions,
  `chmod -R u+w build ios android`.

## Release channels

3 channels map to landscapes — pichu (dev), pikachu (stage), raichu (prod) — as 3 bundle ids,
built/signed/published by **GitHub Actions** (`.github/workflows/cd.yaml`) on every `v*.*.*` tag
(semantic-release cuts these on `main`): iOS → TestFlight, Android → Play internal; prod (raichu)
promotion to the public App Store / Play production stays a manual gate. Signing secrets live as
org-level GitHub Actions secrets (synced from Infisical `raichu`). See
[docs/github-actions-release.md](docs/github-actions-release.md) for the runbook,
[docs/release-strategy.md](docs/release-strategy.md) for the channel strategy, and
[docs/codemagic-setup.md](docs/codemagic-setup.md) for the store/identity setup.
**Codemagic has been removed** — `codemagic.yaml` is gone; the migration to GHA is the current pipeline.

## Known setup dependency

A **Native** Logto app must be registered per landscape (App ID + redirect
`cloud.atomi.alcohol.neon://callback` + the `alcohol-zinc` resource). Until its App ID is in
`AppConfig` (or via `--dart-define`), the app builds/runs but sign-in won't complete.

## Status / next

Foundation + auth + branding done and verified on the iOS Simulator. Next: habit features against
zinc — today's habits (list + complete/skip), create/edit habit, onboarding, charities, and the
Airwallex payment-consent flow. See [docs/app-dev-plan.md](./docs/app-dev-plan.md).
