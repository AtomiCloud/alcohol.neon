# LazyTax (alcohol.neon) — Store Setup Runbook (was: Codemagic)

> ⚠️ **Codemagic has been replaced by GitHub Actions** (`.github/workflows/cd.yaml`); `codemagic.yaml`
> is removed. **Parts 3–9 (store identities, ASC API key, keystore, Play service account) are still
> the source of truth** — those records are reused by the GHA pipeline. **Part 10 (loading credentials
> into Codemagic) is obsolete:** the same materials now live as org-level GitHub Actions secrets
> (synced from Infisical `raichu`) — see [github-actions-release.md](github-actions-release.md) for the
> secret names and the build/publish flow.

Step-by-step setup for shipping **3 channels** of the LazyTax app (codename _neon_) to the
App Store and Play Store. Signing + publishing is automated by GitHub Actions (these parts cover the
one-time Apple/Google **identity** setup the pipeline depends on).

- **pichu** = dev → **TestFlight internal + Play internal** (not public)
- **pikachu** = stage → **TestFlight external + Play closed** (not public)
- **raichu** = prod → **public App Store + Play production**

Signing rests on just **1 Apple API key + 1 Android keystore + 1 Play service account** — shared by all 3.
Everything done "×3" is only _identity registration_.

> **▶ CURRENT SCOPE: Apple / App Store only.** Play Store steps are **deferred**. Parts 6, 7, 8, the Android
> keystore (Part 9), and the Android/Play portions of Parts 10–12 are tagged **_(DEFERRED)_** — skip them for
> now. Do the Apple parts: **3, 4, 5, 10a**, and the iOS portions of **11–12**.
>
> **Account status:** Parts 3–5 require the Apple Developer Program membership to be **active**. If enrollment
> is still pending approval, wait for Apple's confirmation email before starting Part 3. App _review_ is not
> needed for setup — **TestFlight internal testing requires no review**.

## Identities (target state)

| Flavor            | iOS bundle id                      | Android applicationId              | Display name  | Public?                       |
| ----------------- | ---------------------------------- | ---------------------------------- | ------------- | ----------------------------- |
| `pichu` (dev)     | `cloud.atomi.alcohol.neon.pichu`   | `cloud.atomi.alcohol_neon.pichu`   | LazyTax Dev   | No (TestFlight/internal only) |
| `pikachu` (stage) | `cloud.atomi.alcohol.neon.pikachu` | `cloud.atomi.alcohol_neon.pikachu` | LazyTax Stage | No (TestFlight/closed only)   |
| `raichu` (prod)   | `cloud.atomi.alcohol.neon.raichu`  | `cloud.atomi.alcohol_neon.raichu`  | LazyTax       | Yes                           |

---

## Prerequisites (already done / confirm)

- Apple Developer Program active (paid), **Admin/Account Holder** on the owning team.
- Google Play Console active (paid), Admin on the owning account.
- Codemagic personal account created; GitHub app connected to `AtomiCloud/alcohol.neon`.
- No Mac required — Codemagic provides macOS build machines.

### Step 0 — confirm the owning team

- developer.apple.com/account → **Membership details** → note the **Team Name**. That team will own LazyTax.
- The active team is your own account. If publishing under a different team, switch via the top-right avatar first (you must be **Admin** on that team to register App IDs).

---

## PART 3 — Register the 3 App IDs (Apple Developer portal)

1. Go to **developer.apple.com/account** and sign in.
2. Click **Certificates, IDs & Profiles** → **Identifiers**.
3. Click the blue **＋** next to "Identifiers".
4. Select **App IDs** → **Continue**.
5. Select type **App** → **Continue**.
6. Fill **Description** and **Bundle ID** (choose **Explicit**) per the block below.
7. In **Capabilities**, tick **Push Notifications**.
8. Click **Continue** → **Register**.
9. Repeat for the other two.

```
# pichu (dev)
Description: LazyTax Dev
Bundle ID:   Explicit  →  cloud.atomi.alcohol.neon.pichu
Capability:  [x] Push Notifications

# pikachu (stage)
Description: LazyTax Stage
Bundle ID:   Explicit  →  cloud.atomi.alcohol.neon.pikachu
Capability:  [x] Push Notifications

# raichu (prod)
Description: LazyTax
Bundle ID:   Explicit  →  cloud.atomi.alcohol.neon.raichu
Capability:  [x] Push Notifications
```

