# alcohol.neon — App Development Plan

Native SwiftUI iOS app for **LazyTax**, built on the foundation in `speedykrab/foundation`.
This plan maps the existing **argon** (web) experience and the **zinc** REST API onto native
screens, with phased milestones. Derived from a full read of zinc's controllers and argon's pages.

---

## 1. What the foundation already gives us (done)

- **Config/landscapes** — `AppConfig` per landscape (lapras/pichu/pikachu/raichu), zinc base URLs + Logto.
- **Errors** — `Problem` (RFC 7807) + `Result<T, Problem>` everywhere (no throwing to views).
- **Networking** — `ApiClient` (async, Bearer-injected, `Result<T, Problem>`).
- **Auth** — `AuthService` wrapping Logto (`signInWithBrowser`, `getAccessToken(for: zincResource)`, Keychain-persisted).
- **Shell** — `RootView` switching on `AuthStatus`; `SignInView`, `HomeView` (proves token acquisition).

**Pending before features:** (a) build verification (validate Logto SDK call shapes), and
(b) a **Native Logto application** registered (App ID + `cloud.atomi.<landscape>.alcohol.neon.app://callback` + `alcohol-zinc` resource) — sign-in can't complete without it.

---

## 2. Architecture for features

- **Pattern:** SwiftUI + `@Observable` (iOS 17 Observation) view models. One feature = one folder under `Sources/Features/`.
- **Data layer:** typed **repositories** per domain, each wrapping `AuthService.makeApiClient()` and returning `Result<T, Problem>`:
  `HabitRepository`, `ExecutionRepository`, `UserRepository`, `CharityRepository`, `CauseRepository`, `ConfigRepository`, `PaymentRepository`, `ProtectionRepository`, `VacationRepository`.
- **DTOs:** `Codable` structs under `Sources/Models/` mirroring zinc's `*Res`/`*Req`. **Watch the quirks** (see §4).
- **DI:** grow `AlcoholNeonApp` into a small composition root that builds the repositories from `AuthService` and injects via `.environment`.
- **User identity:** zinc user id == Logto `sub`. Most endpoints are `/{userId}/…`; cache `userId` in an app session model after sign-in.

---

## 3. API surface (from zinc) — what we'll call

Base: `{landscape zinc URL}/api/v1`. Bearer token scoped to `alcohol-zinc`. Key endpoints:

**Bootstrap / user**

- `POST /User` `{ IdToken, AccessToken }` → create zinc user from Logto tokens (run after first sign-in)
- `GET /User/Me/All` → profile (`Username, Email, EmailVerified, Active`)
- `GET /Configuration/me` → `{ Timezone, DefaultCharityId }` (absent ⇒ needs onboarding)
- `POST /Configuration` `{ Timezone, DefaultCharityId }` ; `PUT /Configuration/{id}` to update

**Daily loop (core)**

- `GET /Habit/{userId}/overview` → dashboard payload: `Habits[]` (name, days[7], stake, charity, status{currentStreak,maxStreak,isCompleteToday,week}, timeLeftToEodMinutes, version.id, totalDebt), plus `TotalDebt`, `UsedSkip`, `TotalSkip`
- `POST /Habit/{userId}/{habitVersionId}/executions` `{ Notes? }` → complete (Status "succeeded")
- `POST /Habit/{userId}/{habitVersionId}/executions/skip` `{ Notes? }` → skip (quota-limited)
- `GET /Habit/{userId}/executions?date=yyyy-MM-dd` → executions for a day

**Habit CRUD (versioned)**

- `GET /Habit/{userId}` (list) ; `GET /Habit/{userId}/{id}` (current version)
- `POST /Habit/{userId}` `{ Task, DaysOfWeek[], NotificationTime "HH:mm", Stake "10.50", CharityId, Timezone }`
- `PUT /Habit/{userId}/{id}` `{ …, Enabled }` (creates a new version)
- `DELETE /Habit/{userId}/{id}`

**Charities / causes (public, no auth)**

