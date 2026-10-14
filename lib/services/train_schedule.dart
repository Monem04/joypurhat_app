import '../models/transport.dart';
import '../utils/bn.dart';

/// A train leaving (or reaching) Joypurhat at a given moment.
class Departure {
  const Departure({
    required this.train,
    required this.run,
    required this.at,
    required this.minutesAway,
    required this.offToday,
  });

  final Train train;
  final TrainRun run;
  final DateTime at;

  /// Negative when the train left a few minutes ago.
  final int minutesAway;

  /// The weekly off day falls on this date (counted at the starting station).
  final bool offToday;

  String get when {
    if (minutesAway < 0) return 'এইমাত্র ছেড়েছে';
    if (minutesAway == 0) return 'এখন';
    if (minutesAway < 60 * 12) return '${durationBn(minutesAway)} পরে';
    return dayLabelBn(at);
  }
}

/// Where a train goes, grouped for the filter chips.
String directionGroup(String to) {
  if (to == 'ঢাকা') return 'ঢাকা';
  if (to == 'রাজশাহী') return 'রাজশাহী';
  if (to == 'খুলনা') return 'খুলনা';
  return 'উত্তরে';
}

const directionFilters = ['সব', 'ঢাকা', 'রাজশাহী', 'খুলনা', 'উত্তরে'];

/// The next 24 hours of trains at Joypurhat, soonest first. A train that
/// left up to [graceMinutes] ago stays on the list, marked as just left.
List<Departure> upcomingDepartures(
  List<Train> trains,
  DateTime now, {
  String filter = 'সব',
  int graceMinutes = 5,
}) {
  final out = <Departure>[];
  final today = DateTime(now.year, now.month, now.day);
  final nowMin = now.hour * 60 + now.minute;
  for (final t in trains) {
    for (final r in t.runs) {
      if (filter != 'সব' && directionGroup(r.to) != filter) continue;
      final m = parseHm(r.time);
      if (m == null) continue;
      var day = today;
      var away = m - nowMin;
      if (away < -graceMinutes) {
        day = today.add(const Duration(days: 1));
        away += 24 * 60;
      }
      final at = day.add(Duration(minutes: m));
      out.add(Departure(
        train: t,
        run: r,
        at: at,
        minutesAway: away,
        offToday: r.offDay != null && r.offDay == weekdayIndex(at),
      ));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// "শুক্রবার" for a run's off day, or a note when unknown.
String offDayText(TrainRun r) {
  if (r.offConflict) return 'মঙ্গল বা বুধবার (উৎস ভেদে)';
  if (r.offDay == null) return 'নেই, প্রতিদিন চলে';
  return weekdaysBn[r.offDay!];
}

/// "16:53" -> "বিকাল ৪:৫৩"
String hmBn(String hm) {
  final m = parseHm(hm);
  if (m == null) return '';
  return clockBn(m ~/ 60, m % 60);
}
