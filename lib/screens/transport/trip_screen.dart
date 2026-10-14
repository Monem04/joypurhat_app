import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../models/transport.dart';
import '../../providers/booking_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transport_provider.dart';
import '../../services/launcher.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';
import '../booking/booking_form_screen.dart' show ChoiceCard;
import 'ticket_screen.dart';

/// Demo bus trip: pick seats on a live seat map and follow the bus.
///
/// Everything here is simulated on the phone (see TransportProvider). In the
/// real app the seat map comes from the bus company's server.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.trip});
  final DemoTrip trip;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  late final TransportProvider _transport;
  int _day = 0;

  @override
  void initState() {
    super.initState();
    _transport = context.read<TransportProvider>()..startLive();
  }

  @override
  void dispose() {
    _transport.stopLive();
    super.dispose();
  }

  DateTime get _date => dayOnly(DateTime.now()).add(Duration(days: _day));

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final tp = context.watch<TransportProvider>();
    final picked = tp.pickedFor(t, _day);
    final canBook = tp.canBook(t, _day);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.name),
          bottom: const TabBar(tabs: [Tab(text: 'সিট বাছাই'), Tab(text: 'লাইভ লোকেশন')]),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const DemoBanner('ডেমো: সিট, পেমেন্ট ও টিকিট নমুনা, আসল নয়।'),
                const SizedBox(height: 12),
                _TripHeader(trip: t),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 0; d < 3; d++)
                      ChoiceChip(
                        label: Text(dayLabelBn(dayOnly(DateTime.now()).add(Duration(days: d)))),
                        selected: _day == d,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _day == d ? Colors.white : AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() {
                          _day = d;
                          tp.clearPicked();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!canBook)
                  const NoteBanner('আজকের বাস ছেড়ে গেছে। আগামীকালের সিট দেখুন।', icon: Icons.schedule)
                else ...[
                  if (tp.lastSale.isNotEmpty) ...[
                    NoteBanner(tp.lastSale, icon: Icons.bolt_outlined),
                    const SizedBox(height: 12),
                  ],
                  _SeatMap(trip: t, day: _day),
                ],
              ],
            ),
            _LiveTab(trip: t),
          ],
        ),
        bottomNavigationBar: BottomAction(
          label: picked.isEmpty ? 'সিট বাছাই করুন' : 'এগিয়ে যান',
          icon: Icons.arrow_forward,
          onPressed: picked.isEmpty || !canBook
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _PayScreen(trip: t, day: _day, date: _date, seats: List.of(picked)),
                  )),
          leading: picked.isEmpty
              ? null
              : Text(
                  'সিট ${picked.join(', ')}\n${t.fare > 0 ? 'মোট ৳${money(t.fare * picked.length)}' : 'ভাড়া কাউন্টারে'}',
                  style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});
  final DemoTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(Icons.directions_bus_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.route, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${t.coach} · ছাড়বে ${t.time}', style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
                  ],
                ),
              ),
              Text(t.fare > 0 ? '৳${money(t.fare)}' : '',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          InfoLine(
            icon: Icons.place_outlined,
            label: 'কাউন্টার',
            value: t.address,
            onTap: () => Launch.map(context, query: t.mapQuery),
            divider: false,
          ),
        ],
      ),
    );
  }
}

class _SeatMap extends StatelessWidget {
  const _SeatMap({required this.trip, required this.day});
  final DemoTrip trip;
  final int day;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TransportProvider>();
    final sold = tp.sold(trip, day);
    final held = tp.held(trip, day);
    final picked = tp.pickedFor(trip, day);
    final ids = TransportProvider.seatIds(trip.rows);

