import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's name and number, kept only on this phone to fill forms.
class ProfileProvider extends ChangeNotifier {
  static const _kName = 'profile.name';
  static const _kPhone = 'profile.phone';
  static const _kUpazila = 'profile.upazila';

  String name = '';
  String phone = '';
  String upazila = '';

  bool get isEmpty => name.isEmpty && phone.isEmpty;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      name = p.getString(_kName) ?? '';
      phone = p.getString(_kPhone) ?? '';
      upazila = p.getString(_kUpazila) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
  }

  Future<void> save({required String name, required String phone, required String upazila}) async {
    this.name = name.trim();
    this.phone = phone.trim();
    this.upazila = upazila;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, this.name);
    await p.setString(_kPhone, this.phone);
    await p.setString(_kUpazila, this.upazila);
  }

  Future<void> clear() => save(name: '', phone: '', upazila: '');
}
