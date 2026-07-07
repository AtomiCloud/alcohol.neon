# Store credentials — Apple & Google setup from scratch

Everything CD needs to sign and publish, how to mint each credential from
zero, and where it lives. All secrets go into **Infisical (`raichu`)** and sync
to org-level GitHub Actions secrets.

## Apple — what CD needs

| Secret                             | What it is                                                 |
| ---------------------------------- | ---------------------------------------------------------- |
| `APP_STORE_CONNECT_ISSUER_ID`      | ASC API key issuer (UUID, shown on the Integrations page)  |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | ASC API key id (e.g. `A1B2C3D4E5`)                         |
| `APP_STORE_CONNECT_PRIVATE_KEY`    | the API key's `.p8` contents (multiline)                   |
| `CERTIFICATE_PRIVATE_KEY`          | RSA private key backing the Apple Distribution certificate |

### 1. App Store Connect API key (the robot)

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Users and
   Access → Integrations → App Store Connect API → Team Keys** (an Admin must
   generate).
2. **Generate API Key** — role **App Manager** is enough for CD (certs,
   profiles, bundle ids, uploads).
3. Download the `.p8` — **only downloadable once**; its contents become
   `APP_STORE_CONNECT_PRIVATE_KEY`. The key id and the page's **Issuer ID**
   fill the other two secrets.

### 2. Distribution certificate key (the signature)

The signing certificate is _derived from a private key you own_. Mint the key
once; `fetch-signing-files --create` then creates the Apple Distribution
certificate from it on first run and **reuses** it forever after (teams are
capped at ~2 distribution certs — never mint per-run):

```bash
openssl genrsa -out apple_distribution.key 2048   # contents → CERTIFICATE_PRIVATE_KEY
```

No portal clicking needed — the first CD run creates the certificate.

### 3. Human Apple ID (for `pls register` only)

Portal writes with no API (App Groups, associations, ASC app records) run
through `pls register` with a **human App Manager/Admin Apple ID** + one 2FA
prompt. Nothing is stored; see
[docs/developer/standard/bundle-id.md](developer/standard/bundle-id.md).

### Apple troubleshooting

| Error                                 | Meaning                                                                         | Fix                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `401` from app-store-connect          | issuer/key-id/`.p8` mismatch or revoked key                                     | re-check the three secrets as a set                          |
| `409 … identifier … is not available` | bundle id/App Group registered in another team, or reserved ~48h after deletion | delete it there / wait / Apple support                       |
| `doctor: FAIL … lacks App Group`      | portal wiring missing for a target                                              | `pls register`                                               |
| cert limit reached                    | too many Distribution certs                                                     | revoke an unused one; keep reusing `CERTIFICATE_PRIVATE_KEY` |

---

## Google Play service account

CD publishes Android builds to Play (internal track) via the Google Play
Developer API, authenticated as a **GCP service account**. This is the
one-time setup and the care-and-feeding rules.

## How the pieces fit

```
GCP project ──owns──▶ service account ──JSON key──▶ Infisical ──sync──▶ GitHub secret
                                                        GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
Play Console ──invites the SA's email as a "user" with per-app permissions
CD (cd-android.sh / r0adkll-upload-google-play) ──uses key + permissions──▶ upload AAB
```

The service account lives in Google Cloud; Play Console only _grants it
permissions_, like any human user, keyed by its email.

## 1. Create the service account (GCP, once)

1. [console.cloud.google.com](https://console.cloud.google.com) → pick/create a
   project (any project — it does not need to relate to the app).
2. **APIs & Services → Library** → enable **Google Play Android Developer API**.
3. **IAM & Admin → Service Accounts → Create service account**
   - name: e.g. `play-publisher` — no GCP roles needed (permissions come from
     Play Console, not IAM).
4. Open the account → **Keys → Add key → JSON** → download. This file is the
   credential; treat it like a password.

## 2. Grant it access in Play Console (account owner)

1. [play.google.com/console](https://play.google.com/console) →
   **Users and permissions → Invite new user**.
2. Email = the service account's email (`play-publisher@<project>.iam.gserviceaccount.com`).
3. Permissions — either **account-wide** (simplest) or per-app. Minimum for CD:
   - View app information
   - **Release to testing tracks** + manage testing tracks / tester lists
   - (Only when automating store promotion later: release to production)
4. Send invite — service accounts "accept" automatically.

> ⚠️ **Per-app grants do NOT cover apps created later.** When a new Play app
> is created (new landscape, id migration, …) the service account must be
> added to it explicitly — forgetting this yields CD failing with
> `The caller does not have permission` (exactly what happened on v1.6.0).
> Account-wide access avoids the whole class.

## 3. Wire the key into CI

1. Put the JSON key in Infisical (`raichu` — the org-level signing project).
2. It syncs to the org GitHub Actions secret **`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`**,
   consumed by `⚡reusable-cd-android.yaml` (versionCode query in
   `scripts/ci/cd-android.sh` + the `r0adkll/upload-google-play` publish step).

## 4. Verify

Run a manual CD smoke: Actions → **CD → Run workflow → flavor: pichu**. The
Android job should query the latest build number and upload to the internal
track of `cloud.atomi.pichu.alcohol.neon.app`.

## Troubleshooting

| Error                                       | Meaning                                                             | Fix                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `The caller does not have permission`       | SA not granted on _that_ app (or grant still propagating, ~minutes) | Users and permissions → add the SA to the app                                    |
| `Package not found: <id>`                   | No Play app record with that package                                | Create the app in Play Console (no API exists); package is fixed by first upload |
| `401 invalid_grant` / `unauthorized_client` | JSON key revoked/rotated, or API not enabled                        | New key → Infisical; check the Play Developer API is enabled                     |
| First upload rejected                       | Play App Signing not yet accepted                                   | Accept Play App Signing in the app's Setup once                                  |

Related: [docs/github-actions-release.md](github-actions-release.md) (release
runbook) · [docs/migration-lpsm-ids.md](migration-lpsm-ids.md) (id migration
cutover) · [docs/developer/standard/bundle-id.md](developer/standard/bundle-id.md)
(identifier grammar).
