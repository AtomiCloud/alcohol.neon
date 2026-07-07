# Home-screen widget (iOS) — setup guide

The iOS "today's habits" home-screen widget shows the **next habit due** (advancing by time
of day), then a **done-summary** when nothing's left. The Flutter app writes today's schedule
to a shared **App Group**; the WidgetKit extension reads it and renders.

```
Flutter app ──writes today_schedule──▶ App Group ──reads──▶ NeonWidget (WidgetKit) ──▶ home screen
            (WidgetService.sync on dashboard load)   group.cloud.atomi.<landscape>.alcohol.neon.app
```

The App Group is **per landscape** — `group.` + the app's LPSM bundle id (see
[docs/developer/standard/bundle-id.md](../developer/standard/bundle-id.md)); Dart derives it
from the package name, the iOS targets from the `NEON_APP_GROUP` build setting.

## Already wired (code side — done)
- `home_widget` package added to `pubspec.yaml`; Podfile `platform :ios, '14.0'`.
- `lib/services/widget_service.dart` — computes today's schedule and pushes it on every
  dashboard load (called from `DashboardController.load()`).
- `ios/NeonWidget/NeonWidget.swift` — the SwiftUI widget (small + medium), ready to drop into
  the extension target.

## Remaining (Xcode GUI — can't be done from the terminal)
1. **Create the target:** Xcode → open `ios/Runner.xcworkspace` → **File ▸ New ▸ Target ▸
   Widget Extension**. Name it **`NeonWidget`**. Uncheck "Include Live Activity" and
   "Include Configuration App Intent". Finish → "Activate" the scheme if prompted.
2. **Use our widget code:** replace the generated `NeonWidget.swift` body with
   `ios/NeonWidget/NeonWidget.swift` (keep Xcode's generated `@main … Bundle.swift`).
3. **App Group on BOTH targets:** select the project → for **Runner** and **NeonWidgetExtension**,
   Signing & Capabilities → **+ Capability ▸ App Groups** → add the landscape's group
   (**`group.cloud.atomi.<landscape>.alcohol.neon.app`** — or keep the `$(NEON_APP_GROUP)`
   entitlements the repo already carries).
   - On the **Simulator** the App Group works without portal registration.
   - For a **real device / TestFlight**, an Admin/App Manager runs **`pls register`** once —
     it creates the groups, App IDs, and associations in the Developer portal (a
     Developer-role member can't). CD verifies this via `scripts/ci/doctor-ios.sh`.
4. **Fix the build-phase order (avoids a dependency cycle):** Runner target → Build Phases →
   drag **"Embed Foundation Extensions"** ABOVE **"[CP] Embed Pods Frameworks"**.
5. **Set both targets' Team** + Deployment Target iOS 14.0+.
6. `flutter run` → long-press the home screen → **+** → add **Today's habits**.

## Data contract
App Group `group.cloud.atomi.<landscape>.alcohol.neon.app`, key `today_schedule`, widget kind `NeonWidget`:
```json
{ "date": "2026-06-06", "done": 1, "total": 3,
  "items": [ { "time": "06:30", "name": "Morning run", "done": false } ] }
```
`days[]` is Sunday=0 (zinc convention); `time` is `"HH:mm"`.
