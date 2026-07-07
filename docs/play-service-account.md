# Google Play service account — setup from scratch

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
