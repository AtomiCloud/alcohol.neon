//
//  NeonWidget.swift
//  NeonWidget
//
//  "Today" home-screen widget in the glass style of the Today screen:
//  - small: the next habit (soonest deadline), time left and its proof.
//  - medium: today's ring plus up to three open habits; check-in habits get a
//    Complete button, NFC habits show the tag icon (scanning needs the app).
//  Reads the plan the app writes into the shared App Group via home_widget
//  (WidgetService.sync). Complete POSTs to zinc through CompleteHabitIntent.
//  Tinted and clear Home Screens (accented rendering) keep the accent parts
//  accentable and drop the card colour.
//

import AppIntents
import SwiftUI
import WidgetKit

// Per-landscape App Group, injected from the NEON_APP_GROUP build setting via Info.plist.
private let appGroupId =
    (Bundle.main.object(forInfoDictionaryKey: "NeonAppGroup") as? String) ?? "group.invalid"
private let dataKey = "today_schedule"

// Same emerald as the Today screen and the Live Activity, on a dark glass card.
private let glassBG = Color(red: 0x16 / 255.0, green: 0x18 / 255.0, blue: 0x17 / 255.0)
private let wAccent = Color(red: 0x34 / 255.0, green: 0xD3 / 255.0, blue: 0x99 / 255.0)
private let wMuted = Color.white.opacity(0.6)
private let wTrack = Color.white.opacity(0.12)

// MARK: - Data

private struct StoredItem: Decodable {
    let id: String?
    let name: String
    let done: Bool
    let deadline: String?
    let proof: String?
}
private struct StoredSchedule: Decodable { let done: Int; let total: Int; let items: [StoredItem] }

struct WidgetHabit: Hashable {
    let id: String?
    let name: String
    let deadline: Date?
    let nfc: Bool
}

private func parseDate(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

private func loadSchedule() -> (done: Int, total: Int, open: [WidgetHabit])? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let raw = defaults.string(forKey: dataKey),
          let data = raw.data(using: .utf8),
          let s = try? JSONDecoder().decode(StoredSchedule.self, from: data) else { return nil }
    let open = s.items.filter { !$0.done }.map {
        WidgetHabit(id: $0.id, name: $0.name, deadline: parseDate($0.deadline), nfc: $0.proof == "nfc")
    }
    return (s.done, s.total, open)
}

private func hm(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}

// MARK: - Timeline

struct NeonEntry: TimelineEntry {
    let date: Date
    let total: Int
    let done: Int
    /// Habits still open at `date`, soonest deadline first.
    let open: [WidgetHabit]
    let hasData: Bool
    var pendingId: String? = nil // a Complete POST is in flight for this version

    var next: WidgetHabit? { open.first }
}

struct Provider: TimelineProvider {
    static let sample = NeonEntry(
        date: .now, total: 6, done: 2,
        open: [
            WidgetHabit(id: "a", name: "Run 5 km", deadline: .now.addingTimeInterval(7_500), nfc: false),
            WidgetHabit(id: "b", name: "Write in journal", deadline: .now.addingTimeInterval(11_000), nfc: true),
            WidgetHabit(id: "c", name: "Stretch 10 min", deadline: .now.addingTimeInterval(14_000), nfc: false),
        ],
        hasData: true)

    func placeholder(in context: Context) -> NeonEntry { Self.sample }
    func getSnapshot(in context: Context, completion: @escaping (NeonEntry) -> Void) {
        completion(context.isPreview && loadSchedule() == nil ? Self.sample : makeEntry(at: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NeonEntry>) -> Void) {
        let now = Date()
        // A new entry whenever an open habit's check closes, so it drops off.
        var dates = [now]
        for h in loadSchedule()?.open ?? [] { if let d = h.deadline, d > now { dates.append(d) } }
        dates.sort()
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        completion(Timeline(entries: dates.map { makeEntry(at: $0) }, policy: .after(midnight)))
    }

    private func makeEntry(at date: Date) -> NeonEntry {
        guard let s = loadSchedule() else {
            return NeonEntry(date: date, total: 0, done: 0, open: [], hasData: false)
        }
        let open = s.open.filter { ($0.deadline ?? .distantFuture) > date }
        // "Saving…" only while the tap is recent, so a killed intent can't stick.
        let d = UserDefaults(suiteName: appGroupId)
        let recent = Date().timeIntervalSince1970 - (d?.double(forKey: "pending_at") ?? 0) < 10
        return NeonEntry(date: date, total: s.total, done: s.done, open: open, hasData: true,
                         pendingId: recent ? d?.string(forKey: "pending_id") : nil)
    }
}

// MARK: - Views

private struct WidgetRing: View {
    let done: Int
    let total: Int
    let size: CGFloat
    let line: CGFloat
    var body: some View {
        let frac = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        ZStack {
            Circle().stroke(wTrack, lineWidth: line)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(wAccent, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .frame(width: size, height: size)
    }
}

private struct ProofLabel: View {
    let habit: WidgetHabit
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: habit.nfc ? "wave.3.right" : "checkmark")
            Text(habit.nfc ? "NFC tag" : "Check-in")
        }
    }
}

