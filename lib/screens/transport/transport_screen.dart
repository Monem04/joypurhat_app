import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/catalog.dart';
import '../../models/transport.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/transport_provider.dart';
import '../../services/launcher.dart';
import '../../services/train_schedule.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';
import '../category_router.dart';
import 'train_detail_screen.dart';
import 'train_live_screen.dart';
import 'trip_screen.dart';

/// Trains (live timetable) and buses (counters, fares, stands), with the
/// seat-booking demo when demo mode is on.
class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key, required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: c.mode == 'train' ? _TrainBody(category: c) : _BusBody(category: c),
    );
  }
}

// ---------------------------------------------------------------- trains

class _TrainBody extends StatefulWidget {
  const _TrainBody({required this.category});
  final Category category;

  @override
  State<_TrainBody> createState() => _TrainBodyState();
}

class _TrainBodyState extends State<_TrainBody> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _filter = 0;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openTrain(Train t) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainDetailScreen(train: t)));

  void _openLive() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainLiveScreen()));

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>().catalog;
    final data = catalog.transport;
    final rail = data.rail;
    final c = widget.category;
    final filter = directionFilters[_filter];
    final departures = upcomingDepartures(data.trains, _now, filter: filter);
    final next = departures.where((d) => d.minutesAway >= 0 && !d.offToday).firstOrNull;
    final station = data.place('Joypurhat Railway Station');
    final stations = data.places.where((p) => p.nameEn.contains('Railway')).toList();
    final trains = data.trains.where((t) => filter == 'সব' || t.runs.any((r) => directionGroup(r.to) == filter)).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        if (next != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _NextTrainCard(dep: next, onTap: () => _openTrain(next.train)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _ActionGrid(actions: [
            _Action('অনলাইনে টিকিট', Icons.confirmation_number_outlined, () => Launch.web(context, rail.ticketUrl)),
            _Action('${rail.appName} অ্যাপ', Icons.install_mobile_outlined, () => Launch.playStore(context, rail.appPackage)),
            _Action('ট্রেন এখন কোথায়', Icons.share_location_outlined, _openLive),
            _Action('কল সেন্টার ${bn(rail.callCentre)}', Icons.call_outlined, () => Launch.call(context, rail.callCentre)),
            if (rail.appSupport.isNotEmpty)
              _Action('অ্যাপের হেল্পলাইন', Icons.support_agent_outlined, () => Launch.call(context, rail.appSupport)),
            if (station != null)
              _Action('স্টেশনের ম্যাপ', Icons.map_outlined,
                  () => Launch.map(context, query: station.mapQuery, lat: station.lat, lng: station.lng)),
          ]),
        ),
        if (c.note.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: NoteBanner(c.note)),
        if (rail.ticketNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: NoteBanner(rail.ticketNote,
                icon: Icons.gpp_maybe_outlined, bg: AppColors.warnBg, fg: AppColors.warnText),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('পরের ট্রেন'), icon: Icon(Icons.schedule)),
              ButtonSegment(value: true, label: Text('সব ট্রেন'), icon: Icon(Icons.list_alt)),
            ],
            selected: {_all},
            onSelectionChanged: (s) => setState(() => _all = s.first),
          ),
        ),
        FilterBar(filters: directionFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const SizedBox(height: 12),
        if (!_all) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('জয়পুরহাট স্টেশন, এখন ${timeOfBn(_now)}',
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final (i, d) in departures.indexed)
                    _DepartureRow(dep: d, divider: i < departures.length - 1, onTap: () => _openTrain(d.train)),
                  if (departures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('এই দিকের কোনো ট্রেন নেই।', style: TextStyle(color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          ),
        ] else
          for (final t in trains)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _TrainCard(train: t, onTap: () => _openTrain(t)),
            ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('জেলার রেলস্টেশন', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PlacesPanel(places: stations, icon: Icons.train_outlined),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SourcesPanel(
            sources: {...rail.sources, for (final t in data.trains) ...t.sources}.toList(),
            checked: catalog.checked,
            note: data.note,
          ),
        ),
      ],
    );
  }
}

