import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/booking.dart';
import '../../models/catalog.dart';
import '../../providers/booking_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/launcher.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import 'done_screen.dart';
import 'order_track_screen.dart';

/// What a form is about and where the request goes.
class BookingTarget {
  const BookingTarget({
    required this.title,
    this.sub = '',
    this.place = '',
    this.price = '',
    this.phones = const [],
    this.icon = 'calcheck',
    this.color = 'teal',
    this.kind = 'booking',
    this.weekdays = const [],
    this.lines = const [],
    this.deliveryFee = 0,
    this.services = const [],
    this.bookedSlots = const [],
    this.toSupport = false,
    this.demoOnly = false,
    this.onSent,
  });

  /// Requests that go to the app owner, like "Shop দিতে চাই" or To-Let.
  const BookingTarget.support({required this.title, this.sub = '', this.icon = 'bag', this.color = 'teal'})
      : place = '',
        price = '',
        phones = const [],
        kind = 'request',
        weekdays = const [],
        lines = const [],
        deliveryFee = 0,
        services = const [],
        bookedSlots = const [],
        toSupport = true,
        demoOnly = false,
        onSent = null;

  final String title;
  final String sub;
  final String place;
  final String price;
  final List<String> phones;
  final String icon;

  /// Colour group of the service, for the header.
  final String color;

  /// serial, booking, order, request
  final String kind;

  /// Days a doctor sits (0 Sunday ... 6 Saturday), for the date chips.
  final List<int> weekdays;

  /// Cart lines: name, quantity, line total.
  final List<(String, int, int)> lines;

  /// Added to the bill for home delivery.
  final int deliveryFee;

  /// The place's own services and prices, for a "fromServices" field.
  final List<MenuRow> services;

  /// Time slots already taken, per offered day (sample parlours).
  final List<List<String>> bookedSlots;
  final bool toSupport;

  /// Sample entries can only be "booked" in demo mode.
  final bool demoOnly;

  /// Called once the request is made, e.g. to empty the food cart.
  final VoidCallback? onSent;

  int get subtotal => lines.fold(0, (a, l) => a + l.$3);
}

