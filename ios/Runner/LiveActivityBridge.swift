//
//  LiveActivityBridge.swift
//  Runner
//
//  `neon/live_activity` method channel: the Flutter app sends the next open
//  habit after each Today load ("sync"), or "end" when nothing is left or the
//  user signs out. One activity at a time; it's updated in place.
//

import ActivityKit
import Flutter
import Foundation

enum LiveActivityBridge {
    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "neon/live_activity", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 17.0, *) else { result(nil); return }
            Task { @MainActor in
                switch call.method {
                case "sync": await sync(call.arguments as? [String: Any])
                case "end": await endAll()
                default: result(FlutterMethodNotImplemented); return
                }
                result(nil)
            }
        }
    }

    @available(iOS 17.0, *)
    private static var live: [Activity<HabitActivityAttributes>] {
        Activity<HabitActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    @available(iOS 17.0, *)
    private static func sync(_ args: [String: Any]?) async {
        guard let a = args,
              let versionId = a["versionId"] as? String,
              let name = a["name"] as? String,
              let deadlineMs = (a["deadlineMs"] as? NSNumber)?.doubleValue else { return }
        let state = HabitActivityAttributes.ContentState(
            versionId: versionId,
            name: name,
            deadline: Date(timeIntervalSince1970: deadlineMs / 1000),
            stake: a["stake"] as? String,
            done: (a["done"] as? NSNumber)?.intValue ?? 0,
            total: (a["total"] as? NSNumber)?.intValue ?? 0,
            phase: .open
        )
        let content = ActivityContent(state: state, staleDate: state.deadline)
        let current = live
        if let first = current.first {
            for extra in current.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            if first.content.state != state { await first.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: HabitActivityAttributes(), content: content, pushType: nil)
        } catch {
            NSLog("LIVEACTIVITY request failed: \(error.localizedDescription)")
        }
    }

    @available(iOS 17.0, *)
    private static func endAll() async {
        for activity in live { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