> ⚠️ **Description** allows letters/numbers/spaces only. Push capability is free; it only matters
> once you add remote push later. Local reminders need no capability.

---

## PART 4 — Create the 3 App Store Connect records

1. Go to **appstoreconnect.apple.com** → **Apps**.
2. Click **＋** (top-left, beside "Apps") → **New App**.
3. Fill the block below (Bundle ID is a dropdown of what you registered in Part 3) → **Create**.
4. Repeat for the other two.

```
# pichu (dev)
Platforms:        [x] iOS
Name:             LazyTax Dev
Primary Language: English (U.S.)
Bundle ID:        cloud.atomi.alcohol.neon.pichu
SKU:              alcohol-neon-pichu
User Access:      Full Access

# pikachu (stage)
Platforms:        [x] iOS
Name:             LazyTax Stage
Primary Language: English (U.S.)
Bundle ID:        cloud.atomi.alcohol.neon.pikachu
SKU:              alcohol-neon-pikachu
User Access:      Full Access

# raichu (prod)
Platforms:        [x] iOS
Name:             LazyTax
Primary Language: English (U.S.)
Bundle ID:        cloud.atomi.alcohol.neon.raichu
SKU:              alcohol-neon-raichu
User Access:      Full Access
```

> **User Access (Full vs Limited) is NOT about TestFlight vs public.** It only controls which of your
> teammates can see/manage this app record. TestFlight-only distribution (pichu/pikachu) is achieved
> simply by never submitting to the App Store — the User Access setting has no effect on it. Use
> **Full Access** unless you specifically want to hide an app from some team members.
>
> ⚠️ App **Name** is globally unique on the App Store. If `LazyTax` is taken for raichu, use
> `LazyTax: Habit Stakes`.

5. **Capture each app's Apple ID:** open the app and read the browser URL
   `…/apps/`**`6478123456`**`/…` — that number is the Apple ID. (Or: app → **Distribution** tab →
   **General → App Information** → **Apple ID**.)

```
APP_STORE_APPLE_ID (pichu)   = __________
APP_STORE_APPLE_ID (pikachu) = __________
APP_STORE_APPLE_ID (raichu)  = __________
```

---

## PART 5 — Create 1 App Store Connect API key (shared by all 3)

1. App Store Connect → **Users and Access**.
2. Click the **Integrations** tab (top).
3. Select **App Store Connect API** (left). If first time, click **Request Access** / enable.
4. Under **Team Keys**, click **＋** (Generate API Key).
5. Fill: `Name: codemagic-lazytax`, `Access: App Manager` → **Generate**.
6. **Capture** (one-time only):

```
ISSUER_ID = __________     # shown above the keys table
KEY_ID    = __________     # the new key's ID
.p8 file  = Download  →  AuthKey_<KEY_ID>.p8   (downloadable ONCE — save safely)
```

---

## PART 6 — Create the 3 Google Play apps _(DEFERRED — Play Store)_

1. Go to **play.google.com/console** (confirm the correct developer account).
2. Click **Create app**, fill the block below → **Create app**.
3. Repeat for the other two.

```
# pichu (dev)
App name:         LazyTax Dev
Package name:     cloud.atomi.alcohol_neon.pichu   (ref only — locked in at Part 12)
Default language: English (United States)
App or game:      App
Free or paid:     Free   (tick the declarations)

# pikachu (stage)
App name:         LazyTax Stage
Package name:     cloud.atomi.alcohol_neon.pikachu   (ref only — locked in at Part 12)
Default language: English (United States)
App or game:      App
Free or paid:     Free

# raichu (prod)
App name:         LazyTax
Package name:     cloud.atomi.alcohol_neon.raichu   (ref only — locked in at Part 12)
Default language: English (United States)
App or game:      App
Free or paid:     Free
```

> ⚠️ The **applicationId** is NOT set here — it's locked in by the first uploaded AAB (Part 12).
> Keep the three straight by name for now.

---

## PART 7 — Confirm Play App Signing (each app)

1. Open each app → left sidebar **Protected with Play** (shield icon) → expand the **Play Store
   protection** row (chevron ⌄) → find **Play app signing** in the service list. (Current UI; the old
   **Setup → App signing** path is gone — signing is now a service nested under _Protected with Play →
   Play Store protection_.)
