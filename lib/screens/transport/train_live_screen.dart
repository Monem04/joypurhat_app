import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transport.dart';
import '../../providers/catalog_provider.dart';
import '../../services/launcher.dart';
import '../../services/train_live.dart';
import '../../services/train_schedule.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';

/// Where a train should be now, on a small map of the line from Parbatipur
/// to Santahar and as a station list. It is worked out from the timetable;
/// the SMS button asks the railway for the real position.
class TrainLiveScreen extends StatefulWidget {
  const TrainLiveScreen({super.key, this.train, this.run});
  final Train? train;
  final TrainRun? run;

  @override
  State<TrainLiveScreen> createState() => _TrainLiveScreenState();
}

class _TrainLiveScreenState extends State<TrainLiveScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  (Train, TrainRun)? _pick;

  @override
  void initState() {
    super.initState();
    if (widget.train != null && widget.run != null) _pick = (widget.train!, widget.run!);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>().catalog;
    final data = catalog.transport;
    final rail = data.rail;
    // Runs with a known Joypurhat time, the next one first.
    final deps = upcomingDepartures(data.trains, _now, graceMinutes: 120);
    // By default the train nearest to Joypurhat in time.
    final nearest = deps.isEmpty
        ? null
        : deps.reduce((a, b) => a.minutesAway.abs() <= b.minutesAway.abs() ? a : b);
    final pick = _pick ?? (nearest == null ? null : (nearest.train, nearest.run));
    final pickIndex = pick == null ? -1 : deps.indexWhere((d) => identical(d.run, pick.$2));
    final est = pick == null ? null : estimatePosition(data.line, pick.$2, _now);
    final offToday = pick != null && pick.$2.offDay != null && pick.$2.offDay == weekdayIndex(_now);

    return Scaffold(
      appBar: AppBar(title: const Text('ট্রেন এখন কোথায়')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const NoteBanner(
            'সময়সূচি থেকে হিসাব করা আনুমানিক অবস্থান। ট্রেন দেরিতে চললে আসল অবস্থান আলাদা হবে; '
            'নিশ্চিত হতে নিচের বাটনে রেলের এসএমএস সেবা ব্যবহার করুন।',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: pickIndex < 0 ? null : pickIndex,
                hint: const Text('ট্রেন বাছাই করুন'),
                items: [
                  for (final (i, d) in deps.indexed)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${d.train.name} (${bn(d.run.number)}), ${d.run.to} এর দিকে',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (i) => setState(() => _pick = i == null ? null : (deps[i].train, deps[i].run)),
              ),
            ),
          ),
          if (pick != null && est != null) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Pill('আনুমানিক', icon: Icons.schedule, bg: AppColors.infoBg, fg: AppColors.infoText),
                      if (offToday) const Pill('আজ সাপ্তাহিক বন্ধ', bg: AppColors.dangerBg, fg: AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(est.headline, style: const TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(est.detail, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSoft)),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 1.15,
                    child: _LineMap(line: data.line, estimate: est, south: goesSouth(pick.$2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('${pick.$1.name}: স্টেশনে আনুমানিক সময়'),
                  for (final (i, s) in (goesSouth(pick.$2) ? data.line : data.line.reversed).indexed)
                    _StationRow(
                      name: s.name,
                      time: est.stationTimes[data.line.indexOf(s)],
                      passed: est.passed[data.line.indexOf(s)],
                      home: s.min == 0,
                      divider: i < data.line.length - 1,
                    ),
                ],
              ),
            ),
          ],
          if (pick != null) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('আসল অবস্থান জানুন'),
                  Text(
                    '${phoneBn(rail.smsNumber)} নম্বরে "${rail.smsBody(pick.$2.number)}" লিখে এসএমএস করুন। '
                    'ফিরতি এসএমএসে ট্রেনের অবস্থান, পরের স্টেশন ও কত দেরি জানাবে।',
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => Launch.sms(context, rail.smsNumber, rail.smsBody(pick.$2.number)),
                    icon: const Icon(Icons.sms_outlined),
                    label: Text('এসএমএস লিখুন (${rail.smsBody(bn(pick.$2.number))})'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Launch.call(context, rail.callCentre),
                    icon: const Icon(Icons.call_outlined),
                    label: Text('রেলের কল সেন্টার ${bn(rail.callCentre)}'),
                  ),
                  if (rail.smsNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(rail.smsNote, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SourcesPanel(sources: rail.sources, checked: catalog.checked, note: data.note),
        ],
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.name, required this.time, required this.passed, required this.home, required this.divider});
  final String name;
  final DateTime time;
  final bool passed;
  final bool home;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20, color: passed ? AppColors.success : AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: TextStyle(fontSize: 15, fontWeight: home ? FontWeight.w800 : FontWeight.w500,
                    color: home ? Group.blue.deep : AppColors.text)),
          ),
          Text(hmBnOf(time),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: passed ? AppColors.muted : AppColors.text)),
        ],
      ),
    );
  }
}

/// The drawn line with stations and the train marker.
class _LineMap extends StatelessWidget {
  const _LineMap({required this.line, required this.estimate, required this.south});
  final List<LineStation> line;
  final LiveEstimate estimate;
  final bool south;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        Offset at(double x, double y) => Offset(w * x / 100 * 1.3 - w * 0.15, h * y / 100);
        final train = at(estimate.x, estimate.y);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _LinePainter(line, at, estimate.passed))),
              for (final s in line)
                Positioned(
                  left: at(s.x, s.y).dx + 12,
                  top: at(s.x, s.y).dy - 10,
                  right: 4,
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: s.min == 0 ? 13.5 : 12.5,
                      fontWeight: s.min == 0 ? FontWeight.w800 : FontWeight.w600,
                      color: s.min == 0 ? Group.blue.deep : AppColors.textSoft,
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: still ? Duration.zero : const Duration(milliseconds: 1200),
                curve: Curves.easeInOutCubic,
                left: train.dx - 17,
                top: train.dy - 17,
                child: Semantics(
                  label: estimate.headline,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: estimate.onLine ? const Color(0xFFEA580C) : AppColors.muted,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Icon(south ? Icons.south : Icons.north, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.line, this.at, this.passed);
  final List<LineStation> line;
  final Offset Function(double x, double y) at;
  final List<bool> passed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFF6FF));
    // A soft river and fields so the map does not look empty.
    final river = Path()
      ..moveTo(size.width * 0.9, 0)
      ..cubicTo(size.width * 0.75, size.height * 0.3, size.width * 0.98, size.height * 0.6, size.width * 0.82, size.height);
    canvas.drawPath(
        river,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFFBFDBFE));
    final pts = [for (final s in line) at(s.x, s.y)];
    final track = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      track.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        track,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF94A3B8));
    canvas.drawPath(
        track,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
    for (final (i, s) in line.indexed) {
      final home = s.min == 0;
      canvas.drawCircle(pts[i], home ? 9 : 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          pts[i],
          home ? 9 : 6.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = home ? const Color(0xFF0369A1) : (passed[i] ? const Color(0xFF16A34A) : const Color(0xFF64748B)));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.passed != passed;
}
