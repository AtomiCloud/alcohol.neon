# alcohol.neon — Mobile Release Strategy (App Store + Play Store, 3 Landscapes)

> Scope: Flutter (iOS 17+/Android) app `alcohol.neon`, part of AtomiCloud's "alcohol" product. Three published channels mapped to AtomiCloud landscapes: **pichu** (dev), **pikachu** (stage), **raichu** (prod). CI = **Codemagic**. Apple Developer Program and Google Play Console already paid for.
>
> Status note: the foundation PR (#2, `feat: foundation`) scaffolds the Flutter iOS/Android project, `AppConfig`, the `Landscape` enum, and `--dart-define` config injection — assume it is merged to `main`. There is **no `codemagic.yaml`, no real signing config, and no per-flavor setup yet** (Android release currently signs with debug keys; iOS has no signing config). This document is written so the identity/signing/CI scheme is baked in before the first store upload rather than retrofitted.
>
> Pricing and Google Play policy figures verified June 2026 against official Apple, Google, Flutter, and Codemagic docs. Pricing and the Play "12 testers / 14 days" gate are date-sensitive — reconfirm at purchase/launch.

---

## 1. TL;DR

- **Identity:** three distinct app identities, one per landscape, so all three install side-by-side on one device. **Every** landscape — including prod (raichu) — gets a flavor suffix, so the base id is never shipped directly — Android `cloud.atomi.alcohol_neon.{pichu,pikachu,raichu}`, iOS `cloud.atomi.alcohol.neon.{pichu,pikachu,raichu}`.
- **Store channels:** only **raichu** gets public listings (App Store + Play production). **pichu** = TestFlight internal + Play internal track (no public listing). **pikachu** = TestFlight external + Play closed testing (no public listing).
- **Flutter mechanism:** three flavors named exactly `pichu`/`pikachu`/`raichu` (Android product flavors + iOS shared Xcode schemes), with per-landscape config injected via `--dart-define-from-file=config/<flavor>.json` alongside `--flavor`.
- **CI tool:** **Codemagic** — Flutter-first, managed macOS runners, automatic iOS signing via one App Store Connect API key, declarative store publishing. (Fastlane+GitHub Actions is the zero-lock-in fallback; EAS is ruled out — no Flutter support.)
- **Trigger model:** `push` to `main` → pichu; tag `v*-rc` → pikachu; tag `v*` (excluding `*-rc`) → raichu. Build numbers auto-incremented per channel by querying the store.
- **Cost:** Apple already-paid $99/yr covers all 3 (no documented per-app fee); Play already-paid $25 one-time covers all 3; realistic Codemagic spend ≈ **$100–165/mo** on Pay-As-You-Go (no free minutes on Team accounts).

---

## 2. App identity scheme

**Recommendation: one distinct identity per landscape (separate listings/records), NOT one app with tracks.**

iOS and Android namespace installed apps by bundle id / applicationId. Two builds sharing an id overwrite each other, so distinct ids are the **only** way to install dev+stage+prod simultaneously — valuable for a team testing auth (Logto) and payments (Airwallex) against different backends. Each distinct id is also its own App Store Connect record / Play Console listing, with independent review pipelines, crash data, and icons, and zero risk of shipping a dev build to the public listing. Cost: 3 app records, 3 provisioning setups, 3 CI workflows per platform — accepted here because the team explicitly wants three published channels.

Give **every** landscape — including raichu (prod) — its own flavor suffix, so the bare base id is never shipped and all three install side-by-side.

| Landscape       | Flavor name | Android applicationId              | iOS bundle id                      | Display name | Stores                              |
| --------------- | ----------- | ---------------------------------- | ---------------------------------- | ------------ | ----------------------------------- |
| pichu (dev)     | `pichu`     | `cloud.atomi.alcohol_neon.pichu`   | `cloud.atomi.alcohol.neon.pichu`   | `Neon Dev`   | TestFlight internal + Play internal |
| pikachu (stage) | `pikachu`   | `cloud.atomi.alcohol_neon.pikachu` | `cloud.atomi.alcohol.neon.pikachu` | `Neon Stage` | TestFlight external + Play closed   |
| raichu (prod)   | `raichu`    | `cloud.atomi.alcohol_neon.raichu`  | `cloud.atomi.alcohol.neon.raichu`  | `Neon`       | App Store + Play production         |

Notes:

- Flavor name = Android product flavor = iOS Xcode scheme name = `--flavor` value = `appFlavor` at runtime. Keep them identical (and lowercase — the Flutter CLI matches the iOS scheme name case-sensitively/lowercase) so they never drift. ([Flutter flavors](https://docs.flutter.dev/deployment/flavors), [iOS flavors](https://docs.flutter.dev/deployment/flavors-ios))
- An applicationId/bundle id **can never change after first publish** or the store treats it as a brand-new app. ([Android](https://developer.android.com/build/configure-app-module), [Apple](https://developer.apple.com/help/app-store-connect/create-an-app-record/create-and-submit-app-bundles/))
- Logto OIDC: the current shared scheme `cloud.atomi.alcohol.neon://callback` would be **ambiguous** with three apps installed (iOS routes a custom scheme to whichever app claims it). Make the scheme landscape-specific per bundle id (e.g. `cloud.atomi.alcohol.neon.pichu://callback`), and register a **separate Logto Native app + redirect URI per landscape**.

---

## 3. Store channel mapping

| Landscape           | App Store / TestFlight target                                                                             | Play Console track                                         | Who can install        | Public listing? |
| ------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ---------------------- | --------------- |
| **pichu (dev)**     | TestFlight **internal** group (≤100 ASC users, no Beta App Review, builds testable within minutes)        | **internal** testing (≤100 testers, fast)                  | Team only              | **No**          |
| **pikachu (stage)** | TestFlight **external** group(s) (≤10,000; first build of each version clears Beta App Review)            | **closed** testing (≤2,000 per email list, up to 50 lists) | Invited QA/UAT testers | **No**          |
| **raichu (prod)**   | Full **App Store review** + public listing (optionally keep an external TestFlight group for RC sign-off) | **production**                                             | Everyone               | **Yes**         |

**Dev and stage must NOT be public store listings.** Only raichu goes through full App Store review and Play production. This is the industry-standard tier model and eliminates accidental dev→public releases.

Sources: [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/), [Play tracks](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en).

---

## 4. Flutter flavor + dart-define implementation

The foundation already injects per-landscape config via `--dart-define` (`NEON_LANDSCAPE` etc.) into `AppConfig`. Add **native flavors** on top so each landscape gets its own bundle id / icon / name, then drive the existing dart-defines per flavor.

### 4.1 Android — `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        applicationId = "cloud.atomi.alcohol_neon"   // base id; every flavor adds a suffix
        // versionCode / versionName driven by --build-number / --build-name from CI
    }
    flavorDimensions += "landscape"
    productFlavors {
        create("pichu")   { dimension = "landscape"; applicationIdSuffix = ".pichu";
                            resValue("string", "app_name", "Neon Dev") }
        create("pikachu") { dimension = "landscape"; applicationIdSuffix = ".pikachu";
                            resValue("string", "app_name", "Neon Stage") }
        create("raichu")  { dimension = "landscape"; applicationIdSuffix = ".raichu";
                            resValue("string", "app_name", "Neon") }
    }
}
```

`AndroidManifest.xml`: `android:label="@string/app_name"`. This yields 6 variants (`pichuRelease`, … `raichuRelease`). The `.aab` lands at `build/app/outputs/bundle/<flavor>Release/app-<flavor>-release.aab`. ([Build variants](https://developer.android.com/build/build-variants), [Flutter flavors](https://docs.flutter.dev/deployment/flavors))

### 4.2 iOS — Xcode schemes + xcconfig

- Create three **shared** schemes `pichu`/`pikachu`/`raichu` (Product ▸ Scheme ▸ New Scheme, target `Runner`, mark Shared in Manage Schemes).
- Duplicate `Debug`/`Profile`/`Release` into per-flavor configs: `Debug-pichu`, `Profile-pichu`, `Release-pichu` (and pikachu/raichu). Map each scheme's Run→`Debug-<flavor>`, Profile→`Profile-<flavor>`, Archive→`Release-<flavor>`.
- Set `PRODUCT_BUNDLE_IDENTIFIER` per config from base `cloud.atomi.alcohol.neon` (pichu→`.pichu`, pikachu→`.pikachu`, raichu→`.raichu`). Set `CFBundleDisplayName` to a user-defined `$(APP_DISPLAY_NAME)` var per config.
- **Register every new config in `ios/Podfile`'s project map** (`'Debug-pichu' => :debug, 'Release-pichu' => :release, …`). The official docs require this so CocoaPods knows each config's build mode (note: docs require the registration but do **not** state `pod install` hard-fails — treat as a correctness requirement). ([iOS flavors](https://docs.flutter.dev/deployment/flavors-ios))
- xcconfig trap: `//` is treated as a comment **even inside quotes** — never put a raw `https://…` URL in an xcconfig-injected value; prefix the scheme in Dart code.

### 4.3 Per-landscape config via `--dart-define-from-file`

The foundation currently passes defines one-by-one. Consolidate them into `config/pichu.json`, `config/pikachu.json`, `config/raichu.json`, each a flat string map matching the existing `NEON_*` keys read by `AppConfig`:

```json
{
  "NEON_LANDSCAPE": "pichu",
  "NEON_LOGTO_ENDPOINT": "https://logto.pichu.example",
  "NEON_LOGTO_APP_ID": "<pichu-logto-native-app-id>",
  "NEON_ZINC_URL": "https://api.zinc.alcohol.pichu.cluster.atomi.cloud",
  "NEON_ZINC_RESOURCE": "https://api.zinc.alcohol.pichu",
  "NEON_AIRWALLEX_ENV": "demo"
}
```

Build with the matching pair (flavor selects native identity/icon; dart-define-from-file injects runtime config):

```bash
flutter build appbundle --release --flavor pichu --dart-define-from-file=config/pichu.json
```

- `--dart-define-from-file` accepts a flat JSON/.env file; values are read in Dart as **compile-time const** via `String.fromEnvironment(...)` — exactly what `AppConfig._resolve()` already does. Requires Flutter 3.7+. ([dart-define-from-file](https://codewithandrea.com/tips/dart-define-from-file-env-json/), [dart.dev](https://dart.dev/libraries/core/environment-declarations))
- At startup, **assert `appFlavor == const String.fromEnvironment('NEON_LANDSCAPE')`** and throw if any required key is empty — this catches the classic "built `--flavor pikachu` but passed pichu JSON" mistake before a mis-pointed binary ships. (`appFlavor` from `package:flutter/services.dart` returns the flavor name, or `null` if `--flavor` omitted; it landed ~3.16–3.19, so use Flutter ≥ 3.19.) ([appFlavor](https://api.flutter.dev/flutter/services/appFlavor-constant.html))
- Sensitive defines (e.g. `NEON_LOGTO_APP_ID`) should live in Codemagic encrypted env groups and be passed as `--dart-define` rather than committed in the JSON.

### 4.4 Per-flavor icons

`flutter_launcher_icons-pichu.yaml` / `-pikachu.yaml` / `-raichu.yaml` (DEV/STG badges on dev/stage; the foundation already ships `assets/brand/logo.png`). Generate: `dart run flutter_launcher_icons -f flutter_launcher_icons*`. On iOS also set `ASSETCATALOG_COMPILER_APPICON_NAME` per build config to the generated `AppIcon-<flavor>` set. ([flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)) Consider `flutter_flavorizr` to reduce manual wiring.

---

## 5. Signing setup

### 5.1 iOS — App Store Connect API key + automatic signing

**One-time in Apple consoles:**

1. Register all three App IDs in the Apple Developer portal: `cloud.atomi.alcohol.neon.pichu`, `.pikachu`, and `.raichu`.
2. Create three App Store Connect **app records**, one per bundle id (a bundle id can't be changed after the first upload).
3. **Users and Access ▸ Integrations ▸ App Store Connect API** → create one key with **App Manager** access. Capture **Issuer ID** (account-level), **Key ID** (per key), and download the **`.p8` (downloadable only once)**.
4. Register that key in **Codemagic Team Settings ▸ Integrations** as an Apple Developer Portal integration.

With the integration, Codemagic **auto-creates/fetches the cert + provisioning profile per bundle id at build time** — the only signing script needed is `xcode-project use-profiles`, and the same key drives both signing **and** publishing across all 3 workflows. Store the `.p8` base64-encoded if using env vars to avoid newline issues. ([Codemagic iOS signing](https://docs.codemagic.io/yaml-code-signing/signing-ios/), [ASC API key](https://docs.fastlane.tools/app-store-connect-api/)) The Apple Developer **Enterprise** Program is **not** needed for this TestFlight+App Store model.

### 5.2 Android — keystore + Play App Signing + service account

**Generate a real upload keystore now** (replaces the current debug-key placeholder in `android/app/build.gradle.kts`):

```bash
keytool -genkeypair -v -keystore atomi-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias atomi-upload
```

- A **single shared upload keystore across all three flavors is fine** (each enrolls separately in Play App Signing). Upload it under Codemagic **Team settings ▸ Code signing identities ▸ Android keystores**. Codemagic exports `CM_KEYSTORE_PATH`/`CM_KEYSTORE_PASSWORD`/`CM_KEY_ALIAS`/`CM_KEY_PASSWORD`. **Codemagic-uploaded keystores cannot be downloaded back — keep a secure offline copy.**
- **Enroll in Play App Signing**: you sign the AAB with the upload key; Google generates and holds the permanent RSA-4096 app signing key. If the upload key is lost it can be reset without affecting users. ([Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en))
- Replace the debug-signing release config:

```kotlin
signingConfigs {
    create("release") {
        if (System.getenv("CI") != null) {
            storeFile = file(System.getenv("CM_KEYSTORE_PATH"))
            storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("CM_KEY_ALIAS")
            keyPassword = System.getenv("CM_KEY_PASSWORD")
        }
    }
}
buildTypes { getByName("release") { signingConfig = signingConfigs.getByName("release") } }
```

**Service account for CI publishing (one-time in Google Cloud + Play Console):**

1. Google Cloud Console (same Google account as Play Console) → enable the **Google Play Android Developer API** → create a service account → generate a **JSON key**.
2. Play Console ▸ **Users and permissions** → invite the service-account email → grant **Release Manager/Admin on all three apps**. One service account publishes all three listings. (Can take up to ~24h to activate.)
3. Store the JSON as a Codemagic secret env var (e.g. `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS`). ([Codemagic Google Play](https://docs.codemagic.io/yaml-publishing/google-play/), [Android publisher getting started](https://developers.google.com/android-publisher/getting_started))

**Mandatory first manual upload:** the very first `.aab` for **each** of the three applicationIds must be uploaded to Play Console manually before automated publishing works. ([Codemagic](https://docs.codemagic.io/yaml-publishing/google-play/))

---

## 6. Codemagic CI design

Single `codemagic.yaml` with a `definitions:` block of YAML anchors for shared config, and **6 workflows** (iOS/Android split per landscape) so an iOS signing issue never blocks an Android publish. Secrets live in encrypted env groups (`neon_pichu`/`neon_pikachu`/`neon_raichu` + shared `app_store_credentials`, `google_play_credentials`, `android_keystore`); nothing sensitive is committed.

```yaml
definitions:
  env_versions: &env_versions
    flutter: stable
    xcode: latest
    cocoapods: default
  ios_publish_pichu: &ios_publish_pichu
    app_store_connect:
      auth: integration
      submit_to_testflight: true
      beta_groups: [pichu-internal]
      submit_to_app_store: false

workflows:
  # ---------- iOS ----------
  neon-pichu-ios:
    name: iOS pichu (dev)
    instance_type: mac_mini_m2
    max_build_duration: 60
    integrations:
      app_store_connect: AtomiNeonKey # Team integration name
    environment:
      <<: *env_versions
      ios_signing:
        distribution_type: app_store
        bundle_identifier: cloud.atomi.alcohol.neon.pichu
      groups: [neon_pichu, app_store_credentials]
      vars:
        APP_STORE_APPLE_ID: <pichu-asc-apple-id>
    triggering:
      events: [push]
      branch_patterns:
        - pattern: main
          include: true
          source: true
      cancel_previous_builds: true
    scripts:
      - flutter pub get
      - find . -name "Podfile" -execdir pod install \;
      - xcode-project use-profiles
      - >
        flutter build ipa --release
        --flavor pichu --dart-define-from-file=config/pichu.json
        --build-number=$(($(app-store-connect get-latest-build-number "$APP_STORE_APPLE_ID") + 1))
        --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      <<: *ios_publish_pichu

  neon-pikachu-ios:
    name: iOS pikachu (stage)
    # same shape; bundle_identifier .pikachu, --flavor pikachu, config/pikachu.json,
    # groups: [neon_pikachu, app_store_credentials]
    triggering:
      events: [tag]
      tag_patterns:
        - pattern: 'v*-rc'
          include: true
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        beta_groups: [pikachu-external]
        submit_to_app_store: false

  neon-raichu-ios:
    name: iOS raichu (prod)
    # bundle_identifier cloud.atomi.alcohol.neon.raichu, --flavor raichu, config/raichu.json
    triggering:
      events: [tag]
      tag_patterns:
        - pattern: 'v*'
          include: true
        - pattern: 'v*-rc' # exclude RC tags from prod
          include: false
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        submit_to_app_store: true
        release_type: MANUAL # human approves the public release
        cancel_previous_submissions: true

  # ---------- Android ----------
  neon-pichu-android:
    name: Android pichu (dev)
    instance_type: linux_x2 # Android-only → cheaper than macOS
    environment:
      <<: *env_versions
      android_signing: [neon_upload_keystore]
      groups: [neon_pichu, google_play_credentials]
      vars:
        PACKAGE_NAME: cloud.atomi.alcohol_neon.pichu
        GOOGLE_PLAY_TRACK: internal
    triggering:
      events: [push]
      branch_patterns:
        - pattern: main
          include: true
          source: true
    scripts:
      - flutter pub get
      - >
        BUILD_NUMBER=$(($(google-play get-latest-build-number
        --package-name "$PACKAGE_NAME" --tracks="$GOOGLE_PLAY_TRACK") + 1));
        flutter build appbundle --release
        --flavor pichu --dart-define-from-file=config/pichu.json
        --build-number=$BUILD_NUMBER
    artifacts:
      - build/**/outputs/bundle/**/*.aab
    publishing:
      google_play:
        credentials: $GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
        track: internal

  neon-pikachu-android:
    # flavor pikachu, PACKAGE_NAME cloud.atomi.alcohol_neon.pikachu,
    # GOOGLE_PLAY_TRACK = <closed-track-name> (or 'beta'), tag 'v*-rc'
    ...

  neon-raichu-android:
    # flavor raichu, PACKAGE_NAME cloud.atomi.alcohol_neon.raichu, track: production,
    # tag 'v*' excluding 'v*-rc'
    publishing:
      google_play:
        credentials: $GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
        track: production
        rollout_fraction: 0.25 # staged rollout; omit for 100%
```

Key behaviors (all from official Codemagic docs):

- **iOS signing**: the integration + `ios_signing` auto-resolves the correct provisioning profile per bundle id; only `xcode-project use-profiles` is needed. ([signing-ios](https://docs.codemagic.io/yaml-code-signing/signing-ios/))
- **iOS publishing** is async post-processing: `submit_to_testflight` (default false), `beta_groups`, `submit_to_app_store`, `release_type` (MANUAL/AFTER_APPROVAL/SCHEDULED). pichu can alternatively use `XCODE_PROJECT_CUSTOM_EXPORT_OPTIONS={"testFlightInternalTestingOnly": true}` to push to internal testers and skip review. ([app-store-connect](https://docs.codemagic.io/yaml-publishing/app-store-connect/))
- **Android publishing**: `google_play.track` accepts `internal|alpha|beta|production|<closed-track-name>`. `rollout_fraction` not usable with `submit_as_draft`. Leave `changes_not_sent_for_review` **unset** initially; add `true` only if Google returns "Changes cannot be sent for review automatically." ([google-play](https://docs.codemagic.io/yaml-publishing/google-play/), [common errors](https://docs.codemagic.io/troubleshooting/common-google-play-errors/))
- **Triggers**: tag_patterns and branch_patterns are independent; watched-branch settings don't affect tag builds. Patterns apply top-down, later wins — hence raichu includes `v*` then excludes `v*-rc`. ([starting-builds](https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/))

---

## 7. Trigger & versioning model

| Git ref                                   | Workflow(s)                  | Landscape       | iOS channel         | Play track          |
| ----------------------------------------- | ---------------------------- | --------------- | ------------------- | ------------------- |
| `push` → `main`                           | `neon-pichu-{ios,android}`   | pichu (dev)     | TestFlight internal | internal            |
| tag `v*-rc` (e.g. `v1.4.0-rc1`)           | `neon-pikachu-{ios,android}` | pikachu (stage) | TestFlight external | closed              |
| tag `v*` excluding `*-rc` (e.g. `v1.4.0`) | `neon-raichu-{ios,android}`  | raichu (prod)   | App Store (MANUAL)  | production (staged) |

- Keep `cancel_previous_builds: true`; manual UI/API builds remain available for ad-hoc releases.

**Versioning scheme:**

- `--build-number` sets Android `versionCode` and iOS `CFBundleVersion`; `--build-name` sets `versionName`/`CFBundleShortVersionString`.
- **Build number per channel**: query the relevant store/track and `+1` so numbers monotonically increase **within each channel** — iOS `app-store-connect get-latest-build-number $APP_STORE_APPLE_ID`; Android `google-play get-latest-build-number --tracks=$GOOGLE_PLAY_TRACK`. Each Play listing has its own versionCode space; never reuse a versionCode within one applicationId. ([build-versioning](https://docs.codemagic.io/knowledge-codemagic/build-versioning/))
- **versionName**: for pikachu/raichu, derive from the git tag (strip leading `v`, drop `-rc` suffix → e.g. `1.4.0`). For pichu, use a fixed dev label (e.g. `0.0.0-dev`) since it builds on every `main` push.

---

## 8. Costs

| Item                           | Cost                                                                                                          | Covers all 3 channels?                                                                                                                                                                                          |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apple Developer Program        | **$99/yr** (already paid)                                                                                     | Yes — no **documented** per-app/per-bundle-id fee. (The free "Personal Team" 10-App-ID cap does **not** apply to the paid Program.) ([Apple memberships](https://developer.apple.com/programs/whats-included/)) |
| Google Play Console            | **$25 one-time** (already paid)                                                                               | Yes — one-time, no annual or per-app fee. ([Play fee](https://support.google.com/android-developer-console/answer/16604405?hl=en))                                                                              |
| Codemagic free tier            | 500 macOS-M2 min/mo                                                                                           | **Personal accounts only — NOT available on Team accounts.** ([pricing](https://docs.codemagic.io/billing/pricing/))                                                                                            |
| Codemagic Pay-As-You-Go        | macOS M2 **$0.095/min**, M4 $0.114/min, Linux/Windows **$0.045/min**; +$49/mo per extra concurrency (up to 3) | —                                                                                                                                                                                                               |
| Codemagic flat (unlimited min) | from **$3,990/yr** (M2, 3 concurrencies)                                                                      | —                                                                                                                                                                                                               |

> Pricing correction: a "$299/mo unlimited" plan circulates on third-party review sites but is **stale** — the current unlimited tier is billed annually from $3,990/yr. Do **not** plan around $299/mo.

**Realistic monthly Codemagic estimate (Team account, PAYG):** an iOS+Android Flutter build ≈ 10–20 macOS min. ~15 min/build × ~40 builds/mo × 2 platforms ≈ 1,200 min ≈ **~$114/mo** at $0.095/min, **plus ~$49/mo** for a 2nd concurrency so 6 workflows don't serialize → **~$115–165/mo**. Run Android-only workflows on Linux ($0.045/min) to cut cost. If you cross ~3,000 macOS min/mo, the $3,990/yr unlimited plan becomes cheaper.

---

## 9. Setup checklist (current state → 3 channels live)

1. **Merge foundation** (PR #2) so `ios/`, `android/`, `AppConfig`, and the `Landscape` enum are on `main`.
2. **Flavors**: add Android product flavors (`pichu`/`pikachu`/`raichu` + suffixes), iOS shared schemes + per-flavor build configs, and register configs in the `ios/Podfile` project map.
3. **Config**: add `config/{pichu,pikachu,raichu}.json` with all `NEON_*` keys (`NEON_LANDSCAPE` == flavor name); add the startup assert `appFlavor == NEON_LANDSCAPE` in `AppConfig`.
4. **Icons + names**: per-flavor launcher icons (DEV/STG badges) and display names.
5. **Logto**: create 3 Native apps + landscape-specific redirect URIs (`...neon.pichu://callback`, etc.); set Airwallex `demo` for pichu, production for pikachu/raichu.
6. **Apple**: register 3 App IDs; create 3 ASC app records; create 1 ASC API key (App Manager); register it as a Codemagic Apple Developer Portal integration.
7. **Android signing**: generate the upload keystore; upload to Codemagic code-signing identities; enroll each app in Play App Signing; replace the debug-key release signingConfig.
8. **Play**: create 3 Play Console apps; create 1 Google Cloud service account (enable Play Android Developer API); grant it Release Manager on all 3; store JSON as a Codemagic secret.
9. **First manual upload**: upload one signed `.aab` per applicationId to Play Console (and one build per iOS app record to TestFlight) to bootstrap automated publishing.
10. **Play production gate** (if personal account): run a ≥12-tester / 14-continuous-day closed test for raichu **before** production is unlocked (see §10).
11. **Codemagic**: add `codemagic.yaml` with the 6 workflows + anchors + env groups; configure triggers (`main`/`v*-rc`/`v*`).
12. **Dry run**: push to `main` → verify pichu reaches TestFlight internal + Play internal. Tag `v*-rc` → verify pikachu. Tag `v*` → verify raichu reaches App Store review + Play production.
13. **Billing**: switch Codemagic to PAYG (no free minutes on Team), add a 2nd concurrency, set tight `max_build_duration`.

---

## 10. Risks & gotchas

- **Apple Beta App Review (pikachu):** the **first build of each version** sent to an external TestFlight group must clear Beta App Review (budget ~up to 48h; later builds of the same version usually skip full review). Internal (pichu) has **no** review. Complete Info.plist permission usage strings + data-collection declarations to avoid holds. ([external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/))
- **Google Play new-personal-account gate:** personal accounts created **after 13 Nov 2023** must run a closed test with **≥12 testers opted-in continuously for 14 days** before production is unlocked. **Organization accounts are exempt** (verify your account type in Play Console). **Recommendation: register/transfer the Play account as an AtomiCloud organization to skip this gate**, or start recruiting testers ~3 weeks before raichu launch. ([Play closed-testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en))
- **Signing-key loss is catastrophic/irreversible:** rely on Play App Signing (Google holds the app key; upload key is recoverable) and keep an **offline backup** of the upload keystore and the iOS `.p8` + distribution material — Codemagic-uploaded keystores can't be downloaded back.
- **Logto/Airwallex per-landscape config:** because dart-define values are baked at **build time**, a config change requires a full store rebuild (Shorebird OTA can't change them). Each landscape needs its own Logto Native app + landscape-specific redirect scheme; mismatched scheme/bundle id breaks the OIDC callback.
- **iOS scheme/flavor naming:** if the Xcode scheme name doesn't **exactly** (lowercase) match `--flavor`, the build fails or silently uses the base config. Every duplicated build config must be in the `Podfile` project map.
- **Build-number collisions:** always derive `--build-number` from the target store/track, never a global counter, or TestFlight/Play will reject duplicate `CFBundleVersion`/`versionCode`.
- **`flutter_launcher_icons` on iOS** also needs `ASSETCATALOG_COMPILER_APPICON_NAME` set per config, or all flavors share one icon.
- **Firebase (if added later):** per-flavor `google-services.json` (under `android/app/src/<flavor>/`) and `GoogleService-Info.plist` per iOS config, each registered to that flavor's exact id.
- **Codemagic Team free-tier trap:** the 500 free minutes vanish on a Team account — don't budget around them.

---

## 11. Open decisions for the user

1. **Play account type — organization vs personal?** _Recommendation:_ use/transfer to an **AtomiCloud organization** account to skip the 12-tester/14-day production gate entirely. If it must stay personal-post-Nov-2023, schedule the closed test before raichu launch.
2. **pikachu Play track — closed vs open testing?** _Recommendation:_ **closed** testing (invited QA/UAT), since stage should not be publicly discoverable.
3. **One shared upload keystore vs one per applicationId?** _Recommendation:_ **one shared** keystore — simpler in CI; each app still enrolls separately in Play App Signing.
4. **raichu rollout — staged vs 100%?** _Recommendation:_ **staged** (`rollout_fraction: 0.1–0.25`) for the first few prod releases, then widen.
5. **Codemagic workflow shape — 3 combined vs 6 split?** _Recommendation:_ **6 split** (iOS/Android per landscape) so a signing failure on one platform can't block the other's release.
6. **Are any `NEON_*` defines sensitive?** _Recommendation:_ keep `NEON_LOGTO_APP_ID` (and anything secret-ish) in **Codemagic encrypted env groups**, not committed JSON; commit only non-secret defaults.
7. **iOS release approval — MANUAL vs AFTER_APPROVAL?** _Recommendation:_ **MANUAL** (`release_type: MANUAL`) so a human gates the public App Store release after review passes.
8. **Shorebird OTA on raichu?** _Recommendation:_ treat as an **optional later add-on** for Dart-only hotfixes; it cannot change baked dart-define config, native code, assets, or the engine version.
9. **CI lock-in tolerance?** _Recommendation:_ **Codemagic** for lowest setup; keep Fastlane + GitHub Actions documented as the portable fallback. EAS is ruled out (no Flutter support).
