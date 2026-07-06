//
//  CompleteHabitIntent.swift
//  Runner + NeonWidgetExtension
//
//  Powers the "Complete" button on the home-screen widget. Widget-button intents
//  run in the extension sandbox (no Flutter engine / Logto there), so instead of a
//  headless callback this completes via a direct zinc POST using the auth context
//  the app caches into the shared App Group (zinc_base / zinc_token / zinc_uid).
//
//  Flow: optimistic tick (instant) → POST → on failure, roll the tick back. perform()
//  returns as soon as the POST settles (~1s), so the widget reloads promptly.
//

import AppIntents
import Foundation
import WidgetKit

private let appGroupId = "group.cloud.atomi.alcoholNeon"
private let dataKey = "today_schedule"

@available(iOS 17.0, *)
struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete habit"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit Version Id")
    var versionId: String

    init() {}
    init(versionId: String) { self.versionId = versionId }

    func perform() async throws -> some IntentResult {
        // Show an immediate "Saving…" state so the tap feels responsive, WITHOUT
        // claiming "done" yet.
        setPending(versionId: versionId)
        WidgetCenter.shared.reloadAllTimelines()

        // Confirm-first: this is a money-stakes app, so we must NOT show "done" unless
        // zinc actually recorded it — a false tick could make the user skip a habit they
        // think is complete and get charged the stake. So we POST first and only tick on
        // a confirmed success.
        let ok = await completeOnServer(versionId: versionId)
        clearPending()
        if ok {
            setDone(versionId: versionId, done: true)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    // The "Saving…" marker — a version id + timestamp. The widget shows the loading
    // state only while this matches and is recent, so a killed perform() can't leave
    // the button stuck on "Saving…".
    private func setPending(versionId: String) {
        let d = UserDefaults(suiteName: appGroupId)
        d?.set(versionId, forKey: "pending_id")
        d?.set(Date().timeIntervalSince1970, forKey: "pending_at")
    }
    private func clearPending() {
        let d = UserDefaults(suiteName: appGroupId)
        d?.removeObject(forKey: "pending_id")
        d?.removeObject(forKey: "pending_at")
    }

    // POST {zinc_base}/api/v1.0/Habit/{uid}/{versionId}/executions with the cached
    // bearer token. Mirrors the app's ExecutionRepository.complete (empty `{}` body).
    private func completeOnServer(versionId: String) async -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let base = defaults.string(forKey: "zinc_base"),
              let token = defaults.string(forKey: "zinc_token"),
              let uid = defaults.string(forKey: "zinc_uid"),
              var comps = URLComponents(string: base) else { return false }

        comps.path = "/api/v1.0/Habit/\(uid)/\(versionId)/executions"
        comps.query = nil
        guard let url = comps.url else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = "{}".data(using: .utf8)

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            NSLog("WIDGETCB POST \(url.absoluteString) -> \(code)")
            return (200...299).contains(code)
        } catch {
            NSLog("WIDGETCB POST error \(error.localizedDescription)")
            return false
        }
    }

    // Set the matching item's done flag in the shared schedule and adjust the count.
    private func setDone(versionId: String, done: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let raw = defaults.string(forKey: dataKey),
              let data = raw.data(using: .utf8),
              var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var items = obj["items"] as? [[String: Any]] else { return }

        var count = (obj["done"] as? Int) ?? 0
        for i in items.indices where (items[i]["id"] as? String) == versionId {
            let was = (items[i]["done"] as? Bool) ?? false
            if was != done {
                items[i]["done"] = done
                count += done ? 1 : -1
            }
        }
        obj["items"] = items
        obj["done"] = max(0, count)

        if let out = try? JSONSerialization.data(withJSONObject: obj),
           let str = String(data: out, encoding: .utf8) {
            defaults.set(str, forKey: dataKey)
        }
    }
}
