# Home-screen widget (parked)

The iOS "today's habits" home-screen widget — shows the **next habit due** (advancing by
time of day), then a **done-summary** when nothing's left. Built but **parked** because it
needs an **App Group**, which requires a **paid Apple Developer Program** membership
(a free Apple account can't enable App Groups, and the simulator path hit build-config
friction). All the code is here, ready to re-add once enrolled.

## Files here
- `NeonWidget.swift` — the SwiftUI WidgetKit widget (small + medium): TimelineProvider that
  reads the shared App Group and renders "next up" / summary.
- `widget_service.dart` — Flutter side: computes today's schedule from the habit overview and
  writes it to the App Group via the `home_widget` package; call from `DashboardController.load()`.

## To re-add (on a paid Apple Developer account)
1. `flutter pub add home_widget`, set Podfile `platform :ios, '14.0'`.
2. Xcode → **File → New → Target → Widget Extension** named `NeonWidget` (uncheck Live Activity /
   App Intent). Copy `NeonWidget.swift` over the generated one.
3. Add **App Groups** capability `group.cloud.atomi.alcoholNeon` to **both** Runner and the widget
   target (Signing & Capabilities — needs a Team).
4. **Fix the build cycle:** Runner target → Build Phases → drag **"Embed Foundation Extensions"**
   above **"[CP] Embed Pods Frameworks"**. (And ensure the appex is embedded only once.)
5. Add `widget_service.dart` to `lib/services/`, and in `DashboardController.load()` (Ok branch):
   `unawaited(WidgetService.instance.sync(value));`
6. `flutter run` — add the widget to the home screen.

Contract reminder: schedule JSON is `{date, done, total, items:[{time:"HH:mm", name, done}]}`;
days[] is Sunday=0; the widget keys are App Group `group.cloud.atomi.alcoholNeon`, data key
`today_schedule`, widget kind `NeonWidget`.
