# alcohol.neon — GitHub Actions Release Runbook

The mobile release pipeline runs entirely in **GitHub Actions** (`.github/workflows/cd.yaml`),
replacing Codemagic. It builds, signs, and publishes all 3 flavors on every `v*.*.*` tag.

## Flow

```
merge feat:/fix: to main
  → CI (ci.yaml) green
  → Release (release.yaml) runs semantic-release → cuts tag vX.Y.Z
  → tag push triggers CD (cd.yaml)
       ├─ build-ios     donor IPA (signed raichu)      ┐ staged as run
       ├─ build-android donor AAB (debug-signed raichu)┘ artifacts, in parallel
       ├─ publish-ios     ×3: download → stamp → TestFlight        (parallel)
       └─ publish-android ×3: download → stamp → Play internal track (parallel)
```

The donor is ONE raichu release build per platform — the compiled payload is
landscape-agnostic (bundle-id-as-marker, verified byte-for-byte 2026-07-07);
only packaging differs. Each landscape then gets a small publish job that
downloads the donor, re-badges it (identity, versionCode from the store query,
version name from the tag), and uploads. Store uploads run in parallel, and a
failed upload re-runs in minutes **without rebuilding** — the donor stays in
the run's artifacts (90 days).

- **iOS** (`nscloud-macos-sequoia-arm64-6x14` runners; the publish jobs are macOS too —
  codesign). The donor archive compiles every `AppIcon-*` set into `Assets.car`
  (`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`, raichuRelease.xcconfig), and
  `scripts/ci/stamp-ios.sh` re-badges per landscape: PlistBuddy patches to app + widget
  Info.plists (bundle ids, display name, icon pointer, App Group, CFBundleVersion,
  CFBundleShortVersionString), the landscape's provisioning profiles embedded,
  signing entitlements derived from the donor's own signature (identity bits patched;
  app-authored values like NFC formats and associated domains carry over — profile
  entitlements would ship Apple's wildcards), then `codesign` re-signs appex→app and
  a doctor asserts every field plus the signed App Group before upload. Only raichu's
  profiles exist at build time, so `use-profiles`/export see exactly the single-flavor
  setup; each publish job fetches its own landscape's profiles.
- **Android** (Linux runners; the donor build needs no secrets — it debug-signs and every
  publish job re-signs with the upload key). `scripts/ci/stamp-android.sh` re-badges per
  landscape: it patches the protobuf `AndroidManifest.xml` (applicationId — which is also
  the Logto scheme and the provider-authority prefix — plus label, versionCode and
  versionName) and the resource table's `package_name` via a `protoc` text-format
  round-trip, swaps the launcher-icon PNGs (release PNG crunch is disabled so repo bytes
  match AAB bytes 1:1), re-signs with `jarsigner`, and runs a doctor (`bundletool
validate` + dump assertions) before anything is uploaded. Never edit inside the
  resource table's `source_pool` blob — it's a length-prefixed string pool and any width
  change corrupts it.
- A small `setup` job resolves the publish matrix: **all 3 landscapes on a tag**, or
  **just one** on a manual run (the donors are always built).
- **raichu (prod)** uploads to TestFlight / Play **internal** automatically; promotion to the public
  App Store / Play production is **manual** (App Store Connect "Submit"; Play Console "promote").

## Flavor → identity map

| Flavor  | Bundle id / package (iOS = Android)    | Apple ID                                   |
| ------- | -------------------------------------- | ------------------------------------------ |
| pichu   | `cloud.atomi.pichu.alcohol.neon.app`   | `6777280038` — old record, new one pending |
| pikachu | `cloud.atomi.pikachu.alcohol.neon.app` | `6777280047` — old record, new one pending |
| raichu  | `cloud.atomi.raichu.alcohol.neon.app`  | `6777280099` — old record, new one pending |

All identifiers derive from the LPSM grammar (the widget extension is `<bundle id>.widget`) —
see [docs/developer/standard/bundle-id.md](developer/standard/bundle-id.md). The numeric Apple
IDs above belong to the **old** App Store Connect app records; the new records don't exist yet,
so the `apple_id` fields in `scripts/ci/cd-matrix.sh` are empty until they're created — see
[docs/migration-lpsm-ids.md](migration-lpsm-ids.md).

