import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';

/// Bookings, requests and tickets, saved on this phone.
class BookingProvider extends ChangeNotifier {
  static const _key = 'bookings.v1';
  final _random = Random();

  List<Booking> _items = [];
  List<Booking> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        _items = (jsonDecode(raw) as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Bookings load failed: $e');
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_items.map((b) => b.toJson()).toList()));
  }

  String newId() => '${DateTime.now().millisecondsSinceEpoch}${_random.nextInt(1000)}';

  /// A short code people can read out on the phone, like JP-4821.
  String newCode(String prefix) => '$prefix-${1000 + _random.nextInt(9000)}';

  int newSerial() => 3 + _random.nextInt(18);

  Future<void> add(Booking b) async {
    _items = [b, ..._items];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _items = _items.where((b) => b.id != id).toList();
    notifyListeners();
    await _save();
  }
}
