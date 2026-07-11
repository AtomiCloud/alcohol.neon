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
bundle_id   = "cloud.atomi" "." landscape "." platform "." service ("." module)+
app_group   = "group." bundle_id(app)           # per landscape (app = the `app` module)
scheme      = bundle_id(app)                    # custom-URL/deeplink scheme
redirect    = scheme "://callback"              # Logto redirect URI
package     = bundle_id                         # Android — identical string
```

The module segment is **mandatory** — the main app is the `app` module, its
embedded targets nest under it (`app.widget`), and the unit-test bundle is the
peer `tests` module.

This is LPSM rendered as reverse-DNS: broadest (landscape) → narrowest (module),
after the reversed domain (`atomi.cloud` → `cloud.atomi`).

### For alcohol.neon

| Thing               | pichu (dev)                                     | raichu (prod)                                    |
| ------------------- | ----------------------------------------------- | ------------------------------------------------ |
| App (iOS + Android) | `cloud.atomi.pichu.alcohol.neon.app`            | `cloud.atomi.raichu.alcohol.neon.app`            |
| Home-screen widget  | `cloud.atomi.pichu.alcohol.neon.app.widget`     | `cloud.atomi.raichu.alcohol.neon.app.widget`     |
| App Group           | `group.cloud.atomi.pichu.alcohol.neon.app`      | `group.cloud.atomi.raichu.alcohol.neon.app`      |
| Logto redirect      | `cloud.atomi.pichu.alcohol.neon.app://callback` | `cloud.atomi.raichu.alcohol.neon.app://callback` |

Flavorless local builds map to the `lapras` landscape
(`cloud.atomi.lapras.alcohol.neon.app`); the unit-test bundle uses the `tests` module.

## Rules

1. **The main app is the `app` module; every embedded target nests under it.**
   Apple requires an extension's bundle id to be `<parent>.<suffix>` — module
   nesting satisfies it (`…neon.app.widget`; a future watch app:
   `…neon.app.watch`, its widget `…neon.app.watch.widget`).
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
- **`lpsm.yaml` is the single source of truth** — platform/service, team,
  landscapes, store names, apple_ids. `scripts/ci/cd-matrix.sh` derives the CD
  matrix from it; `scripts/ci/lpsm-lint.sh` (pre-commit) fails any literal in
  pbxproj/gradle/pubspec/config yamls that drifts from it; `scripts/ci/ios-signing-targets.sh`
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
| ASC app record + apple_id fill       | `pls register` (rename old apps first)                | Apple ID + 2FA     |
| Play Console app                     | Manual, once per landscape — no API                   | Human              |

### `pls register` — contract

`pls register [landscape ...]` (default: every landscape in `lpsm.yaml`) runs
`scripts/register-apple.sh` as a human App Manager/Admin: one interactive
sign-in (password + one 2FA tap, session cached by fastlane), then everything
else is non-interactive.

**Postconditions — after a successful run, for each requested landscape:**

1. The App Group `group.<app bundle id>` exists in the project's portal team.
2. Every signing target discovered from the Xcode project (app + all
   extensions, `.tests` excluded) has an App ID.
3. Each App ID has **exactly the capabilities declared for its module in
   `lpsm.yaml`'s `capabilities:` map** — the Developer portal is IaC'd from
   that file (values are fastlane `produce enable_services` flag names, so any
   Apple service fastlane supports can be declared). Enable-only: deleting a
   declaration does NOT disable the capability in the portal — do that
   manually. Every capability change needs a `pls register` re-run: profiles
   embed the capability list, and step 5 rotates them.
4. The App Group is associated with each App ID.
5. Every pre-existing App Store provisioning profile for those bundle ids is
   **deleted** (profiles never gain entitlements retroactively; the next CD run
   re-mints fresh ones via `fetch-signing-files --create` carrying the current
   entitlements).
6. The ASC app record exists for the main app id (store name = `app_name` +
   the landscape's `store_suffix`), and its numeric apple_id is written back
   into `lpsm.yaml` — review and commit that diff.

**Idempotency:** re-running is always safe. "Already exists" outcomes are
treated as success; the only repeated side effect is step 5's profile rotation,
which CD self-heals on its next run.

**Failure semantics (per landscape):**

- _Store name still held by an old app record_ → that landscape is **reported
  and skipped** (exit stays green for the others); rename the old app in ASC
  and re-run.
- _Identifier "not available"_ → it exists in another team or is inside
  Apple's ~48 h post-deletion reservation → fix there and re-run; the run
  **fails**.
- _Your Apple ID lacks portal access to the project team_ → the script
  **refuses** to register into a foreign team (override:
  `NEON_ALLOW_FOREIGN_TEAM=1`).
- _apple_id lookup returns nothing_ (records can lag minutes after creation) →
  warned, not failed; re-run later or fill `lpsm.yaml` by hand.

**Explicit non-goals:** Google Play Console apps and Logto redirect URIs (no
APIs exist — manual, see the table above); certificates and profiles
(CD's `fetch-signing-files --create` owns those); freeing store names held by
old app records.

**Env knobs:** `FASTLANE_USER` / `FASTLANE_TEAM_ID` / `FASTLANE_ITC_TEAM_ID`
skip the interactive prompts; `NEON_APP_NAME` overrides the store base name.

**Adding a widget/extension/watch target:** add the target in Xcode with its LPSM
bundle id, run `pls register` (App Manager Apple ID, one 2FA tap), commit. CI
discovers the target automatically; the doctor step fails any release where
registration was skipped, naming the missing piece.

Android needs no registration for any of this — widgets are plain code, and
app↔widget sharing is in-process storage under one signed app.