    Widget seat(String id) {
      final isSold = sold.contains(id);
      final isHeld = held.contains(id);
      final isPicked = picked.contains(id);
      final bg = isPicked
          ? AppColors.primary
          : isSold
              ? const Color(0xFFD0D5DD)
              : isHeld
                  ? AppColors.warnBg
                  : AppColors.surface;
      final fg = isPicked ? Colors.white : (isSold ? AppColors.muted : AppColors.text);
      final state = isSold ? 'বিক্রি হয়েছে' : (isHeld ? 'হোল্ডে আছে' : (isPicked ? 'বাছাই করা' : 'খালি'));
      return Semantics(
        button: !isSold && !isHeld,
        label: 'সিট $id, $state',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isSold || isHeld
              ? null
              : () => tp.togglePick(trip, day, id, onError: (m) => showToast(context, m)),
          child: Container(
            width: 46,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isPicked ? AppColors.primary : AppColors.border, width: 1.4),
            ),
            child: Text(id, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      );
    }

    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              Text('খালি ${bn(tp.freeCount(trip, day))}টি', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.airline_seat_recline_normal, color: AppColors.muted),
              const SizedBox(width: 4),
              const Text('চালক', style: TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          for (var r = 0; r < ids.length; r += 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  seat(ids[r]),
                  const SizedBox(width: 8),
                  seat(ids[r + 1]),
                  const SizedBox(width: 36),
                  seat(ids[r + 2]),
                  const SizedBox(width: 8),
                  seat(ids[r + 3]),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Legend(color: AppColors.surface, label: 'খালি'),
              _Legend(color: AppColors.primary, label: 'আপনার'),
              _Legend(color: Color(0xFFD0D5DD), label: 'বিক্রি'),
              _Legend(color: AppColors.warnBg, label: 'কাউন্টারে হোল্ড'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ],
    );
  }
}

