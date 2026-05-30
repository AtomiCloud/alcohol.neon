# CLAUDE.md

Guidance for Claude Code when working in **alcohol.neon** — the Flutter mobile app (iOS +
Android) for the AtomiCloud *alcohol* product. Companions: **alcohol.zinc** (.NET backend),
**alcohol.argon** (Next.js web).

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
- **Config:** `AppConfig` (`lib/config/app_config.dart`) — per-`Landscape` defaults with
  `--dart-define` overrides (`NEON_LANDSCAPE`/`NEON_LOGTO_ENDPOINT`/`NEON_LOGTO_APP_ID`/
  `NEON_ZINC_URL`/`NEON_ZINC_RESOURCE`). `apiResources` is empty when no resource is set —
  requesting a resource a Logto tenant lacks **breaks the authorize request** (blank bounce-back).
- **Features:** one folder per feature under `lib/features/` (Root, Auth, Home, …). Use `provider`
  for state; grow into repositories (one per zinc domain) as features land — see the plan.

## Build / run

```bash
flutter pub get
flutter run -d <device>
flutter analyze && flutter test
flutter build ios --debug --simulator
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

## Known setup dependency

A **Native** Logto app must be registered (App ID + redirect `cloud.atomi.alcohol.neon://callback`
+ the `alcohol-zinc` resource). Until its App ID is in `AppConfig` (or via `--dart-define`), the app
builds/runs but sign-in won't complete.

## Status / next

Foundation + auth + branding done and verified on the iOS Simulator. Next: habit features against
zinc — today's habits (list + complete/skip), create/edit habit, onboarding, charities, and the
Airwallex payment-consent flow. See [docs/app-dev-plan.md](./docs/app-dev-plan.md).
