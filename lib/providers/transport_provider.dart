import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/transport.dart';
import '../utils/bn.dart';

/// State for the bus seat-booking demo: one shared seat list that the app,
/// online sales and counters all read, plus a simulated live feed.
///
/// In the real app this list lives on a server (see README, "Live seat
/// booking"). Here it is simulated on the phone and every screen that uses it
/// is marked as a demo.
class TransportProvider extends ChangeNotifier {
  TransportProvider({List<DemoTrip> trips = const []}) : _trips = trips;

  List<DemoTrip> _trips;
  final _random = Random();
  Timer? _timer;
  int _listeners = 0;

  /// Demo minutes since the screen opened; moves 1 per tick.
  int tick = 0;

  /// Seats sold since the app opened, per trip and day ("id:day").
  final Map<String, Set<String>> _extraSold = {};

  /// Seats held for counter payment.
  final Map<String, Set<String>> _held = {};

  /// The seats this user has picked on the open trip.
  final List<String> picked = [];
  String? _pickedKey;

  /// The last simulated sale, for the live strip.
  String lastSale = '';

  void setTrips(List<DemoTrip> trips) => _trips = trips;

  List<DemoTrip> get trips => _trips;

  /// Screens call this in initState and [stopLive] in dispose.
  void startLive() {
    _listeners++;
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  void stopLive() {
    _listeners = max(0, _listeners - 1);
    if (_listeners == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static String key(DemoTrip t, int day) => '${t.id}:$day';

  static List<String> seatIds(int rows) => [
        for (final r in 'ABCDEFGHIJKL'.substring(0, rows.clamp(1, 12)).split(''))
          for (var c = 1; c <= 4; c++) '$r$c',
      ];

  static int _hash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Seats already sold before the screen opened, stable per trip and day.
  Set<String> _baseSold(DemoTrip t, int day) {
    final ratio = day == 0 ? 0.5 : (day == 1 ? 0.3 : 0.15);
    var seed = _hash('${t.name}|${t.time}|$day');
    final out = <String>{};
    for (final id in seatIds(t.rows)) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      if (seed / 4294967296 < ratio) out.add(id);
    }
    return out;
  }

  Set<String> sold(DemoTrip t, int day) =>
      {..._baseSold(t, day), ...?_extraSold[key(t, day)]};

  Set<String> held(DemoTrip t, int day) => _held[key(t, day)] ?? const {};

  int freeCount(DemoTrip t, int day) {
    final taken = {...sold(t, day), ...held(t, day)};
    return seatIds(t.rows).where((s) => !taken.contains(s)).length;
  }

  /// Booking is closed once today's bus has left.
  bool canBook(DemoTrip t, int day) {
    if (t.fare == 0 && t.rows == 0) return false;
    if (day == 0 && liveState(t).isRunning) return false;
    return true;
  }

  void togglePick(DemoTrip t, int day, String seat, {required void Function(String) onError}) {
    final k = key(t, day);
    if (_pickedKey != k) {
      picked.clear();
      _pickedKey = k;
    }
    if (picked.contains(seat)) {
      picked.remove(seat);
    } else if (picked.length >= 4) {
      onError('একবারে সর্বোচ্চ ৪টি সিট নেওয়া যায়।');
      return;
    } else {
      picked.add(seat);
    }
    notifyListeners();
  }

  List<String> pickedFor(DemoTrip t, int day) => _pickedKey == key(t, day) ? picked : const [];

  void clearPicked() {
    picked.clear();
    _pickedKey = null;
    notifyListeners();
  }

  /// Marks the user's seats as sold (paid online) or held (pay at counter).
  void confirm(DemoTrip t, int day, List<String> seats, {required bool paid}) {
    final k = key(t, day);
    (paid ? _extraSold : _held).putIfAbsent(k, () => <String>{}).addAll(seats);
    clearPicked();
  }

  void _tick() {
    tick++;
    if (_trips.isNotEmpty) {
      final t = _trips[_random.nextInt(_trips.length)];
      if (canBook(t, 0)) {
        final taken = {...sold(t, 0), ...held(t, 0), ...pickedFor(t, 0)};
        final free = seatIds(t.rows).where((s) => !taken.contains(s)).toList();
        if (free.length > 4) {
          final seat = free[_random.nextInt(free.length)];
          _extraSold.putIfAbsent(key(t, 0), () => <String>{}).add(seat);
          const via = ['অ্যাপে', 'অনলাইনে', 'কাউন্টারে'];
          lastSale = '${t.name}: সিট $seat এইমাত্র ${via[_random.nextInt(via.length)]} বিক্রি হলো';
        }
      }
    }
    notifyListeners();
  }

  /// Where the bus is now, from the trip's demo "live" settings.
  LiveState liveState(DemoTrip t) {
    final l = t.live;
    final st = (l['st'] ?? 'none').toString();
    final stops = t.stops;
    final late = (l['late'] as num?)?.toInt() ?? 0;
    switch (st) {
      case 'run':
        final p = ((l['p'] as num?)?.toDouble() ?? 0) + tick * ((l['v'] as num?)?.toDouble() ?? 0.04);
        final last = max(0, stops.length - 1);
        final pos = p.clamp(0, last.toDouble());
        final at = pos.floor();
        final next = min(at + 1, last);
        return LiveState(
          kind: LiveKind.running,
          position: pos.toDouble(),
          headline: pos >= last ? '${stops.isEmpty ? '' : stops[last].name} পৌঁছেছে' : '${stops[at].name} পার হয়েছে',
          detail: pos >= last ? '' : 'এখন ${stops[next].name} এর পথে',
          late: late,
        );
      case 'freq':
        final every = (l['every'] as num?)?.toInt() ?? 30;
        final eta = (((l['eta'] as num?)?.toInt() ?? 0) - tick) % every;
        return LiveState(
          kind: LiveKind.frequent,
          position: 0,
          headline: 'পরের বাস ${durationBn(eta < 0 ? eta + every : eta)} পরে',
          detail: 'প্রতি ${bn(every)} মিনিট পরপর ছাড়ে',
          late: 0,
        );
      case 'wait':
        final at = (l['at'] as num?)?.toInt() ?? 0;
        final eta = ((l['eta'] as num?)?.toInt() ?? 0) - tick;
        final where = stops.isEmpty ? '' : stops[min(at, stops.length - 1)].name;
        if (eta <= 0) {
          return LiveState(
            kind: LiveKind.boarding,
            position: at.toDouble(),
            headline: '$where এ দাঁড়িয়ে আছে, যাত্রী উঠছে',
            detail: '',
            late: late,
          );
        }
        return LiveState(
          kind: LiveKind.waiting,
          position: at.toDouble() - 0.4,
          headline: '${(l['arr'] ?? '').toString().isEmpty ? '$where এ' : l['arr']} পৌঁছাবে ${durationBn(eta)} পরে',
          detail: (l['from'] ?? '').toString(),
          late: late,
        );
      default:
        return const LiveState(kind: LiveKind.none, position: 0, headline: 'লাইভ লোকেশন নেই', detail: '', late: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum LiveKind { none, waiting, boarding, running, frequent }

class LiveState {
  const LiveState({
    required this.kind,
    required this.position,
    required this.headline,
    required this.detail,
    required this.late,
  });

  final LiveKind kind;

  /// Stop index; a fraction means between two stops.
  final double position;
  final String headline;
  final String detail;
  final int late;

  bool get isRunning => kind == LiveKind.running;
}