2. Confirm **Play App Signing is enabled** (default). You sign with the upload key (Part 9); Google
   holds the real app-signing key. Nothing to change.

> ⚠️ For a **brand-new app with no AAB uploaded yet**, there's nothing to toggle — Play App Signing is
> on by default and only fully activates (signing cert + SHA-1 appear) after the **first upload** (Part 12).
> Seeing "nothing to confirm" here at this stage is expected.

---

## PART 8 — Create 1 Google Play service account (shared) _(DEFERRED — Play Store)_

**In Google Cloud Console** (console.cloud.google.com — same Google account as Play):

1. **APIs & Services → Library** → search **Google Play Android Developer API** → **Enable**.
2. **IAM & Admin → Service Accounts → Create service account**: name `codemagic-alcohol-neon-publish`
   → **Create and continue** → skip optional roles → **Done**.
3. Open the service account → **Keys** → **Add key → Create new key → JSON** → **Create**.
   A `.json` downloads — ⚠️ **save it; this is `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS`.**
4. Copy the service account **email** (`...@<project>.iam.gserviceaccount.com`).

**In Play Console:** 5. Account home → **Users and permissions** → **Invite new users** → paste the service-account email. 6. **App permissions** → add all 3 apps → grant **Admin** (or at least _Release to testing_ +
_Release to production_) → **Invite user**. (Activation can take up to ~24h.)

---

## PART 9 — Generate the 1 Android upload keystore (shared) _(DEFERRED — Android)_

Run locally (`keytool` ships with any JDK):

```bash
keytool -genkeypair -v -keystore atomi-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias atomi-upload
```

Capture:

```
KEYSTORE_FILE  = atomi-upload.jks
STORE_PASSWORD = __________
KEY_ALIAS      = atomi-upload
KEY_PASSWORD   = __________   (press Enter at the prompt to reuse the store password)
```

> ⚠️ **Back up `atomi-upload.jks` + both passwords offline.** Shared by all 3 apps; cannot be
> re-downloaded from Codemagic. Losing it blocks all future Android updates.

---

## PART 10 — Load the shared credentials into Codemagic

Codemagic → **avatar → Settings** (personal account).

**10a — Apple integration** → **Integrations** → **Apple Developer Portal** → **Connect**:

```
Name:      lazytax_app_store_connect
Issuer ID: <ISSUER_ID from Part 5>
Key ID:    <KEY_ID from Part 5>
API key:   upload AuthKey_<KEY_ID>.p8
```

→ Codemagic auto-creates the cert + per-bundle-id provisioning profiles at build time.

**10b — Android keystore** _(DEFERRED — Android)_ → **Code signing identities → Android keystores → Add keystore**:

```
Reference name: atomi_upload_keystore
Keystore file:  upload atomi-upload.jks
Keystore pwd:   <STORE_PASSWORD>
Key alias:      atomi-upload
Key pwd:        <KEY_PASSWORD>
```

**10c — Play service account secret** _(DEFERRED — Play Store)_ → in the **alcohol.neon app → Environment variables**.
This UI is just **Variable name + Value + Secret** (no groups — that's fine, we don't need them). Add ONE entry:

```
Variable name: GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS
Variable value: paste the entire Part 8 JSON
Secret: [x]
```

> ⚠️ Variables added in this box apply to **every build of the app** (no per-landscape scoping). So only put
> things here that are the **same for all three channels** — i.e. just the Play JSON. Do **not** add `FLAVOR`,
> bundle id, track, etc. here (those differ per channel → they go in the workflow YAML, Part 11). If you added
> a global `FLAVOR` earlier, **delete it**.

**10d — Per-landscape values** are NOT entered in the UI — they live in `codemagic.yaml` (Part 11), where
each workflow/loop iteration sets its own. Reference table:

|                      | pichu                          | pikachu                          | raichu                          |
| -------------------- | ------------------------------ | -------------------------------- | ------------------------------- |
| `FLAVOR`             | pichu                          | pikachu                          | raichu                          |
| `BUNDLE_ID_IOS`      | cloud.atomi.alcohol.neon.pichu | cloud.atomi.alcohol.neon.pikachu | cloud.atomi.alcohol.neon.raichu |
| `PACKAGE_NAME`       | cloud.atomi.alcohol_neon.pichu | cloud.atomi.alcohol_neon.pikachu | cloud.atomi.alcohol_neon.raichu |
| `APP_STORE_APPLE_ID` | _(pichu Apple ID, Part 4)_     | _(pikachu Apple ID)_             | _(raichu Apple ID)_             |
| `GOOGLE_PLAY_TRACK`  | internal                       | qa-closed _(closed-track name)_  | production                      |

