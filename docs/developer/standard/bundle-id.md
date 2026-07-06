---
id: bundle-id
title: Bundle & Application IDs (LPSM)
---

# Bundle & Application IDs (LPSM)

Every store-facing identifier derives from the [Service Tree (LPSM)](./service-tree.md).
Nothing is hand-picked; one grammar generates the iOS bundle id, the Android
application id, the App Group, the deeplink scheme, and the OAuth redirect URI.

## Grammar

```
bundle_id   = "cloud.atomi" "." landscape "." platform "." service [ "." module ]*
app_group   = "group." bundle_id(app)          # per landscape, no module segment
scheme      = bundle_id(app)                    # custom-URL/deeplink scheme
redirect    = scheme "://callback"              # Logto redirect URI
package     = bundle_id                         # Android — identical string
```

This is LPSM rendered as reverse-DNS: broadest (landscape) → narrowest (module),
after the reversed domain (`atomi.cloud` → `cloud.atomi`).

### For alcohol.neon

| Thing               | pichu (dev)                                 | raichu (prod)                                |
| ------------------- | ------------------------------------------- | -------------------------------------------- |
| App (iOS + Android) | `cloud.atomi.pichu.alcohol.neon`            | `cloud.atomi.raichu.alcohol.neon`            |
| Home-screen widget  | `cloud.atomi.pichu.alcohol.neon.widget`     | `cloud.atomi.raichu.alcohol.neon.widget`     |
| App Group           | `group.cloud.atomi.pichu.alcohol.neon`      | `group.cloud.atomi.raichu.alcohol.neon`      |
| Logto redirect      | `cloud.atomi.pichu.alcohol.neon://callback` | `cloud.atomi.raichu.alcohol.neon://callback` |

Flavorless local builds map to the `lapras` landscape
(`cloud.atomi.lapras.alcohol.neon`); the unit-test bundle uses the `tests` module.

## Rules

1. **Main app has no module segment; every embedded target adds one.** Apple
   requires an extension's bundle id to be `<parent>.<suffix>` — module-last
   satisfies it, and nesting works (`…neon.watch`, `…neon.watch.widget`).
2. **Segments are `[a-z][a-z0-9]*`** — lowercase, start with a letter, no `-`
   (Android forbids) and no `_` (iOS forbids). This is what lets iOS and Android
   share one string.
3. **No Java keywords as segments** (`new`, `native`, `int`, …) — Android chokes.
4. **App Group = `group.` + the app's bundle id.** Per-landscape, so dev/stage/prod
   widget data never bleed across. All modules of one landscape share it.
   (Note: group containers are per-device — a future watch app syncs via
   WatchConnectivity, not via the group.)
5. **The deeplink scheme is the app's bundle id.** Per-landscape schemes mean the
   OS never routes a callback to the wrong flavor when several are installed.

## Where it's wired

- iOS: `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER` +
  `NEON_APP_GROUP` per configuration; entitlements reference `$(NEON_APP_GROUP)`,
  Swift reads it via the `NeonAppGroup` Info.plist key).
- Android: `android/app/build.gradle.kts` (per-flavor `applicationId` +
  `logtoRedirectScheme`). The gradle `namespace`/Kotlin package stays
  `cloud.atomi.alcohol_neon` — it's internal, not store-facing.
- Dart: `AppConfig` resolves the landscape from segment 3 of the package name;
  `WidgetService` derives the App Group as `group.<packageName>`;
  `config/<landscape>.yaml` carries the redirect URI.
- CI: `scripts/ci/cd-matrix.sh` derives ids; `scripts/ci/ios-signing-targets.sh`
  discovers all signing targets from the Xcode project.

## Registration & automation boundary

| Operation                            | Automated by                                          | Auth               |
| ------------------------------------ | ----------------------------------------------------- | ------------------ |
| Bundle id / App ID creation          | CD (`fetch-signing-files --create`) or `pls register` | API key / Apple ID |
| Certificates + provisioning profiles | CD (`fetch-signing-files --create`)                   | API key            |
| App Groups capability toggle         | `pls register`                                        | Apple ID           |
| **App Group creation**               | `pls register` **only** — no ASC API exists           | Apple ID + 2FA     |
| **Group ⇄ App ID association**       | `pls register` **only** — no ASC API exists           | Apple ID + 2FA     |
| Verification that it's all wired     | CD (`scripts/ci/doctor-ios.sh`, decodes profiles)     | API key            |
| ASC app record / Play Console app    | Manual, once per landscape                            | Human              |

**Adding a widget/extension/watch target:** add the target in Xcode with its LPSM
bundle id, run `pls register` (App Manager Apple ID, one 2FA tap), commit. CI
discovers the target automatically; the doctor step fails any release where
registration was skipped, naming the missing piece.

Android needs no registration for any of this — widgets are plain code, and
app↔widget sharing is in-process storage under one signed app.
