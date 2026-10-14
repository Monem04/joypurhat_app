/// Bangla number, money, date and time helpers.
library;

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// English digits to Bangla digits: 2026 -> ২০২৬.
String bn(Object value) => value
    .toString()
    .replaceAllMapped(RegExp(r'[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);

/// Bangla digits to English digits, for phone numbers and validation.
String toEnDigits(String s) {
  final out = StringBuffer();
  for (final ch in s.split('')) {
    final i = _bnDigits.indexOf(ch);
    out.write(i >= 0 ? '$i' : ch);
  }
  return out.toString();
}

/// 12500 -> ১২,৫০০
String money(num n) => bn(n
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ','));

/// Index = DateTime.weekday % 7 (0 Sunday ... 6 Saturday).
const weekdaysBn = [
  'রবিবার',
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
];

const weekdaysShortBn = ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি'];

const monthsBn = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

int weekdayIndex(DateTime d) => d.weekday % 7;

String partOfDay(int h) {
  if (h < 4) return 'রাত';
  if (h < 6) return 'ভোর';
  if (h < 12) return 'সকাল';
  if (h < 15) return 'দুপুর';
  if (h < 18) return 'বিকাল';
  if (h < 20) return 'সন্ধ্যা';
  return 'রাত';
}

/// 16, 53 -> বিকাল ৪:৫৩
String clockBn(int h, int m) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${partOfDay(h)} ${bn(h12)}:${bn(m.toString().padLeft(2, '0'))}';
}

String timeOfBn(DateTime d) => clockBn(d.hour, d.minute);

/// 11 অক্টোবর
String dateBn(DateTime d) => '${bn(d.day)} ${monthsBn[d.month - 1]}';

/// 11 অক্টোবর ২০২৬
String fullDateBn(DateTime d) => '${dateBn(d)} ${bn(d.year)}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// আজ, আগামীকাল, or "শুক্র, ১৭ অক্টোবর".
String dayLabelBn(DateTime d, [DateTime? now]) {
  final today = dayOnly(now ?? DateTime.now());
  final diff = dayOnly(d).difference(today).inDays;
  if (diff == 0) return 'আজ, ${dateBn(d)}';
  if (diff == 1) return 'আগামীকাল, ${dateBn(d)}';
  return '${weekdaysShortBn[weekdayIndex(d)]}, ${dateBn(d)}';
}

/// 135 -> ২ ঘণ্টা ১৫ মিনিট
String durationBn(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${bn(m)} মিনিট';
  if (m == 0) return '${bn(h)} ঘণ্টা';
  return '${bn(h)} ঘণ্টা ${bn(m)} মিনিট';
}

/// Parses "16:53" into minutes after midnight, or null.
int? parseHm(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  return int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

/// A Bangladeshi mobile number: 01 then 3-9 then 8 digits.
bool isBdMobile(String raw) {
  final d = toEnDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  final local = d.startsWith('880') ? '0${d.substring(3)}' : d;
  return RegExp(r'^01[3-9]\d{8}$').hasMatch(local);
}

/// Keeps digits and a leading +, for tel: and sms: links.
String dialable(String raw) {
  final s = toEnDigits(raw).trim();
  final plus = s.startsWith('+');
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return plus ? '+$digits' : digits;
}

/// A number written for reading, with Bangla digits.
String phoneBn(String raw) => bn(toEnDigits(raw));