class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({super.key, required this.config, required this.target});
  final FormConfig config;
  final BookingTarget target;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};
  final Map<String, int> _picks = {};
  bool _busy = false;

  List<FieldDef> get _fields => widget.config.fields;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    for (final f in _fields) {
      if (f.type == 'text' || f.type == 'tel' || f.type == 'area') {
        var initial = '';
        if (f.key == 'name' || f.key == 'owner') initial = profile.name;
        if (f.key == 'phone') initial = profile.phone;
        _text[f.key] = TextEditingController(text: initial);
      } else if (f.type == 'step') {
        _picks[f.key] = f.defaultValue;
      } else if (f.type == 'slots') {
        // Nothing picked until the user chooses a free time.
        _picks[f.key] = -1;
      } else {
        _picks[f.key] = 0;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<DateTime> _nextDays(int n) {
    final today = dayOnly(DateTime.now());
    return [for (var i = 0; i < n; i++) today.add(Duration(days: i))];
  }

  List<DateTime> _doctorDays() {
    final w = widget.target.weekdays;
    if (w.isEmpty) return _nextDays(7);
    final today = dayOnly(DateTime.now());
    final out = <DateTime>[];
    for (var i = 0; i < 28 && out.length < 4; i++) {
      final d = today.add(Duration(days: i));
      if (w.contains(weekdayIndex(d))) out.add(d);
    }
    return out.isEmpty ? _nextDays(7) : out;
  }

  List<String> _optionsFor(FieldDef f) {
    if (f.fromServices) {
      return [for (final s in widget.target.services) s.price.isEmpty ? s.name : '${s.name} · ${s.price}'];
    }
    switch (f.type) {
      case 'dates':
        return _nextDays(f.count > 0 ? f.count : 7).map(dayLabelBn).toList();
      case 'docdates':
        return _doctorDays().map(dayLabelBn).toList();
      default:
        return f.options;
    }
  }

  bool _visible(FieldDef f) {
    if (f.whenKey.isNotEmpty && _picks[f.whenKey] != f.whenValue) return false;
    if (f.fromServices && widget.target.services.isEmpty) return false;
    return true;
  }

  /// Slots already taken on the day picked in the form's first date field.
  Set<String> _bookedNow() {
    final booked = widget.target.bookedSlots;
    if (booked.isEmpty) return const {};
    final dateField = _fields.where((f) => f.type == 'dates').firstOrNull;
    final day = dateField == null ? 0 : _picks[dateField.key] ?? 0;
    return day < booked.length ? booked[day].toSet() : const {};
  }

  String _valueText(FieldDef f) {
    switch (f.type) {
      case 'text':
      case 'tel':
      case 'area':
        return _text[f.key]!.text.trim();
      case 'step':
        return '${bn(_picks[f.key]!)}${f.unit}';
      case 'photo':
        return '';
      default:
        final opts = _optionsFor(f);
        final i = _picks[f.key] ?? 0;
        return i >= 0 && i < opts.length ? opts[i] : '';
    }
  }

  List<(String, String)> _rows() => [
        for (final f in _fields)
          if (_visible(f) && _valueText(f).isNotEmpty) (f.label, _valueText(f)),
      ];

  FieldDef? get _deliveryChoice => _fields.where((f) => f.key == 'dtype').firstOrNull;

  /// Pick-up orders skip the delivery charge.
  bool get _pickup {
    final f = _deliveryChoice;
    return f != null && (_picks[f.key] ?? 0) != 0;
  }

  int get _deliveryCharge => widget.target.lines.isEmpty || _pickup ? 0 : widget.target.deliveryFee;

  int get _total => widget.target.subtotal + _deliveryCharge;

  String _kindWord() {
    switch (widget.target.kind) {
      case 'serial':
        return 'সিরিয়ালের অনুরোধ';
      case 'order':
        return 'অর্ডার';
      case 'request':
        return 'আবেদন';
      default:
        return 'বুকিংয়ের অনুরোধ';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      showToast(context, 'লাল চিহ্নিত ঘরগুলো ঠিক করুন।');
      return;
    }
    final slot = _fields.where((f) => f.type == 'slots' && _visible(f)).firstOrNull;
    if (slot != null && (_picks[slot.key] ?? -1) < 0) {
      showToast(context, '${slot.label} বেছে নিন।');
      return;
    }
    setState(() => _busy = true);
    final bookings = context.read<BookingProvider>();
    final profile = context.read<ProfileProvider>();
    final t = widget.target;
    final cfg = widget.config;
    final rows = _rows();
    if (t.lines.isNotEmpty) {
      rows.add(('মোট বিল', '৳${money(_total)}${_deliveryCharge > 0 ? ' (ডেলিভারি ৳${money(_deliveryCharge)} সহ)' : ''}'));
    }
    final name = _text['name']?.text.trim() ?? _text['pname']?.text.trim() ?? _text['owner']?.text.trim() ?? '';
    final phone = _text['phone']?.text.trim() ?? '';
    if (profile.isEmpty && phone.isNotEmpty) {
      await profile.save(name: _text['name']?.text ?? _text['owner']?.text ?? '', phone: phone, upazila: profile.upazila);
    }
    if (!mounted) return;

    final code = bookings.newCode('JP');
    final demo = AppConfig.demoMode || t.demoOnly;
    if (demo) {
      final big = cfg.serial ? bn(bookings.newSerial()) : code;
      final b = Booking(
        id: bookings.newId(),
        kind: t.kind,
        title: t.title,
        place: t.place,
        status: cfg.track ? 'অর্ডার চলছে (ডেমো)' : 'নিশ্চিত হয়েছে (ডেমো)',
        createdAt: DateTime.now(),
        code: big,
        codeLabel: cfg.bigLabel.isEmpty ? (cfg.track ? 'অর্ডার নম্বর' : 'বুকিং নম্বর') : cfg.bigLabel,
        rows: rows,
        phone: t.phones.isEmpty ? '' : t.phones.first,
        isDemo: true,
        track: cfg.track,
        pickup: _pickup,
        total: t.lines.isEmpty ? 0 : _total,
      );
      await bookings.add(b);
      t.onSent?.call();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => cfg.track
            ? OrderTrackScreen(booking: b)
            : DoneScreen(
                booking: b,
                title: cfg.doneTitle.isEmpty ? 'সম্পন্ন হয়েছে' : cfg.doneTitle,
                message: '${cfg.message}\n\nএটি ডেমো, কোথাও পাঠানো হয়নি।',
              ),
      ));
      return;
    }

    // Real request: an SMS to the place (or the app owner) that the user sends.
    final mobiles = t.toSupport
        ? [if (isBdMobile(AppConfig.supportPhone)) AppConfig.supportPhone]
        : t.phones.where(isBdMobile).toList();
    final body = StringBuffer('Joypurhat অ্যাপ থেকে ${_kindWord()} ($code)\n')
      ..writeln(t.place.isEmpty ? t.title : '${t.title}, ${t.place}');
    for (final l in t.lines) {
      body.writeln('${l.$1} x ${bn(l.$2)} = ৳${money(l.$3)}');
    }
    for (final r in rows) {
      body.writeln('${r.$1}: ${r.$2}');
    }
    final text = body.toString().trim();

    if (mobiles.isEmpty) {
      setState(() => _busy = false);
      if (t.toSupport && AppConfig.supportEmail.isNotEmpty) {
        await Launch.email(context, AppConfig.supportEmail, '${t.title} ($code)', text);
        if (!mounted) return;
        await _saveAndFinish(code, rows, 'ইমেইলে পাঠানো হয়েছে', name, 'ইমেইল অ্যাপে মেসেজটি পাঠান। আমাদের টিম যোগাযোগ করবে।');
        return;
      }
      if (t.phones.isNotEmpty) {
        await _callInstead();
      } else {
        showToast(context, 'এই অনুরোধ পাঠানোর নম্বর এখনো যোগ হয়নি। পরের আপডেটে চালু হবে।');
      }
      return;
    }
    await Launch.sms(context, mobiles.first, text);
    if (!mounted) return;
    t.onSent?.call();
    await _saveAndFinish(
      code,
      rows,
      'এসএমএসে অনুরোধ পাঠানো হয়েছে',
      name,
      'এসএমএস অ্যাপে মেসেজটি তৈরি আছে, পাঠাতে Send চাপুন। ${t.toSupport ? 'আমাদের টিম' : 'প্রতিষ্ঠান থেকে'} ফোন করে নিশ্চিত করবে। তাড়া থাকলে নিচের বাটনে কল করুন।',
      phone: mobiles.first,
    );
  }

  Future<void> _saveAndFinish(String code, List<(String, String)> rows, String status, String name, String message,
      {String phone = ''}) async {
    final bookings = context.read<BookingProvider>();
    final t = widget.target;
    final b = Booking(
      id: bookings.newId(),
      kind: t.kind,
      title: t.title,
      place: t.place,
      status: status,
      createdAt: DateTime.now(),
      code: code,
      codeLabel: 'রেফারেন্স',
      rows: rows,
      phone: phone,
      total: t.lines.isEmpty ? 0 : _total,
    );
    await bookings.add(b);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DoneScreen(booking: b, title: 'অনুরোধ তৈরি হয়েছে', message: message),
    ));
  }

  Future<void> _callInstead() async {
    final t = widget.target;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('কল করে বুক করুন'),
        content: Text('${t.place.isEmpty ? t.title : t.place} এর মোবাইল নম্বর পাওয়া যায়নি, তাই এসএমএস যাবে না। কল করে আপনার তথ্য বলুন।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              callNumbers(context, t.title, t.phones);
            },
            icon: const Icon(Icons.call),
            label: const Text('কল করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final cfg = widget.config;
    final g = Group.of(t.color);
    return Scaffold(
      appBar: AppBar(title: Text(cfg.title.isEmpty ? 'বুকিং' : cfg.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: g.gradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: g.shadow, blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: Icon(iconFor(t.icon, Icons.event_available_outlined), color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                            if (t.sub.isNotEmpty)
                              Text(t.sub, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (t.place.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 18, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t.place, style: const TextStyle(fontSize: 14))),
                    ]),
                  ],
                  if (t.price.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(t.price,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            if (t.lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Bill(target: t, delivery: _deliveryCharge, pickup: _pickup, total: _total),
            ],
            if (cfg.intro.isNotEmpty) ...[const SizedBox(height: 12), NoteBanner(cfg.intro)],
            if (!AppConfig.demoMode && !t.demoOnly) ...[
              const SizedBox(height: 12),
              NoteBanner(t.toSupport
                  ? 'ফর্ম জমা দিলে এসএমএস অ্যাপে মেসেজ তৈরি হবে। Send চাপলে অ্যাপের টিমের কাছে যাবে।'
                  : 'ফর্ম জমা দিলে আপনার তথ্যসহ এসএমএস তৈরি হবে। Send চাপলে সরাসরি প্রতিষ্ঠানে যাবে, তারা ফোন করে নিশ্চিত করবে।'),
            ],
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in _fields)
                    if (_visible(f)) ...[
                      _field(f),
                      const SizedBox(height: 16),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAction(
        label: _busy
            ? 'একটু অপেক্ষা করুন'
            : '${cfg.cta.isEmpty ? 'জমা দিন' : cfg.cta}${t.lines.isEmpty ? '' : ' · ৳${money(_total)}'}',
        icon: Icons.check,
        onPressed: _busy ? null : _submit,
      ),
    );
  }

  Widget _label(FieldDef f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(f.label + (f.required ? ' *' : ''),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
      );

  Widget _field(FieldDef f) {
    switch (f.type) {
      case 'text':
      case 'tel':
      case 'area':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            TextFormField(
              controller: _text[f.key],
              keyboardType: f.type == 'tel' ? TextInputType.phone : (f.type == 'area' ? TextInputType.multiline : TextInputType.text),
              maxLines: f.type == 'area' ? 4 : 1,
              minLines: f.type == 'area' ? 3 : 1,
              decoration: InputDecoration(hintText: f.hint),
              validator: (v) {
                final s = (v ?? '').trim();
                if (f.required && s.isEmpty) return '${f.label} লিখুন';
                if (f.type == 'tel' && s.isNotEmpty && !isBdMobile(s)) {
                  return 'সঠিক মোবাইল নম্বর দিন, ০১ দিয়ে শুরু, মোট ১১ সংখ্যা';
                }
                return null;
              },
            ),
          ],
        );
      case 'step':
        final v = _picks[f.key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: '${f.label} কমান',
                  onPressed: v - f.step < f.min ? null : () => setState(() => _picks[f.key] = v - f.step),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text('${bn(v)}${f.unit}',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton.outlined(
                  tooltip: '${f.label} বাড়ান',
                  onPressed: v + f.step > f.max ? null : () => setState(() => _picks[f.key] = v + f.step),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        );
      case 'choice':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            for (var i = 0; i < f.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceCard(
                  title: f.options[i],
                  desc: i < f.descriptions.length ? f.descriptions[i] : '',
                  selected: _picks[f.key] == i,
                  onTap: () => setState(() => _picks[f.key] = i),
                ),
              ),
          ],
        );
      case 'photo':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'এসএমএসে ছবি যায় না। জমা দেওয়ার পর আমাদের টিম ফোন করলে বাইরে, রুম, বাথরুম ও রান্নাঘরের ছবি পাঠানোর উপায় জানিয়ে দেবে।',
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'slots':
        final booked = _bookedNow();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < f.options.length; i++)
                  _SlotChip(
                    label: f.options[i],
                    taken: booked.contains(f.options[i]),
                    selected: _picks[f.key] == i,
                    onTap: () => setState(() => _picks[f.key] = i),
                  ),
              ],
            ),
            if (booked.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('কাটা দাগের সময়গুলো আগেই বুক হয়ে গেছে।',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
          ],
        );
      default:
        final opts = _optionsFor(f);
        final isDate = f.type == 'dates';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < opts.length; i++)
                  ChoiceChip(
                    label: Text(opts[i]),
                    selected: _picks[f.key] == i,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _picks[f.key] == i ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _picks[f.key] = i;
                      // A new day can make the chosen time already taken.
                      if (isDate) _dropTakenSlot();
                    }),
                  ),
              ],
            ),
          ],
        );
    }
  }

  void _dropTakenSlot() {
    final booked = _bookedNow();
    for (final f in _fields.where((f) => f.type == 'slots')) {
      final i = _picks[f.key] ?? -1;
      if (i >= 0 && i < f.options.length && booked.contains(f.options[i])) _picks[f.key] = -1;
    }
  }
}

