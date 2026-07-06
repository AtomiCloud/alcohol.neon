//
//  NeonWidget.swift
//  NeonWidget
//
//  "Today's habits" home-screen widget — shows the next habit due (advancing by
//  time of day), then a done-summary when nothing is left. Reads the shared App
//  Group that the Flutter app writes via home_widget. The "Complete" button POSTs
//  the completion directly to zinc (see CompleteHabitIntent).
//
//  Style: a forced-dark LazyTax card (near-black #171717, white text) with the logo
//  orange (#f97316) as the sole accent — distinct and branded on the home screen.
//

import AppIntents
import SwiftUI
import WidgetKit

// Per-landscape App Group, injected from the NEON_APP_GROUP build setting via Info.plist.
private let appGroupId =
    (Bundle.main.object(forInfoDictionaryKey: "NeonAppGroup") as? String) ?? "group.invalid"
private let dataKey = "today_schedule"

// Forced-dark LazyTax palette (the card is always dark, so colors are explicit
// rather than system-adaptive).
private let cardBG = Color(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x17 / 255.0)        // #171717
private let accent = Color(red: 0xF9 / 255.0, green: 0x73 / 255.0, blue: 0x16 / 255.0)        // #f97316 logo orange
private let textPrimary = Color.white
private let textSecondary = Color.white.opacity(0.55)
private let ringTrack = Color.white.opacity(0.15)

private struct HabitItem: Decodable { let id: String?; let time: String?; let name: String; let done: Bool }
private struct Schedule: Decodable { let date: String; let done: Int; let total: Int; let items: [HabitItem] }

private func loadSchedule() -> Schedule? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let raw = defaults.string(forKey: dataKey),
          let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(Schedule.self, from: data)
}

private func timeToDate(_ hm: String?, base: Date, cal: Calendar) -> Date? {
    guard let hm = hm else { return nil }
    let parts = hm.split(separator: ":")
    guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
    return cal.date(bySettingHour: h, minute: m, second: 0, of: base)
}

struct NeonEntry: TimelineEntry {
    let date: Date; let total: Int; let done: Int
    let nextId: String?; let nextName: String?; let nextTime: String?; let remaining: Int; let hasData: Bool
    var pending: Bool = false // the next habit is mid-save (POST in flight)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NeonEntry {
        NeonEntry(date: Date(), total: 3, done: 1, nextId: nil, nextName: "Morning run", nextTime: "06:30", remaining: 2, hasData: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (NeonEntry) -> Void) { completion(makeEntry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NeonEntry>) -> Void) {
        let cal = Calendar.current; let now = Date(); var dates: [Date] = [now]
        if let sched = loadSchedule() {
            for item in sched.items { if let d = timeToDate(item.time, base: now, cal: cal), d > now { dates.append(d) } }
        }
        dates.sort()
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        completion(Timeline(entries: dates.map { makeEntry(at: $0) }, policy: .after(nextMidnight)))
    }
    private func makeEntry(at date: Date) -> NeonEntry {
        guard let sched = loadSchedule() else {
            return NeonEntry(date: date, total: 0, done: 0, nextId: nil, nextName: nil, nextTime: nil, remaining: 0, hasData: false)
        }
        let cal = Calendar.current; var next: HabitItem?
        for item in sched.items where !item.done {
            if let t = timeToDate(item.time, base: date, cal: cal) { if t >= date { next = item; break } }
            else if next == nil { next = item }
        }
        if next == nil { next = sched.items.first(where: { !$0.done }) }
        let remaining = sched.items.filter { !$0.done }.count
        // "Saving…" only while the in-flight tap matches the next item and is recent
        // (guards against a killed perform() leaving a stuck pending marker).
        let d = UserDefaults(suiteName: appGroupId)
        let pendingId = d?.string(forKey: "pending_id")
        let pendingAt = d?.double(forKey: "pending_at") ?? 0
        let isPending = next?.id != nil && next?.id == pendingId && (Date().timeIntervalSince1970 - pendingAt) < 10
        return NeonEntry(date: date, total: sched.total, done: sched.done, nextId: next?.id, nextName: next?.name, nextTime: next?.time, remaining: remaining, hasData: true, pending: isPending)
    }
}

struct NeonWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    var body: some View {
        if !entry.hasData { empty }
        else if let name = entry.nextName { next(name: name) }
        else { summary }
    }
    private func next(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top: orange progress ring + "done/total" — the one sparing accent.
            HStack(spacing: 6) {
                progressRing
                Text("\(entry.done)/\(entry.total) done").font(.caption2.weight(.medium)).foregroundStyle(textSecondary)
                Spacer()
            }
            Spacer(minLength: 2)
            // Hero: the habit name in white.
            Text(name).font(family == .systemSmall ? .subheadline.weight(.semibold) : .title3.weight(.semibold)).foregroundStyle(textPrimary).lineLimit(2)
            if let t = entry.nextTime { Text(t).font(.caption).foregroundStyle(textSecondary) }
            Spacer(minLength: 4)
            completeButton
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // Thin ring: faint track + orange arc for today's completion fraction.
    private var progressRing: some View {
        let frac = entry.total > 0 ? CGFloat(entry.done) / CGFloat(entry.total) : 0
        return ZStack {
            Circle().stroke(ringTrack, lineWidth: 3)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
    }

    @ViewBuilder private var completeButton: some View {
        if #available(iOS 17.0, *), let id = entry.nextId {
            if entry.pending {
                // Mid-save: dimmed, non-tappable, clearly "in progress" (NOT done).
                HStack(spacing: 4) {
                    Image(systemName: "circle.dotted")
                    Text("Saving…").fontWeight(.semibold)
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(textSecondary)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // High-contrast primary on the dark card: white button, black text.
                Button(intent: CompleteHabitIntent(versionId: id)) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                        Text("Complete").fontWeight(.semibold)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(cardBG)
                    // Rounded-rectangle like the app's buttons (_ctrlRadius = 12).
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    private var summary: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(accent)
            Text(entry.total == 0 ? "No habits today" : "All done!").font(.headline).foregroundStyle(textPrimary)
            if entry.total > 0 { Text("\(entry.done)/\(entry.total) today").font(.caption).foregroundStyle(textSecondary) }
            Text("Nothing left").font(.caption2).foregroundStyle(textSecondary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    private var empty: some View {
        VStack(spacing: 6) { Image(systemName: "list.bullet.circle").font(.title).foregroundStyle(textSecondary); Text("Open the app").font(.caption).foregroundStyle(textSecondary) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NeonWidget: Widget {
    let kind: String = "NeonWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NeonWidgetEntryView(entry: entry)
                    .containerBackground(cardBG, for: .widget)
            } else {
                NeonWidgetEntryView(entry: entry)
                    .padding()
                    .background(cardBG)
            }
        }
        .configurationDisplayName("Today's habits")
        .description("Your next habit, and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    NeonWidget()
} timeline: {
    NeonEntry(date: .now, total: 3, done: 1, nextId: "demo", nextName: "Morning run", nextTime: "06:30", remaining: 2, hasData: true)
    NeonEntry(date: .now, total: 3, done: 3, nextId: nil, nextName: nil, nextTime: nil, remaining: 0, hasData: true)
}