- `GET /Charity?name=&country=&causeKey=&limit=&skip=` ; `GET /Charity/{id}` ; `GET /Charity/supported-countries`
- `GET /Causes?key=&name=`

**Payments (Airwallex) — for staking**

- `PUT /Payment/{userId}/customers` → `{ CustomerId, ClientSecret }`
- `GET /Payment/{userId}/client-secret` → fresh `{ ClientSecret, CustomerId }`
- `GET /Payment/{userId}/consent` → `{ HasPaymentConsent, ConsentId?, Status? }`
- `DELETE /Payment/{userId}/consent` → revoke

**Protections / vacation**

- `GET /Protection/{userId}` → `{ Balance, Cap }` (freeze days)
- `POST /Vacation/{userId}` `{ StartDate, EndDate, Timezone }` ; `GET /Vacation/{userId}?year=` ; `DELETE …/{id}` ; `PATCH …/{id}/end-today`

---

## 4. Data-shape quirks to handle in DTOs/mappers

- **Stake / Ratio / debt are decimal STRINGS** (e.g. `"10.50"`, `"100.0"`). Parse to `Decimal`; format with the currency. (The overview's `stake` is an object `{amount, currency}` — inconsistent with the CRUD string; handle both.)
- **`NotificationTime` is `"HH:mm"`** (CRUD) — but executions/overview use other shapes. Use `DateComponents`/`Date` carefully.
- **`DaysOfWeek` (CRUD) = lowercase names** `["monday",…]`; **overview `days` = `Bool[7]`** indexed (note: agent reported Sun–Sat for the week map and an index array — confirm index base when wiring). Centralize day mapping.
- **Dates are `"yyyy-MM-dd"`**; some admin endpoints use `"dd-MM-yyyy"`. Use explicit `DateFormatter`s, not ISO.
- **Execution status enum:** `succeeded | failed | skip | frozen | vacation | not_applicable`.
- **Timezone is IANA** (e.g. `Asia/Singapore`).
- Build one `ZincDecoding` helper with the right formatters; don't scatter format strings.

---

## 5. Screens (argon → SwiftUI)

| Screen                     | Source (argon)               | Loads                                                | Actions                                                                                |
| -------------------------- | ---------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Sign in**                | `/` + Logto                  | —                                                    | Logto browser sign-in (foundation)                                                     |
| **Onboarding**             | `/onboarding`                | `GET /Configuration/me` (absent), charities          | pick Timezone + default Charity → `POST /Configuration`                                |
| **Dashboard**              | `/app`                       | `GET /Habit/{userId}/overview`                       | complete (optimistic), skip, edit, delete, new; progress + streaks + debt + skips-left |
| **New / Edit habit**       | `/app/new`, `/app/edit/[id]` | config defaults, charity                             | form: task, days, time, stake, charity → `POST`/`PUT /Habit`                           |
| **Charity picker**         | `/charities`                 | `GET /Charity`, `/Causes`                            | search/filter by name/country/cause, select                                            |
| **Settings**               | `/settings`                  | `GET /Configuration/me`, `/Payment/{userId}/consent` | update timezone/charity; set up / remove payment consent                               |
| **Profile**                | `/profile`                   | Logto claims, `/User/Me/All`                         | view info, sign out                                                                    |
| **Payment consent**        | `/app/payment/callback`      | Airwallex flow                                       | collect consent, poll `/Payment/{userId}/consent` until VERIFIED                       |
| **Protections / vacation** | dashboard stubs              | `GET /Protection/{userId}`, `/Vacation`              | view freezes; start/end vacation                                                       |

---

## 6. Key flows

**A. First sign-in → usable app**
sign-in (Logto) → `POST /User` (idempotent create) → `GET /Configuration/me` → if absent, **Onboarding** (timezone + default charity) → `POST /Configuration` → **Dashboard**.

**B. Daily completion (core loop)**
`GET overview` → render today vs rest-day → tap ✓ → **optimistic** mark complete → `POST …/executions` → reconcile; celebrate when all done. Skip → `POST …/executions/skip` (respect `TotalSkip - UsedSkip`).

**C. Staking → payment consent (the hard one)**
Setting a stake > 0 without consent must collect an Airwallex payment consent. Web uses a hosted-page redirect + callback + polling. **Native decision needed (§8):** Airwallex **iOS SDK** vs an in-app web flow (`ASWebAuthenticationSession`/`SFSafariViewController`). Backend supplies `clientSecret`/`customerId`; after collection, poll `GET /Payment/{userId}/consent` until `HasPaymentConsent`, then continue habit creation. Preserve form state across the flow.

**D. Charity selection**
From habit form → Charity picker (search/filter) → return selected `charityId` to the form.

---

## 7. Milestones (vertical slices, each shippable/testable)

- **M0 — Foundation** ✅ (auth, config, networking, shell). _Build-verify + Native Logto app are the gates._
- **M1 — Bootstrap + Onboarding:** session/user model, `POST /User`, `GET /Configuration/me`, onboarding (timezone + default charity), charity picker (read-only). → signed-in users reach a configured state.
- **M2 — Dashboard (daily loop):** overview DTOs + `HabitRepository`, dashboard UI (today/rest-day, streaks, progress, debt), **complete** (optimistic) + **skip**. → the core product.
- **M3 — Habit CRUD:** create/edit/delete with the full form (task, days, time, stake, charity); versioning awareness.
- **M4 — Charity browse/search:** full filters (name/country/cause), causes tree.
- **M5 — Settings + Profile:** update timezone/default charity, sign out, view profile/claims.
- **M6 — Payment consent (Airwallex):** the staking flow (SDK-or-web decision), consent setup + removal, polling.
- **M7 — Protections + Vacation:** freeze balance display, start/end vacation, skip quota surfacing.
- **Polish:** local notifications at `NotificationTime` (habit reminders), streak/celebration UI, empty/error states, offline tolerance, app icon/branding.

Recommended order to build: **M1 → M2** first (gets a real, demoable daily loop), then **M3 → M4 → M5**, then **M6** (payments), then **M7** + polish.

---

## 8. Open decisions / dependencies

1. **Native Logto app** (BLOCKER for any sign-in) — register it; fill `logtoAppId` in `AppConfig`. _(User action.)_
2. **Airwallex on iOS** — decide **Airwallex iOS SDK** (native consent UI, more work) vs **in-app web flow** (reuse the hosted page via `ASWebAuthenticationSession`, faster). Affects M6. _(Needs a decision; recommend starting with the web flow to ship, native SDK later.)_
3. **Local notifications** — habits have a `NotificationTime`; decide whether reminders are local (scheduled on-device from the habit list) or server push. Local is simplest for v1.
4. **State management depth** — `@Observable` view models + repositories is enough; revisit if it grows.
5. **OpenAPI codegen** — zinc exposes OpenAPI; consider generating DTOs/clients later instead of hand-writing (argon does `pls generate:sdk`). For now hand-write the slice we need.
6. **Min iOS / devices** — currently iOS 17, iPhone-only (portrait). Confirm.

---

## 9. Risks

- **Data-shape inconsistencies** between CRUD and overview (stake string vs object; day arrays). Mitigate with a single decoding/mapping layer and tests.
- **Airwallex native flow** is the largest unknown; isolate it behind a `PaymentConsentCollector` protocol so SDK-vs-web is swappable.
- **Timezones / end-of-day** logic is central to correctness (completion windows, day boundaries) — mirror zinc's semantics, don't reinvent.
- **No CI iOS build locally** historically; now unblocked (xcodegen + Xcode). Keep `task build` green per milestone.

---

## 10. Immediate next steps (once build is green + Logto app exists)

1. Add `Sources/Models/` DTOs for the M1/M2 slice (User, Configuration, Charity, HabitOverview, Execution) with the `ZincDecoding` helper.
2. Add `UserRepository`, `ConfigRepository`, `CharityRepository`, `HabitRepository`.
3. Build **M1** (bootstrap + onboarding), then **M2** (dashboard + complete/skip).
4. Keep each milestone behind a green `task build`.
