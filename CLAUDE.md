# CLAUDE.md

Guidance for Claude Code when working in **alcohol.neon** — the native iOS app for the
AtomiCloud *alcohol* product. Companion repos: **alcohol.zinc** (.NET backend),
**alcohol.argon** (Next.js web).

## Stack — use this, not conventional defaults

- **Swift + SwiftUI**, iOS 17+ — no UIKit unless a feature genuinely needs it
- **Logto** auth via the official `logto-io/swift` SDK (`import Logto`, `import LogtoClient`)
- **XcodeGen**: edit `project.yml`, never the generated `.xcodeproj` (it's git-ignored).
  Run `task generate` after changing `project.yml`.
- **Task** runner: `task generate` / `task build` / `task open`
- Talks to the **zinc** REST API; auth via Logto access tokens scoped to the
  `alcohol-zinc` API resource.

## Core patterns (mirror argon's discipline, in idiomatic Swift)

### Errors: `Result<T, Problem>`, never throw across boundaries
`Problem` (`Sources/Core/Problem.swift`) is RFC 7807, the single error currency — the
same shape zinc returns. Convert all failures (network, decoding, auth, HTTP non-2xx) to
`Problem` at the boundary and return `Result<T, Problem>`. Use `Problem.local/network/decoding`
for client-side failures. Don't surface raw `Error`/`throws` to views.

```swift
let result = await apiClient.get("/api/v1/Habit", as: [Habit].self)
switch result {
case .success(let habits): …
case .failure(let problem): …  // already RFC 7807
}
```

### Networking: `ApiClient` (`Sources/Networking/ApiClient.swift`)
Async, returns `Result<T, Problem>`, injects the Bearer token lazily via a
`tokenProvider`. Get a pre-wired client from `AuthService.makeApiClient()`. Add typed
endpoint methods here as features land (consider generating from zinc's OpenAPI later).

### Auth: `AuthService` (`Sources/Auth/AuthService.swift`)
`@MainActor ObservableObject` wrapping `LogtoClient`. The SDK persists/refreshes tokens
in the Keychain — don't hand-roll storage. `status: AuthStatus` drives `RootView`.
`zincAccessToken()` mints the API-resource token for the Bearer header.

### Config: `AppConfig` (`Sources/Config/AppConfig.swift`)
Per-`Landscape` (lapras/pichu/pikachu/raichu). Values mirror argon's settings.yaml.
`AppConfig.current` picks the landscape from the `NEON_LANDSCAPE` env var (default pichu).

### DI
Lightweight for now: `AuthService` is created in `AlcoholNeonApp` and passed via
`.environmentObject`. Grow into a container only when more services appear.

## File structure

```
project.yml                 # XcodeGen source of truth
Sources/
  App/                      # @main entry
  Config/                   # Landscape + AppConfig
  Core/                     # Problem (RFC 7807)
  Networking/               # ApiClient
  Auth/                     # AuthService (Logto)
  Features/<Feature>/       # SwiftUI screens (Root, Auth, Home, …)
Resources/                  # Assets.xcassets, Info.plist
```

## Do / Don't

- ✅ `Result<T, Problem>` for anything fallible; convert at boundaries
- ✅ shared `ApiClient` + Logto token provider for all zinc calls
- ✅ edit `project.yml` then `task generate`
- ✅ one feature = one folder under `Sources/Features/`
- ❌ don't throw to views, don't use `try?`-and-ignore for real errors
- ❌ don't hand-edit the `.xcodeproj`
- ❌ don't call zinc with ad-hoc `URLSession` — go through `ApiClient`
- ❌ don't hardcode landscape URLs in features — read `AppConfig`

## Known setup dependency

A **Native** Logto application must be registered (its own App ID + redirect
`cloud.atomi.alcohol.neon://callback` + the `alcohol-zinc` resource). Until the App ID
is filled into `AppConfig`, the app builds/runs but sign-in won't complete. See README.

## Status / next

Foundation + auth is in place. Next: habit features against zinc — today's habits
(list + complete/skip), create/edit habit, onboarding, charities, and the Airwallex
payment-consent flow (the backend penalty engine is in alcohol.zinc).
