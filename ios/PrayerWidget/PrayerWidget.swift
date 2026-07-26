import WidgetKit
import SwiftUI

// iOS counterpart of the Android PrayerWidgetProvider: shows the next prayer
// and a live countdown to it. Reads the same key/value data the Dart side
// publishes through the home_widget plugin (which stores them in the shared
// App Group's UserDefaults on iOS), so lib/core/services/prayer_widget.dart
// feeds both platforms identically.

private let kAppGroupId = "group.com.abdelrahmanalhajs.quranapp"

struct PrayerEntry: TimelineEntry {
    let date: Date
    /// Next prayer's display name (already localized by the Dart side).
    let prayerName: String?
    /// The moment the next prayer starts (for the countdown).
    let prayerDate: Date?
    /// "Next prayer" header label (localized by the Dart side).
    let label: String
    /// Shown when no data exists yet (localized by the Dart side).
    let placeholder: String
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            prayerName: nil,
            prayerDate: nil,
            label: "الصلاة القادمة",
            placeholder: "افتح التطبيق لتحديد موقعك"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh when the shown prayer arrives (so the widget advances to
        // the following one), or in 30 minutes if we have no data.
        let refresh = entry.prayerDate ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func currentEntry() -> PrayerEntry {
        let defaults = UserDefaults(suiteName: kAppGroupId)
        let label = defaults?.string(forKey: "prayer_label") ?? "الصلاة القادمة"
        let placeholder =
            defaults?.string(forKey: "prayer_placeholder") ?? "افتح التطبيق لتحديد موقعك"

        guard
            let timesCsv = defaults?.string(forKey: "prayer_times"),
            let namesCsv = defaults?.string(forKey: "prayer_names")
        else {
            return PrayerEntry(
                date: Date(), prayerName: nil, prayerDate: nil,
                label: label, placeholder: placeholder)
        }

        let times = timesCsv.split(separator: ",").map(String.init)
        let names = namesCsv.split(separator: ",").map(String.init)
        guard times.count == names.count, !times.isEmpty else {
            return PrayerEntry(
                date: Date(), prayerName: nil, prayerDate: nil,
                label: label, placeholder: placeholder)
        }

        let now = Date()
        let calendar = Calendar.current

        func dateFor(_ hhmm: String, dayOffset: Int) -> Date? {
            let parts = hhmm.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: now)
            else { return nil }
            return calendar.date(
                bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }

        // First prayer later than now today; otherwise tomorrow's first.
        for (i, t) in times.enumerated() {
            if let d = dateFor(t, dayOffset: 0), d > now {
                return PrayerEntry(
                    date: now, prayerName: names[i], prayerDate: d,
                    label: label, placeholder: placeholder)
            }
        }
        if let d = dateFor(times[0], dayOffset: 1) {
            return PrayerEntry(
                date: now, prayerName: names[0], prayerDate: d,
                label: label, placeholder: placeholder)
        }
        return PrayerEntry(
            date: now, prayerName: nil, prayerDate: nil,
            label: label, placeholder: placeholder)
    }
}

struct PrayerWidgetView: View {
    var entry: PrayerEntry

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            if let name = entry.prayerName, let date = entry.prayerDate {
                Text(entry.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(date, style: .time)
                    .font(.subheadline)
                Text(timerInterval: Date()...date, countsDown: true)
                    .font(.caption)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text(entry.placeholder)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
    }
}

@main
struct PrayerWidget: Widget {
    let kind: String = "PrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                PrayerWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PrayerWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("الصلاة القادمة والوقت المتبقي لها")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
