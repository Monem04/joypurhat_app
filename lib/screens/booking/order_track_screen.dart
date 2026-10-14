import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../services/launcher.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../bookings_screen.dart';

/// The demo food order tracker: five steps that move on with the clock.
/// It is a simulation and says so; no restaurant sends these updates yet.
class OrderTrackScreen extends StatefulWidget {
  const OrderTrackScreen({super.key, required this.booking});
  final Booking booking;

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final steps = b.steps;
    final at = b.stepAt(_now);
    final done = at == steps.length - 1;
    const orange = Group.orange;
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার ট্র্যাক')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: orange.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: orange.shadow, blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${b.codeLabel}: ${bn(b.code)}',
                    style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(steps[at].title,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                Text(
                  done
                      ? steps[at].note
                      : '${b.pickup ? 'তৈরি হবে' : 'পৌঁছাবে'} আনুমানিক ${timeOfBn(b.readyAt)}',
                  style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 14.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const DemoBanner(
              'ডেমো: অর্ডারটি কোথাও যায়নি। ধাপগুলো সময় ধরে নিজে নিজে এগোয়, রেস্টুরেন্ট অ্যাপে যুক্ত হলে আসল খবর দেখাবে।'),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                for (final (i, s) in steps.indexed)
                  _StepRow(step: s, state: i < at ? 0 : (i == at ? 1 : 2), last: i == steps.length - 1, at: b.createdAt),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final (i, r) in b.rows.indexed)
                  InfoLine(icon: Icons.chevron_right, label: r.$1, value: r.$2, divider: i < b.rows.length - 1),
              ],
            ),
          ),
          if (b.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Launch.call(context, b.phone),
              icon: const Icon(Icons.call_outlined),
              label: const Text('রেস্টুরেন্টে কল করুন'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomAction(
        label: 'হোমে ফিরুন',
        icon: Icons.home_outlined,
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        leading: OutlinedButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BookingsScreen()),
          ),
          child: const Text('আমার বুকিং'),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.state, required this.last, required this.at});
  final TrackStep step;

  /// 0 done, 1 now, 2 still to come.
  final int state;
  final bool last;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFEA580C);
    final done = state == 0;
    final now = state == 1;
    final dot = now
        ? const GlowDot(color: orange, size: 24, child: Icon(Icons.circle, size: 9, color: Colors.white))
        : Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: done ? AppColors.success : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: done ? AppColors.success : AppColors.border, width: 2),
            ),
            child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
          );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: done ? AppColors.success : AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: state == 2 ? AppColors.muted : AppColors.text)),
                  Text(
                    state == 2 ? step.note : '${step.note} · ${timeOfBn(at.add(Duration(minutes: step.minute)))}',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
