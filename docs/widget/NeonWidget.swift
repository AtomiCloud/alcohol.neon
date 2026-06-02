//
//  PARKED — see docs/widget/README.md. LazyTax "today's habits" home-screen widget.
//  Shows the next habit due (advancing by time), then a done-summary. Restore into
//  the NeonWidget extension target when re-adding the widget (needs an App Group).
//

import WidgetKit
import SwiftUI

private let appGroupId = "group.cloud.atomi.alcoholNeon"
private let dataKey = "today_schedule"
private let brand = Color(red: 0x05 / 255.0, green: 0x96 / 255.0, blue: 0x69 / 255.0) // emerald-600

private struct HabitItem: Decodable { let time: String?; let name: String; let done: Bool }
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
    let nextName: String?; let nextTime: String?; let remaining: Int; let hasData: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NeonEntry {
        NeonEntry(date: Date(), total: 3, done: 1, nextName: "Morning run", nextTime: "06:30", remaining: 2, hasData: true)
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
            return NeonEntry(date: date, total: 0, done: 0, nextName: nil, nextTime: nil, remaining: 0, hasData: false)
        }
        let cal = Calendar.current; var next: HabitItem?
        for item in sched.items where !item.done {
            if let t = timeToDate(item.time, base: date, cal: cal) { if t >= date { next = item; break } }
            else if next == nil { next = item }
        }
        if next == nil { next = sched.items.first(where: { !$0.done }) }
        let remaining = sched.items.filter { !$0.done }.count
        return NeonEntry(date: date, total: sched.total, done: sched.done, nextName: next?.name, nextTime: next?.time, remaining: remaining, hasData: true)
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
            HStack { Text("NEXT UP").font(.caption2.weight(.bold)).foregroundStyle(.secondary); Spacer(); Text("\(entry.done)/\(entry.total)").font(.caption2).foregroundStyle(.secondary) }
            Spacer()
            if let t = entry.nextTime { Text(t).font(.system(size: family == .systemSmall ? 22 : 28, weight: .bold)).foregroundStyle(brand) }
            Text(name).font(family == .systemSmall ? .headline : .title3.weight(.semibold)).lineLimit(2)
            if family != .systemSmall { Text("\(entry.remaining) habit\(entry.remaining == 1 ? "" : "s") left today").font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var summary: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(brand)
            Text(entry.total == 0 ? "No habits today" : "All done!").font(.headline)
            if entry.total > 0 { Text("\(entry.done)/\(entry.total) today").font(.caption).foregroundStyle(.secondary) }
            Text("Nothing left").font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    private var empty: some View {
        VStack(spacing: 6) { Image(systemName: "list.bullet.circle").font(.title).foregroundStyle(.secondary); Text("Open LazyTax").font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NeonWidget: Widget {
    let kind: String = "NeonWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NeonWidgetEntryView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's habits")
        .description("Your next habit, and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
