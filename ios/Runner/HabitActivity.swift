//
//  HabitActivity.swift
//  Runner + NeonWidgetExtension
//
//  The "Next up" Live Activity's data and its Complete button. The app starts
//  and updates the activity (LiveActivityBridge); the widget extension draws it
//  (HabitLiveActivity). A LiveActivityIntent runs in the app's process, so the
//  button can update the activity directly after the zinc POST.
//

import ActivityKit
import AppIntents
import Foundation
import WidgetKit

@available(iOS 17.0, *)
struct HabitActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable { case open, saving, done, failed }

    /// The next open habit; the app swaps it in as habits get done.
    struct ContentState: Codable, Hashable {
        var versionId: String
        var name: String
        var deadline: Date
        var stake: String?
        var done: Int
        var total: Int
        var phase: Phase
    }
}

@available(iOS 17.0, *)
struct CompleteFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete habit"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit Version Id")
    var versionId: String

    init() {}
    init(versionId: String) { self.versionId = versionId }

    func perform() async throws -> some IntentResult {
        // Same confirm-first rule as the widget: never show done until zinc has it.
        await setPhase(.saving)
        let ok = await completeHabitOnServer(versionId: versionId)
        if ok {
            markScheduleItemDone(versionId: versionId)
            WidgetCenter.shared.reloadAllTimelines()
        }
        await setPhase(ok ? .done : .failed)
        return .result()
    }

    private func setPhase(_ phase: HabitActivityAttributes.Phase) async {
        for activity in Activity<HabitActivityAttributes>.activities
        where activity.content.state.versionId == versionId {
            var state = activity.content.state
            if phase == .done && state.phase != .done { state.done = min(state.total, state.done + 1) }
            state.phase = phase
            await activity.update(ActivityContent(state: state, staleDate: state.deadline))
        }
    }
}