## Secrets (org-level GitHub Actions secrets, synced from Infisical `raichu`)

| Secret                             | Used by | Notes                                                                                             |
| ---------------------------------- | ------- | ------------------------------------------------------------------------------------------------- |
| `APP_STORE_CONNECT_ISSUER_ID`      | iOS     | ASC API key (read by `codemagic-cli-tools` by name)                                               |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | iOS     | ASC API key                                                                                       |
| `APP_STORE_CONNECT_PRIVATE_KEY`    | iOS     | ASC API key `.p8` (multiline)                                                                     |
| `CERTIFICATE_PRIVATE_KEY`          | iOS     | Apple Distribution cert private key — `fetch-signing-files` **reuses** the matching existing cert |
| `ANDROID_KEYSTORE_BASE64`          | Android | base64 of `atomi-upload.jks`                                                                      |
| `ANDROID_KEYSTORE_PASSWORD`        | Android | store password                                                                                    |
| `ANDROID_KEY_ALIAS`                | Android | `atomi-upload`                                                                                    |
| `ANDROID_KEY_PASSWORD`             | Android | = store password                                                                                  |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Android | Play publishing service account (JSON) — setup: [docs/store-credentials.md](store-credentials.md) |

To regenerate the secret bundle, see the validated source material in Infisical `raichu` + the
local `signingkey` (cert key) and `atomi-upload.jks` (keystore). All three are gitignored; **never
commit them**.

## How signing works (nix-cached toolchain)

Following the ci-cd-workflows convention, `cd.yaml` only resolves the flavor matrix and fans out
to the per-platform reusable workflows (`⚡reusable-build-{ios,android}.yaml` for the donors,
`⚡reusable-publish-{ios,android}.yaml` per landscape, called with `secrets: inherit`); the
imperative build/sign logic lives in `scripts/ci/` (`cd-{matrix,ios,android}.sh`,
`publish-{ios,android}.sh`, `stamp-{ios,android}.sh`, `lib-ios.sh`), run inside a per-platform
nix dev shell so flutter, Android SDK, JDK, CocoaPods, GNU rsync, and codemagic-cli-tools are
all cached (no per-run `brew`/`apt`/flutter-action downloads). Caching differs per platform:

- **Android (Linux):** `AtomiCloud/actions.setup-nix` restores the **shared nix store cache**
  (`nscloud-cache-tag-atomi-nix-store-cache`) — warm runs start with `/nix` already populated.
- **iOS (macOS):** the Namespace `/nix` cache path can't work on macOS (the cache action mounts via
  symlink and the sealed APFS root forbids creating `/nix`), so `setup-nix@v3` mounts a Namespace
  cache volume at `/tmp/nix-cache` (tag `atomi-nix-darwin-cache`) and uses it as a **local
  `file://` binary cache**: nix is installed fresh each run (DeterminateSystems installer), but
  the dev-shell closure substitutes from NVMe, and a post hook pushes the realized devShell
  closures back at end of job (on success). `~/.pub-cache` / `~/.cocoapods` ride a cache volume
  too. The volume only commits when the job succeeds, and idle volumes expire after ~14 days, so
  the first run after a quiet spell is cold again.

The shells are defined in `nix/shells.nix`:

- `.#cd-ios` — flutter + CocoaPods + GNU rsync + codemagic-cli-tools.
- `.#cd-android` — flutter + Android SDK + JDK + codemagic-cli-tools + protoc + bundletool,
  with `ANDROID_SDK_ROOT`/`ANDROID_HOME`/`JAVA_HOME`.

`codemagic-cli-tools` comes from the AtomiCloud nix registry (v3), so there is no per-run
pipx install step.

