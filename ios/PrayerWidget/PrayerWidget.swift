import WidgetKit
import SwiftUI

// iOS counterpart of the Android PrayerWidgetProvider / PrayerTimesWidgetProvider:
// shows today's prayer times, the next prayer and a live countdown to it.
// Reads the same key/value data the Dart side publishes through the
// home_widget plugin (stored in the shared App Group's UserDefaults on iOS),
// so lib/core/services/prayer_widget.dart feeds both platforms identically.
//
// Sizes: small (next prayer + countdown), medium (next prayer + countdown
// beside all five times), large (all five times, next one highlighted, plus
// the countdown), and the Lock Screen's circular / rectangular / inline
// accessory widgets.

private let kAppGroupId = "group.com.abdelrahmanalhajs.quranapp.shared"

struct PrayerEntry: TimelineEntry {
    let date: Date
    /// Localized prayer names (Fajr..Isha), already translated by Dart.
    let names: [String]
    /// "HH:mm" strings matching [names].
    let times: [String]
    /// Index into [names] of the next prayer, nil when there's no data.
    let nextIndex: Int?
    /// The moment the next prayer starts (for the countdown).
    let nextDate: Date?
    /// "Next prayer" header label (localized by Dart).
    let label: String
    /// Shown when no data exists yet (localized by Dart).
    let placeholder: String
    let isArabic: Bool

    var nextName: String? { nextIndex.map { names[$0] } }
    var nextTime: String? { nextIndex.map { times[$0] } }
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        // The widget gallery preview: show real data when there is some,
        // otherwise a sample so the user can see what each size looks like.
        let entry = currentEntry()
        completion(entry.nextIndex == nil && context.isPreview ? sampleEntry() : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh when the shown prayer arrives (so the widget advances to
        // the following one), or in 30 minutes if we have no data.
        let refresh = entry.nextDate.map { $0.addingTimeInterval(1) }
            ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func sampleEntry() -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            names: ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"],
            times: ["04:30", "11:55", "15:20", "17:50", "19:10"],
            nextIndex: 2,
            nextDate: Date().addingTimeInterval(75 * 60),
            label: "الصلاة القادمة",
            placeholder: "افتح التطبيق لتحديد موقعك",
            isArabic: true
        )
    }

    private func currentEntry() -> PrayerEntry {
        let defaults = UserDefaults(suiteName: kAppGroupId)
        let label = defaults?.string(forKey: "prayer_label") ?? "الصلاة القادمة"
        let placeholder =
            defaults?.string(forKey: "prayer_placeholder") ?? "افتح التطبيق لتحديد موقعك"
        let isArabic = (defaults?.string(forKey: "prayer_lang") ?? "ar") == "ar"

        func empty() -> PrayerEntry {
            PrayerEntry(
                date: Date(), names: [], times: [], nextIndex: nil, nextDate: nil,
                label: label, placeholder: placeholder,
                isArabic: isArabic)
        }

        guard
            let timesCsv = defaults?.string(forKey: "prayer_times"),
            let namesCsv = defaults?.string(forKey: "prayer_names")
        else { return empty() }

        let times = timesCsv.split(separator: ",").map(String.init)
        let names = namesCsv.split(separator: ",").map(String.init)
        guard times.count == names.count, !times.isEmpty else { return empty() }

        let now = Date()
        let calendar = Calendar.current

        func dateFor(_ hhmm: String, dayOffset: Int) -> Date? {
            let parts = hhmm.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2,
                  let day = calendar.date(byAdding: .day, value: dayOffset, to: now)
            else { return nil }
            return calendar.date(
                bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }

        func entry(_ i: Int, _ d: Date) -> PrayerEntry {
            PrayerEntry(
                date: now, names: names, times: times, nextIndex: i, nextDate: d,
                label: label, placeholder: placeholder,
                isArabic: isArabic)
        }

        // First prayer later than now today; otherwise tomorrow's first.
        for (i, t) in times.enumerated() {
            if let d = dateFor(t, dayOffset: 0), d > now { return entry(i, d) }
        }
        if let d = dateFor(times[0], dayOffset: 1) { return entry(0, d) }
        return empty()
    }
}

// MARK: - Views

private let accent = Color(red: 0.11, green: 0.49, blue: 0.36)

struct Countdown: View {
    let date: Date
    var body: some View {
        Text(timerInterval: Date()...max(date, Date()), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.center)
    }
}

struct PrayerRows: View {
    let entry: PrayerEntry
    var spacing: CGFloat = 4
    var font: Font = .subheadline

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(entry.names.indices, id: \.self) { i in
                let isNext = i == entry.nextIndex
                HStack {
                    Text(entry.names[i])
                    Spacer(minLength: 4)
                    Text(entry.times[i]).monospacedDigit()
                }
                .font(font.weight(isNext ? .bold : .regular))
                .foregroundColor(isNext ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isNext ? accent : Color.clear)
                )
            }
        }
    }
}

struct NextPrayerBlock: View {
    let entry: PrayerEntry
    var nameFont: Font = .title2

    var body: some View {
        VStack(spacing: 3) {
            Text(entry.label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(entry.nextName ?? "")
                .font(nameFont)
                .fontWeight(.bold)
                .foregroundColor(accent)
            Text(entry.nextTime ?? "")
                .font(.subheadline)
                .monospacedDigit()
            if let date = entry.nextDate {
                Countdown(date: date)
                    .font(.headline)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerEntry

    var body: some View {
        content
            .environment(\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private var content: some View {
        if entry.nextIndex == nil {
            placeholderView
        } else {
            switch family {
            case .systemSmall:
                NextPrayerBlock(entry: entry)
            case .systemMedium:
                HStack(spacing: 10) {
                    NextPrayerBlock(entry: entry, nameFont: .title3)
                        .frame(maxWidth: .infinity)
                    PrayerRows(entry: entry, spacing: 1, font: .caption)
                        .frame(maxWidth: .infinity)
                }
            case .systemLarge:
                VStack(spacing: 10) {
                    NextPrayerBlock(entry: entry)
                    Divider()
                    PrayerRows(entry: entry, spacing: 6, font: .body)
                    Spacer(minLength: 0)
                }
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(entry.nextName ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let date = entry.nextDate {
                        Countdown(date: date)
                            .font(.system(size: 12, weight: .bold))
                            .minimumScaleFactor(0.5)
                    }
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.nextName ?? "") \(entry.nextTime ?? "")")
                        .font(.headline)
                        .lineLimit(1)
                    if let date = entry.nextDate {
                        Countdown(date: date)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                Text("\(entry.nextName ?? "") \(entry.nextTime ?? "")")
            default:
                NextPrayerBlock(entry: entry)
            }
        }
    }

    private var placeholderView: some View {
        Text(entry.placeholder)
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
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
                    .padding()
            }
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("مواقيت الصلاة والوقت المتبقي للصلاة القادمة")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}