/// The open-habit row of the medium widget: a Complete circle for check-ins,
/// the tag icon for NFC (it can only be proven by scanning in the app).
private struct HabitRow: View {
    let habit: WidgetHabit
    let pending: Bool
    var body: some View {
        HStack(spacing: 9) {
            lead.frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name).font(.caption.weight(.semibold)).lineLimit(1)
                Group {
                    if pending { Text("Saving…") }
                    else if let d = habit.deadline { Text("\(habit.nfc ? "NFC tag" : "Check-in") · by \(hm(d))") }
                    else { Text(habit.nfc ? "NFC tag" : "Check-in") }
                }
                .font(.caption2).foregroundStyle(wMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var lead: some View {
        if habit.nfc {
            Image(systemName: "wave.3.right").font(.caption.weight(.semibold)).foregroundStyle(wMuted)
        } else if pending {
            Image(systemName: "circle.dotted").font(.system(size: 20)).foregroundStyle(wMuted)
        } else if #available(iOS 17.0, *), let id = habit.id {
            Button(intent: CompleteHabitIntent(versionId: id)) {
                Circle().strokeBorder(wAccent, lineWidth: 1.6).widgetAccentable()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(habit.name)")
        } else {
            Circle().strokeBorder(wAccent, lineWidth: 1.6).widgetAccentable()
        }
    }
}

struct NeonWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if !entry.hasData { empty }
            else if family == .systemMedium { medium }
            else { small }
        }
        .foregroundStyle(.white)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.next == nil ? "Today" : "Next up")
                    .font(.caption.weight(.bold)).foregroundStyle(wAccent).widgetAccentable()
                Spacer()
                WidgetRing(done: entry.done, total: entry.total, size: 18, line: 3.5)
            }
            Spacer(minLength: 4)
            if let n = entry.next {
                Text(n.name).font(.headline.weight(.bold)).lineLimit(2).minimumScaleFactor(0.85)
                if let d = n.deadline {
                    (Text(d, style: .relative) + Text(" left"))
                        .font(.caption2).foregroundStyle(wMuted).lineLimit(1)
                }
                ProofLabel(habit: n).font(.caption2).foregroundStyle(wMuted).padding(.top, 4)
            } else {
                Text(entry.total == 0 ? "No habits today" : "All done for today")
                    .font(.headline.weight(.bold)).lineLimit(2)
                Text("\(entry.done) of \(entry.total) done").font(.caption2).foregroundStyle(wMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                ZStack {
                    WidgetRing(done: entry.done, total: entry.total, size: 58, line: 6)
                    Text("\(entry.done)/\(entry.total)").font(.subheadline.weight(.bold)).monospacedDigit()
                }
                .padding(.bottom, 6)
                Text("Today").font(.subheadline.weight(.bold)).foregroundStyle(wAccent).widgetAccentable()
                Group {
                    if let d = entry.next?.deadline { Text("Next by \(hm(d))") }
                    else if entry.next == nil { Text("All done") }
                }
                .font(.caption2).foregroundStyle(wMuted).lineLimit(1)
            }
            .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                if entry.open.isEmpty {
                    Text(entry.total == 0 ? "No habits today" : "Nothing left today")
                        .font(.caption).foregroundStyle(wMuted).padding(.top, 6)
                } else {
                    ForEach(entry.open.prefix(3), id: \.self) { h in
                        HabitRow(habit: h, pending: h.id != nil && h.id == entry.pendingId)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist").font(.title2).foregroundStyle(wAccent).widgetAccentable()
            Text("Open LazyTax to load today").font(.caption).foregroundStyle(wMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NeonWidget: Widget {
    let kind: String = "NeonWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NeonWidgetEntryView(entry: entry)
                    .containerBackground(glassBG, for: .widget)
            } else {
                NeonWidgetEntryView(entry: entry)
                    .padding()
                    .background(glassBG)
            }
        }
        .configurationDisplayName("Today")
        .description("Your next habit and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    NeonWidget()
} timeline: {
    Provider.sample
    NeonEntry(date: .now, total: 6, done: 6, open: [], hasData: true)
}