The Apple IDs aren't secret, so they'll be hardcoded in the YAML. (Only the Play JSON needs to be a Codemagic secret.)

---

## PART 11 — Repo: flavors + config

**Status — code implemented on branch `speedykrab/release-channels`:**

- ✅ `package_info_plus` added; `AppConfig` selects the landscape from the app's **own bundle id** at
  runtime (bundle-id-as-marker) — no per-build `--dart-define`. `main()` awaits `AppConfig.load()`.
  _(All 3 landscapes' values were already baked into `_defaults()`, so no asset JSON files are needed.)_
- ✅ Android `productFlavors` (`pichu`/`pikachu`/`raichu`) + applicationId suffixes + per-flavor app name.
- ✅ `codemagic.yaml` — 3 iOS workflows (build → sign → TestFlight), Apple IDs filled in, manual triggers.
- ⚠️ Flutter isn't on the agent's PATH, so this wasn't compiled here — **run `flutter pub get && flutter analyze && flutter test`** to verify.

**You still need to do — iOS Xcode flavor setup** (schemes don't exist yet; `--flavor pichu` needs them):

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **Rename the base bundle id** to `cloud.atomi.alcohol.neon` (currently `cloud.atomi.alcoholNeon`) — Runner target → Signing & Capabilities, all configs.
3. **Duplicate build configs:** Project → Info → Configurations → duplicate Debug/Profile/Release into `*-pichu`, `*-pikachu`, `*-raichu`.
4. **Create 3 shared schemes** named exactly `pichu`/`pikachu`/`raichu` (Product → Scheme → Manage Schemes → +, tick _Shared_); map each scheme's Run/Profile/Archive to its `-<flavor>` configs.
5. **Per-config bundle id + name:** set `PRODUCT_BUNDLE_IDENTIFIER` per config (`…neon.pichu`/`…neon.pikachu`/`…neon.raichu`); add a user-defined `APP_DISPLAY_NAME` (`LazyTax Dev`/`LazyTax Stage`/`LazyTax`) and set Info.plist _Bundle display name_ = `$(APP_DISPLAY_NAME)`.
6. **Register configs in `ios/Podfile`** project map: add `'Debug-pichu' => :debug, 'Profile-pichu' => :release, 'Release-pichu' => :release` (and pikachu/raichu).
   > Shortcut: `flutter_flavorizr` can generate steps 3–6; manual is more reliable on an existing project.

**You still need to do — Logto:** `pichu` already has a real Logto app id in `AppConfig`; **`pikachu` and `raichu`
still have `REPLACE_WITH_NATIVE_LOGTO_APP_ID`.** Create a Logto Native app per landscape (redirect
`cloud.atomi.alcohol.neon://callback` works for all three on iOS) and put each id in `lib/config/app_config.dart`.
Sign-in won't complete on pikachu/raichu until set.

**Optional:** per-flavor launcher icons (DEV/STG badges) via `flutter_launcher_icons`.

---

## PART 12 — First upload, smoke test, go live

1. **Bootstrap each store once, manually:** upload one signed `.aab` **per applicationId** by hand in
   Play Console (locks in the applicationId); push the first iOS build per record to TestFlight.
2. **Smoke-test raichu only** in Codemagic → confirm green signing + TestFlight + Play internal.
3. **Enable pichu + pikachu** in the loop — no new signing setup needed.
4. **Promote to public manually** when ready (App Store: Submit/Release; Play: promote to
   production) — the manual gate.

---

## Captured values (fill as you go)

```
# Apple
TEAM_NAME            =
ISSUER_ID            =
KEY_ID               =
APP_STORE_APPLE_ID pichu   = 6777280038
APP_STORE_APPLE_ID pikachu = 6777280047
APP_STORE_APPLE_ID raichu  = 6777280099

# Android
STORE_PASSWORD       =
KEY_PASSWORD         =
PLAY_SA_EMAIL        =
PLAY_CLOSED_TRACK    =   # name of pikachu's closed testing track
```
