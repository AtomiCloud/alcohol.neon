//
//  HabitLiveActivity.swift
//  NeonWidget
//
//  The "Next up" Live Activity on the Lock Screen and in the Dynamic Island:
//  the next open habit, a live countdown to its deadline and one Complete
//  button. Colours follow the glass Today screen (emerald on near-black).
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let emerald = Color(red: 0x34 / 255.0, green: 0xD3 / 255.0, blue: 0x99 / 255.0)
private let onEmerald = Color(red: 0x05 / 255.0, green: 0x2E / 255.0, blue: 0x1B / 255.0)
private let muted = Color.white.opacity(0.62)

private typealias State = HabitActivityAttributes.ContentState

/// Counts down to the deadline; the system keeps it ticking without updates.
private struct Countdown: View {
    let deadline: Date
    var body: some View {
        Text(timerInterval: min(Date(), deadline)...deadline, countsDown: true)
            .monospacedDigit()
    }
}

private struct Ring: View {
    let done: Int, total: Int
    var size: CGFloat = 18
    var body: some View {
        let frac = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        ZStack {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
            Circle().trim(from: 0, to: frac)
                .stroke(emerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

/// Complete while open; then Saving…, Done, or Try again after a failure.
private struct CompleteButton: View {
    let state: State
    var body: some View {
        switch state.phase {
        case .saving:
            label("Saving…", icon: "circle.dotted", fg: muted, bg: Color.white.opacity(0.12))
        case .done:
            label("Done", icon: "checkmark.circle.fill", fg: emerald, bg: emerald.opacity(0.16))
        case .open, .failed:
            Button(intent: CompleteFromActivityIntent(versionId: state.versionId)) {
                label(state.phase == .failed ? "Couldn't save · Try again" : "Complete",
                      icon: state.phase == .failed ? "arrow.clockwise" : "checkmark",
                      fg: onEmerald, bg: emerald)
            }
            .buttonStyle(.plain)
        }
    }

    private func label(_ text: String, icon: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(bg, in: Capsule())
    }
}

private struct LockScreenView: View {
    let state: State
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Ring(done: state.done, total: state.total, size: 14)
                        Text("Next up · \(state.done)/\(state.total) done")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(emerald)
                    }
                    Text(state.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let stake = state.stake {
                        Text(stake).font(.caption).foregroundStyle(muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Countdown(deadline: state.deadline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                    Text("left").font(.caption2).foregroundStyle(muted)
                }
            }
            CompleteButton(state: state)
        }
        .padding(16)
    }
}

struct HabitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.04, green: 0.06, blue: 0.05).opacity(0.78))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next up").font(.caption2.weight(.semibold)).foregroundStyle(emerald)
                        Text(s.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Countdown(deadline: s.deadline)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90, alignment: .trailing)
                        Text("\(s.done)/\(s.total) done").font(.caption2).foregroundStyle(muted)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CompleteButton(state: s).padding(.top, 4)
                }
            } compactLeading: {
                Ring(done: s.done, total: s.total)
            } compactTrailing: {
                Countdown(deadline: s.deadline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(emerald)
                    // Fits "10:01:53" (over an hour left), not just "59:59".
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 64)
            } minimal: {
                Ring(done: s.done, total: s.total)
            }
            .keylineTint(emerald)
        }
    }
}

#Preview("Lock Screen", as: .content, using: HabitActivityAttributes()) {
    HabitLiveActivity()
} contentStates: {
    State(versionId: "v1", name: "Run 5 km", deadline: .now.addingTimeInterval(6840),
          stake: "SGD 5.00 to Furkids if you miss", done: 2, total: 5, phase: .open)
    State(versionId: "v1", name: "Run 5 km", deadline: .now.addingTimeInterval(6840),
          stake: nil, done: 3, total: 5, phase: .done)
}
