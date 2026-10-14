/// A booking, request or ticket saved on the phone.
class Booking {
  Booking({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAt,
    this.place = '',
    this.code = '',
    this.codeLabel = '',
    this.rows = const [],
    this.phone = '',
    this.isTicket = false,
    this.isDemo = false,
    this.track = false,
    this.pickup = false,
    this.total = 0,
  });

  final String id;

  /// serial, booking, order, request, ticket
  final String kind;
  final String title;
  final String status;
  final DateTime createdAt;
  final String place;
  final String code;
  final String codeLabel;
  final List<(String, String)> rows;

  /// Number to call about this booking.
  final String phone;
  final bool isTicket;
  final bool isDemo;

  /// A demo food order with the step-by-step tracker.
  final bool track;

  /// Picked up at the restaurant instead of home delivery.
  final bool pickup;

  /// Bill total in taka, when there is one.
  final int total;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'place': place,
        'code': code,
        'codeLabel': codeLabel,
        'rows': rows.map((r) => [r.$1, r.$2]).toList(),
        'phone': phone,
        'isTicket': isTicket,
        'isDemo': isDemo,
        'track': track,
        'pickup': pickup,
        'total': total,
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? 'booking',
        title: j['title'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        place: j['place'] as String? ?? '',
        code: j['code'] as String? ?? '',
        codeLabel: j['codeLabel'] as String? ?? '',
        rows: (j['rows'] as List? ?? const [])
            .map((r) => ((r as List)[0].toString(), r[1].toString()))
            .toList(),
        phone: j['phone'] as String? ?? '',
        isTicket: j['isTicket'] == true,
        isDemo: j['isDemo'] == true,
        track: j['track'] == true,
        pickup: j['pickup'] == true,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// One stage of a food order, reached [minute] minutes after ordering.
class TrackStep {
  const TrackStep(this.title, this.minute, this.note);
  final String title;
  final int minute;
  final String note;
}

const _deliverySteps = [
  TrackStep('অর্ডার পাঠানো হয়েছে', 0, 'রেস্টুরেন্টের উত্তরের অপেক্ষা'),
  TrackStep('রেস্টুরেন্ট অর্ডার নিয়েছে', 2, 'এখনই রান্না শুরু হবে'),
  TrackStep('খাবার তৈরি হচ্ছে', 5, 'গরম গরম রান্না হচ্ছে'),
  TrackStep('ডেলিভারি ম্যান পথে', 24, 'আপনার ঠিকানায় আসছেন'),
  TrackStep('খাবার পৌঁছে গেছে', 38, 'খাবার উপভোগ করুন!'),
];

const _pickupSteps = [
  TrackStep('অর্ডার পাঠানো হয়েছে', 0, 'রেস্টুরেন্টের উত্তরের অপেক্ষা'),
  TrackStep('রেস্টুরেন্ট অর্ডার নিয়েছে', 2, 'এখনই রান্না শুরু হবে'),
  TrackStep('খাবার তৈরি হচ্ছে', 5, 'গরম গরম রান্না হচ্ছে'),
  TrackStep('খাবার তৈরি, নিয়ে যান', 20, 'রেস্টুরেন্টে গিয়ে অর্ডার নম্বর বলুন'),
  TrackStep('অর্ডার বুঝে নিয়েছেন', 30, 'খাবার উপভোগ করুন!'),
];

extension OrderTracking on Booking {
  List<TrackStep> get steps => pickup ? _pickupSteps : _deliverySteps;

  /// The step the demo order has reached at [now].
  int stepAt(DateTime now) {
    final minutes = now.difference(createdAt).inSeconds / 60;
    var i = 0;
    while (i + 1 < steps.length && steps[i + 1].minute <= minutes) {
      i++;
    }
    return i;
  }

  DateTime get readyAt => createdAt.add(Duration(minutes: steps.last.minute));
}
