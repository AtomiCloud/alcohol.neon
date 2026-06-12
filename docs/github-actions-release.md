# alcohol.neon — GitHub Actions Release Runbook

The mobile release pipeline runs entirely in **GitHub Actions** (`.github/workflows/cd.yaml`),
replacing Codemagic. It builds, signs, and publishes all 3 flavors on every `v*.*.*` tag.

## Flow

```
merge feat:/fix: to main
  → CI (ci.yaml) green
  → Release (release.yaml) runs semantic-release → cuts tag vX.Y.Z
  → tag push triggers CD (cd.yaml)
       ├─ ios job     (3 flavors) → build signed IPA → TestFlight
       └─ android job (3 flavors) → build signed AAB → Play internal track
```

- **iOS** runs on a Namespace macOS runner (`nscloud-macos-sequoia-arm64-6x14`, Xcode preinstalled).
- **Android** runs on the standard Namespace Linux runner.
- A small `setup` job resolves the build matrix: **all 3 flavors on a tag**, or **just one** on a
  manual run.
- **raichu (prod)** uploads to TestFlight / Play **internal** automatically; promotion to the public
  App Store / Play production is **manual** (App Store Connect "Submit"; Play Console "promote").

## Flavor → identity map

| Flavor  | iOS bundle id                      | Apple ID     | Android package                    |
| ------- | ---------------------------------- | ------------ | ---------------------------------- |
| pichu   | `cloud.atomi.alcohol.neon.pichu`   | `6777280038` | `cloud.atomi.alcohol_neon.pichu`   |
| pikachu | `cloud.atomi.alcohol.neon.pikachu` | `6777280047` | `cloud.atomi.alcohol_neon.pikachu` |
| raichu  | `cloud.atomi.alcohol.neon.raichu`  | `6777280099` | `cloud.atomi.alcohol_neon.raichu`  |

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
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Android | Play publishing service account (JSON)                                                            |

To regenerate the secret bundle, see the validated source material in Infisical `raichu` + the
local `signingkey` (cert key) and `atomi-upload.jks` (keystore). All three are gitignored; **never
commit them**.

## How signing works (nix-cached toolchain)

Following the ci-cd-workflows convention, `cd.yaml` is a thin task runner: the imperative
build/sign logic lives in `scripts/ci/cd-{matrix,ios,android}.sh`, run inside a per-platform nix dev
shell so flutter, Android SDK, JDK, CocoaPods, GNU rsync, and pipx are all cached (no per-run
`brew`/`apt`/flutter-action downloads). Caching differs per platform:

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

- `.#cd-ios` — flutter + CocoaPods + GNU rsync + pipx.
- `.#cd-android` — flutter + Android SDK + JDK + pipx, with `ANDROID_SDK_ROOT`/`ANDROID_HOME`/`JAVA_HOME`.

`codemagic-cli-tools` is **not** in nixpkgs, so each job installs it with the nix-provided `pipx`
(`nix develop .#<shell> -c pipx install codemagic-cli-tools`) into `~/.local/bin` (added to `PATH`).

- **iOS** (`nix develop .#cd-ios -c ./scripts/ci/cd-ios.sh`)**:** nix exports a C/C++ stdenv that
  hijacks `xcodebuild`, so the actual `flutter build ipa` is run through `scripts/flutter-ios.sh`,
  which strips the nix toolchain vars and points `DEVELOPER_DIR` at real Xcode. GNU rsync comes from
  nix (macOS openrsync ignores `--chmod` → read-only framework → lipo fails). Signing mirrors the old
  Codemagic script: `keychain initialize` → `app-store-connect fetch-signing-files … --create` →
  `keychain add-certificates` → `xcode-project use-profiles --export-options-plist`.
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
  in-flight build on back-to-back runs.
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
- **Play first upload:** the very first `.aab` for each applicationId must be uploaded **manually**
  once in Play Console before the API will accept automated uploads.
- **macOS toolchain:** if an iOS step fails on Xcode path / pods / profiles, iterate via manual
  `workflow_dispatch` before relying on a real tag.
