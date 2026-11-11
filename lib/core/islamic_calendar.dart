import 'package:hijri/hijri_calendar.dart';

/// An Islamic occasion and the Gregorian date it next falls on.
class IslamicEvent {
  /// Translation key under `prayer.` (e.g. `event_ramadan`).
  final String key;
  final DateTime date;

  /// For multi-day occasions (Ayyam al-Beed): the last day, else [date].
  final DateTime endDate;

  /// True for days the Sunnah encourages fasting on.
  final bool isFast;

  IslamicEvent(this.key, this.date, {DateTime? endDate, this.isFast = false})
    : endDate = endDate ?? date;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Gregorian date of [hDay]/[hMonth] in Hijri year [hYear], using the
/// `hijri` package's Umm al-Qura tables. Actual dates can differ by a day
/// from moon sighting.
DateTime hijriDate(int hYear, int hMonth, int hDay) =>
    _day(HijriCalendar().hijriToGregorian(hYear, hMonth, hDay));

/// Next occurrence (today or later) of a fixed Hijri date.
DateTime nextHijriDate(int hMonth, int hDay, {DateTime? from}) {
  final today = _day(from ?? DateTime.now());
  final h = HijriCalendar.fromDate(today);
  var d = hijriDate(h.hYear, hMonth, hDay);
  if (d.isBefore(today)) d = hijriDate(h.hYear + 1, hMonth, hDay);
  return d;
}

/// The next (or current) White Days, 13th to 15th of a Hijri month.
({DateTime start, DateTime end}) nextAyyamAlBeed({DateTime? from}) {
  final today = _day(from ?? DateTime.now());
  final h = HijriCalendar.fromDate(today);
  var y = h.hYear, m = h.hMonth;
  if (h.hDay > 15) {
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return (start: hijriDate(y, m, 13), end: hijriDate(y, m, 15));
}

/// Next Monday or Thursday after today.
DateTime nextMondayOrThursday({DateTime? from}) {
  var d = _day(from ?? DateTime.now()).add(const Duration(days: 1));
  while (d.weekday != DateTime.monday && d.weekday != DateTime.thursday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// The coming occasions, soonest first.
List<IslamicEvent> upcomingIslamicEvents({DateTime? from}) {
  final beed = nextAyyamAlBeed(from: from);
  final events = [
    IslamicEvent('event_ramadan', nextHijriDate(9, 1, from: from)),
    IslamicEvent('event_eid_fitr', nextHijriDate(10, 1, from: from)),
    IslamicEvent(
      'event_arafah',
      nextHijriDate(12, 9, from: from),
      isFast: true,
    ),
    IslamicEvent('event_eid_adha', nextHijriDate(12, 10, from: from)),
    IslamicEvent('event_new_year', nextHijriDate(1, 1, from: from)),
    IslamicEvent(
      'event_ashura',
      nextHijriDate(1, 10, from: from),
      isFast: true,
    ),
    IslamicEvent('event_beed', beed.start, endDate: beed.end, isFast: true),
    IslamicEvent(
      'event_mon_thu',
      nextMondayOrThursday(from: from),
      isFast: true,
    ),
  ];
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}