/// Subtotal, delivery and total for a food order.
class _Bill extends StatelessWidget {
  const _Bill({required this.target, required this.delivery, required this.pickup, required this.total});
  final BookingTarget target;
  final int delivery;
  final bool pickup;
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget line(String a, String b, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(a,
                    style: TextStyle(
                        fontSize: strong ? 16 : 14, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
              ),
              Text(b,
                  style: TextStyle(
                      fontSize: strong ? 16 : 14,
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                      color: strong ? const Color(0xFFC2410C) : AppColors.text)),
            ],
          ),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(target.deliveryFee > 0 ? 'আপনার অর্ডার' : 'যা কিনছেন'),
          for (final l in target.lines) line('${l.$1} × ${bn(l.$2)}', '৳${money(l.$3)}'),
          const Divider(height: 18),
          if (target.deliveryFee > 0) ...[
            line('খাবারের দাম', '৳${money(target.subtotal)}'),
            line('ডেলিভারি চার্জ', pickup ? 'লাগবে না' : '৳${money(delivery)}'),
          ],
          const Divider(height: 18),
          line('মোট', '৳${money(total)}', strong: true),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.taken, required this.selected, required this.onTap});
  final String label;
  final bool taken;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: taken ? '$label, বুক হয়ে গেছে' : label,
      selected: selected,
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            decoration: taken ? TextDecoration.lineThrough : null,
            color: taken ? AppColors.muted : (selected ? Colors.white : AppColors.text),
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        disabledColor: const Color(0xFFEFF2F2),
        onSelected: taken ? null : (_) => onTap(),
      ),
    );
  }
}

/// A radio-style card with a title and a line of explanation.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({super.key, required this.title, required this.desc, required this.selected, required this.onTap});
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF6F4) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(desc, style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