class _LiveTab extends StatelessWidget {
  const _LiveTab({required this.trip});
  final DemoTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final live = context.watch<TransportProvider>().liveState(t);
    final stops = t.stops;
    final at = live.position.round().clamp(0, stops.isEmpty ? 0 : stops.length - 1);
    final showBus = live.kind == LiveKind.running || live.kind == LiveKind.boarding || live.kind == LiveKind.waiting;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DemoBanner('ডেমো: বাসের অবস্থান নমুনা। আসল অ্যাপে বাসের জিপিএস থেকে আসবে।'),
        const SizedBox(height: 12),
        Panel(
          child: Row(
            children: [
              const IconBox(Icons.gps_fixed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(live.headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (live.detail.isNotEmpty)
                      Text(live.detail, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
                    if (live.late > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Pill('${bn(live.late)} মিনিট দেরি', bg: AppColors.warnBg, fg: AppColors.warnText),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (stops.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                for (final (i, s) in stops.indexed)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: showBus && i <= live.position ? AppColors.primary : AppColors.surface,
                                  border: Border.all(color: AppColors.primary, width: 2),
                                ),
                              ),
                              if (i < stops.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: showBus && i + 1 <= live.position ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                Text(s.time, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                        if (showBus && i == at)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.directions_bus, color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Passenger details and payment for the picked seats (simulated).
class _PayScreen extends StatefulWidget {
  const _PayScreen({required this.trip, required this.day, required this.date, required this.seats});
  final DemoTrip trip;
  final int day;
  final DateTime date;
  final List<String> seats;

  @override
  State<_PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<_PayScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  int _board = 0;
  int _pay = 0;
  bool _busy = false;

  List<(String, String)> get _payOptions => [
        if (widget.trip.fare > 0) ...[
          ('বিকাশ', 'বিকাশ অ্যাপে পেমেন্ট, সাথে সাথে টিকিট'),
          ('নগদ', 'নগদ অ্যাপে পেমেন্ট, সাথে সাথে টিকিট'),
          ('কার্ড', 'ভিসা বা মাস্টারকার্ড'),
        ],
        (
          'কাউন্টারে পেমেন্ট',
          widget.trip.hold.isEmpty
              ? 'সিট হোল্ড থাকবে, কাউন্টারে টাকা দিয়ে টিকিট নিন'
              : 'সিট ${widget.trip.hold} পর্যন্ত হোল্ড থাকবে, এর মধ্যে কাউন্টারে টাকা দিন'
        ),
      ];

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileProvider>();
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final t = widget.trip;
    final transport = context.read<TransportProvider>();
    final bookings = context.read<BookingProvider>();
    final navigator = Navigator.of(context);
    final option = _payOptions[_pay].$1;
    final paid = option != 'কাউন্টারে পেমেন্ট';
    setState(() => _busy = true);
    // Stands in for the payment gateway's round trip.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    transport.confirm(t, widget.day, widget.seats, paid: paid);
    final total = t.fare * widget.seats.length;
    final b = Booking(
      id: bookings.newId(),
      kind: 'ticket',
      title: t.name,
      place: t.address,
      status: paid ? 'টিকিট কনফার্ম (ডেমো)' : 'সিট হোল্ড (ডেমো)',
      createdAt: DateTime.now(),
      code: bookings.newCode('JPB'),
      codeLabel: 'টিকিট নম্বর',
      rows: [
        ('যাত্রা', t.route),
        ('তারিখ', dayLabelBn(widget.date)),
        ('ছাড়বে', t.time),
        ('কোচ', t.coach),
        ('সিট', widget.seats.join(', ')),
        if (t.boards.isNotEmpty) ('বোর্ডিং', t.boards[_board.clamp(0, t.boards.length - 1)]),
        ('যাত্রী', _name.text.trim()),
        ('মোবাইল', phoneBn(_phone.text.trim())),
        if (total > 0) ('ভাড়া', '৳${money(total)}'),
        ('পেমেন্ট', paid ? '$option এ পরিশোধিত' : 'কাউন্টারে দিতে হবে${t.hold.isEmpty ? '' : ', ${t.hold} এর মধ্যে'}'),
      ],
      isTicket: true,
      isDemo: true,
    );
    await bookings.add(b);
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => TicketScreen(booking: b)));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final total = t.fare * widget.seats.length;
    return Scaffold(
      appBar: AppBar(title: const Text('যাত্রীর তথ্য ও পেমেন্ট')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DemoBanner('ডেমো: কোনো টাকা কাটা হবে না, টিকিটও আসল নয়।'),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                children: [
                  InfoLine(icon: Icons.directions_bus_outlined, label: t.name, value: t.route),
                  InfoLine(icon: Icons.event_outlined, label: 'তারিখ ও সময়', value: '${dayLabelBn(widget.date)}, ${t.time}'),
                  InfoLine(
                    icon: Icons.event_seat_outlined,
                    label: 'সিট',
                    value: widget.seats.join(', '),
                    divider: total > 0,
                  ),
                  if (total > 0)
                    InfoLine(icon: Icons.payments_outlined, label: 'মোট ভাড়া', value: '৳${money(total)}', divider: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('যাত্রী'),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'যাত্রীর নাম *'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'নাম লিখুন' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'মোবাইল নম্বর *'),
                    validator: (v) =>
                        isBdMobile((v ?? '').trim()) ? null : 'সঠিক মোবাইল নম্বর দিন, ০১ দিয়ে শুরু, মোট ১১ সংখ্যা',
                  ),
                  if (t.boards.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('কোথা থেকে উঠবেন',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, b) in t.boards.indexed)
                          ChoiceChip(
                            label: Text(b),
                            selected: _board == i,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _board == i ? Colors.white : AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() => _board = i),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('পেমেন্ট'),
                  for (final (i, o) in _payOptions.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChoiceCard(
                        title: o.$1,
                        desc: o.$2,
                        selected: _pay == i,
                        onTap: () => setState(() => _pay = i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAction(
        label: _busy
            ? 'একটু অপেক্ষা করুন'
            : (_payOptions[_pay].$1 == 'কাউন্টারে পেমেন্ট' ? 'সিট হোল্ড করুন' : 'পেমেন্ট করুন (ডেমো)'),
        icon: Icons.lock_outline,
        onPressed: _busy ? null : _confirm,
      ),
    );
  }
}
