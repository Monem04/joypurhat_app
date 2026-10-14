import '../models/transport.dart';
import '../utils/bn.dart';
import 'train_schedule.dart';

/// Where a train should be now if it runs on time, worked out from its
/// Joypurhat time and the usual running minutes between stations. This is
/// an estimate, not a live feed; the railway's SMS service gives the real
/// position.
class LiveEstimate {
  const LiveEstimate({
    required this.headline,
    required this.detail,
    required this.x,
    required this.y,
    required this.stationTimes,
    required this.passed,
    required this.onLine,
  });

  final String headline;
  final String detail;

  /// Marker position on the drawn map, percent of width and height.
  final double x;
  final double y;

  /// Expected clock time at each station of the line, in line order.
  final List<DateTime> stationTimes;

  /// Whether the train has passed each station.
  final List<bool> passed;

  /// False when the train is outside the drawn part of the line.
  final bool onLine;
}

/// Trains to Dhaka, Rajshahi and Khulna run south through Joypurhat.
bool goesSouth(TrainRun r) => directionGroup(r.to) != 'উত্তরে';

/// Minutes from [a] to [b] on a 24-hour clock, between -720 and 719.
int _wrap(int minutes) => ((minutes + 720) % 1440 + 1440) % 1440 - 720;

LiveEstimate? estimatePosition(List<LineStation> line, TrainRun run, DateTime now) {
  final t = parseHm(run.time);
  if (t == null || line.length < 2) return null;
  final south = goesSouth(run);
  final nowMin = now.hour * 60 + now.minute + now.second / 60;
  final offset = _wrap((nowMin - t).round());
  // Position in "minutes north of Joypurhat" along the line.
  final p = south ? -offset.toDouble() : offset.toDouble();

  final base = DateTime(now.year, now.month, now.day).add(Duration(minutes: (nowMin - offset).round()));
  final times = [
    for (final s in line) base.add(Duration(minutes: south ? -s.min : s.min)),
  ];
  final passed = [for (final s in line) south ? s.min > p : s.min < p];

  final north = line.first, last = line.last;
  final joy = line.firstWhere((s) => s.min == 0, orElse: () => line[line.length ~/ 2]);
  final toJoy = offset < 0
      ? 'জয়পুরহাট পৌঁছাবে ${durationBn(-offset)} পরে, আনুমানিক ${hmBnOf(times[line.indexOf(joy)])}'
      : (offset == 0 ? 'এখন জয়পুরহাট স্টেশনে থাকার কথা' : 'জয়পুরহাট ছেড়েছে ${durationBn(offset)} আগে');

  if (p > north.min || p < last.min) {
    // Outside the drawn stretch: before it, or already past it.
    final beforeEnd = south ? (p > north.min ? north : null) : (p < last.min ? last : null);
    final pastEnd = south ? (p < last.min ? last : null) : (p > north.min ? north : null);
    final end = beforeEnd ?? pastEnd!;
    return LiveEstimate(
      headline: beforeEnd != null ? 'ট্রেন এখন ${_short(end.name)}ের আগে' : 'ট্রেন ${_short(end.name)} পার হয়েছে',
      detail: toJoy,
      x: end.x,
      y: end.y,
      stationTimes: times,
      passed: passed,
      onLine: false,
    );
  }

  // Between two stations, a (north) and b (south).
  var i = 0;
  while (i + 1 < line.length && line[i + 1].min >= p) {
    i++;
  }
  final a = line[i];
  final b = line[i + 1 < line.length ? i + 1 : i];
  final span = (a.min - b.min).toDouble();
  final f = span == 0 ? 0.0 : (a.min - p) / span;
  final x = a.x + (b.x - a.x) * f;
  final y = a.y + (b.y - a.y) * f;
  final String headline;
  if ((a.min - p).abs() <= 1) {
    headline = 'ট্রেন এখন ${a.name} স্টেশনে';
  } else if ((b.min - p).abs() <= 1) {
    headline = 'ট্রেন এখন ${b.name} স্টেশনে';
  } else {
    final from = south ? a : b, to = south ? b : a;
    headline = 'ট্রেন ${from.name} পার হয়েছে, পরের স্টেশন ${to.name}';
  }
  return LiveEstimate(
    headline: headline,
    detail: toJoy,
    x: x,
    y: y,
    stationTimes: times,
    passed: passed,
    onLine: true,
  );
}

/// "পার্বতীপুর জংশন" -> "পার্বতীপুর" for short sentences.
String _short(String name) => name.replaceAll(' জংশন', '');

String hmBnOf(DateTime d) => clockBn(d.hour, d.minute);
