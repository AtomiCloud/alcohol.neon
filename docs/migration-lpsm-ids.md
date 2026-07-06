# Migration runbook: LPSM bundle/application IDs

The repo now uses LPSM identifiers everywhere (see
[docs/developer/standard/bundle-id.md](developer/standard/bundle-id.md)):

|                | old                                           | new                                                  |
| -------------- | --------------------------------------------- | ---------------------------------------------------- |
| iOS app        | `cloud.atomi.alcohol.neon.<L>`                | `cloud.atomi.<L>.alcohol.neon`                       |
| iOS widget     | `cloud.atomi.alcohol.neon.<L>.NeonWidget`     | `cloud.atomi.<L>.alcohol.neon.widget`                |
| Android app    | `cloud.atomi.alcohol_neon.<L>`                | `cloud.atomi.<L>.alcohol.neon` (same as iOS)         |
| App Group      | `group.cloud.atomi.alcoholNeon` (one, shared) | `group.cloud.atomi.<L>.alcohol.neon` (per landscape) |
| Logto redirect | `cloud.atomi.alcohol.neon.<L>://callback`     | `cloud.atomi.<L>.alcohol.neon://callback`            |

New bundle ids = new store apps. The code side ships in this PR; the following
finishes the cutover. Steps 2–3 are manual forever because Apple/Google expose
no API for them; step 1 is one command that does everything Apple-side.

## 1. Rename the old apps, then `pls register` (App Manager, ~10 min)

In App Store Connect, **rename the 3 old apps first** — they hold the store
names ("LazyTax", "LazyTax (Pichu)", "LazyTax (Pikachu)"): e.g. suffix " OLD".
Old numeric ids for reference: pichu `6777280038`, pikachu `6777280047`,
raichu `6777280099`. Then:

```bash
pls register
```

Sign in with your (App Manager/Admin) Apple ID; expect one 2FA prompt, then a
team menu (Developer portal + App Store Connect). Per landscape it creates the
App Group, all App IDs (app + widget), enables + associates the App Groups
capability, creates the **App Store Connect app record**, and **writes the new
numeric `apple_id` into `scripts/ci/cd-matrix.sh`** — review and commit that
diff. Idempotent — safe to re-run; if a store name is still taken it tells you
which landscape to fix and you just re-run after renaming.

## 2. Google Play Console — 3 new apps (~15 min)

App creation has no API here either. For each landscape:

1. All apps → **Create app** → name as above, App/Game, Free.
2. Package name is fixed by the first upload: `cloud.atomi.<L>.alcohol.neon`.
3. Ensure the CI service account (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`) has access
   to the new app (skip if it has account-wide access).
4. Complete the minimum setup for the **internal testing** track. The first CD
   upload enrolls Play App Signing (same upload keystore — no keystore change).

## 3. Logto — redirect URIs (~3 min, or scriptable via Logto Management API)

On each landscape's Native app in Logto, add the new redirect URI
`cloud.atomi.<L>.alcohol.neon://callback` (keep the old one during cutover;
delete it once the new builds are live).

## 4. Cut a release and let the doctor check you

Tag (or `workflow_dispatch` a pichu smoke build). CD now:

- fetches signing files for **every** discovered target (app + widget),
- runs `scripts/ci/doctor-ios.sh`, which decodes the profiles and **fails with
  the exact missing piece** if step 1 was skipped,
- publishes to the new TestFlight/Play apps.

## 5. Cleanup (later, non-blocking)

- Remove/retire the renamed old ASC apps and old Play apps; re-invite testers.
- Delete the old bundle ids and the old shared `group.cloud.atomi.alcoholNeon`
  in the portal once no old build matters.
- Drop the old Logto redirect URIs.

## Ongoing: adding a widget / extension / watch app

1. Add the target in Xcode with its LPSM bundle id (`…alcohol.neon.<module>`).
2. `pls register` (one 2FA tap).
3. Commit. CI discovers it; nothing else to edit. If you skip step 2, the
   doctor step fails the release naming the unregistered target.

Android widgets: just code — no registration anywhere.
