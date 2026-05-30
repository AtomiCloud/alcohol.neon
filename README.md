# alcohol.neon

Native **iOS app** for **LazyTax** (the AtomiCloud *alcohol* product): stake money on
your habits — miss one and the stake goes to charity. Companion to:

- **alcohol.zinc** — .NET 8 backend (habit + penalty/charity engine)
- **alcohol.argon** — Next.js web frontend

## Stack

- **Swift + SwiftUI**, iOS 17+
- **Logto** for auth (official [`logto-io/swift`](https://github.com/logto-io/swift) SDK)
- **XcodeGen** — the `.xcodeproj` is generated from [`project.yml`](./project.yml) and git-ignored
- **Task** (`task` / Taskfile.yml) as the runner, mirroring the `pls` convention in sibling repos

## Prerequisites

```bash
brew install xcodegen go-task/tap/go-task   # project generation + task runner
# Xcode 15+ (iOS 17 SDK)
```

## Getting started

```bash
task generate      # generate AlcoholNeon.xcodeproj from project.yml
task open          # generate + open in Xcode
task build         # build for the iOS Simulator
```

Run from Xcode (⌘R) on a simulator.

## ⚠️ Required before sign-in works: register a Native Logto app

The Logto app IDs in argon are for the **web** (SPA) application. iOS needs its **own**
Logto application of type **Native**:

1. In the Logto admin console (the *lithium* service for the target landscape), create a
   **Native** application.
2. Add redirect URI: `cloud.atomi.alcohol.neon://callback`
3. Grant it the **alcohol-zinc** API resource and the scopes
   (`openid profile offline_access email admin active`).
4. Paste the resulting **App ID** into `Sources/Config/AppConfig.swift`
   (`logtoAppId`, per landscape — currently `REPLACE_WITH_NATIVE_LOGTO_APP_ID`).

Until then the app builds and runs, but sign-in cannot complete.

## Landscape selection

Defaults to **pichu** (shared dev). Override with the `NEON_LANDSCAPE` env var in your
Xcode scheme (`lapras` / `pichu` / `pikachu` / `raichu`).

## Status

**Foundation + auth** (this iteration): project setup, config/landscapes, networking
(`Result<T, Problem>`), Logto sign-in/out, and an authenticated home screen that proves
the zinc-API token wiring. Habit features come next — see [CLAUDE.md](./CLAUDE.md).