- **iOS** (`nix develop .#cd-ios -c ./scripts/ci/cd-ios.sh`)**:** nix exports a C/C++ stdenv that
  hijacks `xcodebuild`, so the actual `flutter build ipa` is run through `scripts/flutter-ios.sh`,
  which strips the nix toolchain vars and points `DEVELOPER_DIR` at real Xcode. GNU rsync comes from
  nix (macOS openrsync ignores `--chmod` → read-only framework → lipo fails). Signing mirrors the old
  Codemagic script, extended for embedded extensions: `keychain initialize` →
  `app-store-connect fetch-signing-files … --create` looped over **every** signing target
  (the app plus each extension, e.g. the widget — discovered from the Xcode project by
  `scripts/ci/ios-signing-targets.sh`) → `keychain add-certificates` →
  `xcode-project use-profiles --export-options-plist` → a doctor step
  (`scripts/ci/doctor-ios.sh`) that decodes each fetched profile and fails fast, naming the
  missing piece, if a profile lacks the App Group entitlement (i.e. `pls register` was skipped
  for a target).
- **Android** (`nix develop .#cd-android -c ./scripts/ci/cd-android.sh`)**:** flutter + Android SDK +
  JDK17 from nix; `codemagic-cli-tools` provides `google-play get-latest-build-number` for the
  versionCode query. The keystore is decoded to `android/app/upload-keystore.jks` and a
  `android/key.properties` is written — this hits the **existing** `key.properties` path in
  `android/app/build.gradle.kts` (no gradle change). The script also writes
  `~/.gradle/gradle.properties` with `kotlin.compiler.execution.strategy=in-process` and a
  right-sized `org.gradle.jvmargs` (-Xmx4g) — GRADLE_USER_HOME is the only properties scope that
  reaches the flutter_tools **included build** (where a KGP 2.0.x daemon-startup race, KT-69929,
  was intermittently killing `:<engine-rev>:compileKotlin` on the 8 GB runner), and it overrides
  the project's dev-machine `-Xmx8G` in CI only.

## Versioning

- **Version name** = the tag (`v1.2.3` → `1.2.3`). Omitted on manual runs (pubspec version used).
- **iOS build number** = `max(app-store-connect get-latest-build-number <apple_id> + 1,
github.run_number)`. The `get-latest` figure lags while a freshly uploaded build is still
  processing on Apple's side, so the monotonic CI run number guards against colliding with an
  in-flight build on back-to-back runs. While a landscape's `apple_id` in
  `scripts/ci/cd-matrix.sh` is empty (new ASC records pending —
  [docs/migration-lpsm-ids.md](migration-lpsm-ids.md)), the store query is skipped and the CI
  run number alone is used.
- **Android versionCode** = `google-play get-latest-build-number --package-name <pkg>` + 1 — the
  highest existing build number across **all** Play tracks, incremented. This mirrors the iOS
  scheme and coordinates with releases from the prior (Codemagic) pipeline; a bare counter (e.g.
  `github.run_number`) can land at or below an existing release, and Play then rejects the rollout
  with _"does not allow any existing users to upgrade to the newly added APKs"_ (`apkNoUpgradePaths`).

## Running it

- **Automatic:** merge a `feat:`/`fix:` to `main`; semantic-release tags it and CD fires.
- **Manual smoke test:** Actions → **CD** → **Run workflow** → pick a `flavor`. Builds and publishes
  that one channel without cutting a release. Use this to validate signing on first setup.

## First-run / gotchas

- **iOS cert cap (~2):** `--create` reuses the cert matching `CERTIFICATE_PRIVATE_KEY`, so no new cert
  should be minted. If the log shows a _new_ cert being created, revoke a stale one in the Apple portal.
- **App Groups have no API:** `fetch-signing-files --create` self-heals bundle ids and profiles,
  but App Group creation and group⇄App-ID association need `pls register`
  (`scripts/register-apple.sh`; App Manager Apple ID, one 2FA tap). If it was skipped, the doctor
  step fails the build naming the missing piece — see
  [docs/developer/standard/bundle-id.md](developer/standard/bundle-id.md).
- **Play first upload:** the very first `.aab` for each applicationId must be uploaded **manually**
  once in Play Console before the API will accept automated uploads.
- **macOS toolchain:** if an iOS step fails on Xcode path / pods / profiles, iterate via manual
  `workflow_dispatch` before relying on a real tag.