class _NextTrainCard extends StatelessWidget {
  const _NextTrainCard({required this.dep, required this.onTap});
  final Departure dep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: AppColors.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('জয়পুরহাট থেকে পরের ট্রেন',
                        style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${dep.train.name} (${bn(dep.run.number)})',
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('${dep.run.to} এর দিকে, ${hmBn(dep.run.time)}',
                        style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Text(dep.when,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.dep, required this.divider, required this.onTap});
  final Departure dep;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = dep.run;
    final left = dep.minutesAway < 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hmBn(r.time),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: left ? AppColors.muted : AppColors.primary)),
                  Text(dep.when,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: left ? AppColors.muted : AppColors.accent)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${dep.train.name} (${bn(r.number)})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('${r.to} এর দিকে${r.dep.isEmpty && r.arr.isNotEmpty ? ' (পৌঁছানোর সময়)' : ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  if (dep.offToday)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Pill('এই দিনে সাপ্তাহিক বন্ধ', bg: AppColors.dangerBg, fg: AppColors.danger),
                    ),
                  if (r.offConflict)
                    const Padding(padding: EdgeInsets.only(top: 4), child: CheckBadge()),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _TrainCard extends StatelessWidget {
  const _TrainCard({required this.train, required this.onTap});
  final Train train;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = train;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBox(Icons.train_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(t.termini, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    for (final r in t.runs)
                      Text(
                        '${bn(r.number)}: ${r.to} এর দিকে, ${r.time.isEmpty ? 'সময় যাচাই হয়নি' : hmBn(r.time)}',
                        style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSoft),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- buses

class _BusBody extends StatefulWidget {
  const _BusBody({required this.category});
  final Category category;

  @override
  State<_BusBody> createState() => _BusBodyState();
}

class _BusBodyState extends State<_BusBody> {
  int _filter = 0;
  int _coach = 0;
  static const _coaches = ['সব কোচ', 'এসি', 'নন-এসি'];

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>().catalog;
    final data = catalog.transport;
    final c = widget.category;
    final brtc = c.key == 'brtc';
    final filter = _filter < c.filters.length ? c.filters[_filter] : 'সব';
    final operators = brtc
        ? const <BusOperator>[]
        : data.buses
            .where((b) => filter == 'সব' || b.route.contains(filter))
            .where((b) => _coach == 0 || b.hasCoach(_coaches[_coach]))
            .toList();
    final stands = data.places.where((p) => p.nameEn.contains('Bus')).toList();
    final trips = AppConfig.demoMode
        ? context
            .watch<TransportProvider>()
            .trips
            .where((t) => t.brtc == brtc && (filter == 'সব' || t.tag == filter))
            .toList()
        : const <DemoTrip>[];

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        if (c.note.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: NoteBanner(c.note)),
        if (c.filters.length > 1) ...[
          FilterBar(filters: c.filters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
          const SizedBox(height: 8),
        ],
        if (!brtc) ...[
          FilterBar(filters: _coaches, selected: _coach, onSelected: (i) => setState(() => _coach = i)),
          const SizedBox(height: 12),
          if (data.busOnline.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('অনলাইনে বাসের টিকিট', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _TicketSites(sites: data.busOnline),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('বাস কোম্পানি, কাউন্টার ও ভাড়া', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
          for (final b in operators)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _OperatorCard(op: b)),
          if (operators.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: EmptyState(
                icon: Icons.directions_bus_outlined,
                title: 'এই রুটের তথ্য এখনো নেই',
                text: 'যাচাই করা তথ্য পাওয়া গেলে যোগ হবে। এখন ঢাকার বাসগুলো দেখুন।',
              ),
            ),
        ],
        if (brtc && trips.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: EmptyState(
              icon: Icons.directions_bus_filled_outlined,
              title: 'তথ্য যোগ হচ্ছে',
              text: 'বিআরটিসি কাউন্টারের যাচাই করা নম্বর ও সময় পাওয়া গেলে এখানে যোগ হবে। এখন বেসরকারি বাসের তালিকা দেখুন।',
              actionLabel: 'আন্তনগর বাস',
              onAction: () => openCategoryKey(context, 'bus'),
            ),
          ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('অনলাইনে সিট বুকিং', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: DemoBanner(
                'ডেমো: এই বাস, সিট, লাইভ লোকেশন ও পেমেন্ট নমুনা। বাস কোম্পানির সাথে চুক্তি ও সার্ভার চালু হলে আসল বুকিং হবে (README দেখুন)।'),
          ),
          for (final t in trips)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _TripCard(trip: t)),
        ],
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('বাসস্ট্যান্ড ও টার্মিনাল', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PlacesPanel(places: stands, icon: Icons.directions_bus_outlined),
        ),
        if (!brtc) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SourcesPanel(
              sources: {for (final b in data.buses) ...b.sources}.toList(),
              checked: catalog.checked,
              note: data.note,
            ),
          ),
        ],
      ],
    );
  }
}

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.op});
  final BusOperator op;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBox(Icons.directions_bus_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(op.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(op.route, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (coach, fare) in op.coaches)
              Pill('$coach: $fare', icon: Icons.sell_outlined, bg: AppColors.surfaceAlt, fg: AppColors.textSoft),
            if (op.confidence == 'low') const CheckBadge(),
          ]),
          if (op.website.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
              onPressed: () => Launch.web(context, op.website),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('${SourcesPanel.host(op.website)} এ টিকিট'),
            ),
          ],
          if (op.counters.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, k) in op.counters.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: i < op.counters.length - 1
                      ? const Border(bottom: BorderSide(color: AppColors.divider))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.place, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                          Text(k.phones.map(phoneBn).join(', '),
                              style: const TextStyle(fontSize: 14, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    if (k.phones.isNotEmpty) CallButton(name: '${op.name}, ${k.place}', numbers: k.phones, size: 40),
                  ],
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('জয়পুরহাট কাউন্টারের নম্বর যাচাই করা যায়নি।',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final DemoTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final transport = context.watch<TransportProvider>();
    final live = transport.liveState(t);
    final free = transport.freeCount(t, 0);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripScreen(trip: t))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                  Text(t.time,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
              Text(t.route, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                const SampleBadge(),
                Pill(t.coach),
                Pill(t.fare > 0 ? '৳${money(t.fare)}' : 'ভাড়া কাউন্টারে',
                    bg: AppColors.surfaceAlt, fg: AppColors.textSoft),
                Pill('আজ ${bn(free)}টি সিট খালি', bg: AppColors.successBg, fg: AppColors.successText),
              ]),
              if (live.kind != LiveKind.none) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.gps_fixed, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(live.headline, style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Online bus ticket sites with their help lines.
class _TicketSites extends StatelessWidget {
  const _TicketSites({required this.sites});
  final List<TicketSite> sites;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (final (i, s) in sites.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i < sites.length - 1 ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBox(Icons.confirmation_number_outlined, size: 40, bg: Group.blue.soft, fg: Group.blue.deep),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                            Text(s.sub, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 40)),
                      onPressed: () => Launch.web(context, s.url),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('টিকিট দেখুন'),
                    ),
                    if (s.helpline.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
                        onPressed: () => Launch.call(context, s.helpline),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text('হেল্পলাইন ${bn(s.helpline)}'),
                      ),
                  ]),
                  if (s.hours.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('হেল্পলাইন খোলা: ${s.hours}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- shared

class _Action {
  const _Action(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in actions)
              SizedBox(
                width: w,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: a.onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(a.icon, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(a.label,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlacesPanel extends StatelessWidget {
  const _PlacesPanel({required this.places, required this.icon});
  final List<TransportPlace> places;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (final (i, p) in places.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < places.length - 1 ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: Row(
                children: [
                  IconBox(icon, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(p.nameEn, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
                    onPressed: () => Launch.map(context, query: p.mapQuery, lat: p.lat, lng: p.lng),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('ম্যাপ'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
