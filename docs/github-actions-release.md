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

## How signing works (no nix)

The CI mobile builds deliberately **do not use the nix dev shell** — nix hijacks the C/C++ toolchain
(see `scripts/flutter-ios.sh`) and carries flutter-on-nix gotchas. Instead:

- **iOS:** `subosito/flutter-action` (stable) + the runner's system Xcode + `pipx install
codemagic-cli-tools` (`keychain`, `app-store-connect`, `xcode-project`). GNU rsync is installed via
  Homebrew (macOS openrsync ignores `--chmod` → read-only framework → lipo fails). Signing mirrors the
  old Codemagic script: `keychain initialize` → `app-store-connect fetch-signing-files … --create` →
  `keychain add-certificates` → `xcode-project use-profiles --export-options-plist`.
- **Android:** `setup-java@17` + `subosito/flutter-action` + `android-actions/setup-android`. The
  keystore is decoded to `android/app/upload-keystore.jks` and a `android/key.properties` is written —
  this hits the **existing** `key.properties` path in `android/app/build.gradle.kts` (no gradle change).

## Versioning

- **Version name** = the tag (`v1.2.3` → `1.2.3`). Omitted on manual runs (pubspec version used).
- **iOS build number** = `app-store-connect get-latest-build-number <apple_id>` + 1.
- **Android versionCode** = `github.run_number` (monotonic; unique per Play app).

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
