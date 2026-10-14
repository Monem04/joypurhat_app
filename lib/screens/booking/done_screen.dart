import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../services/launcher.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';
import '../bookings_screen.dart';

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.booking, required this.title, required this.message});
  final Booking booking;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সম্পন্ন'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.successBg,
                  child: Icon(Icons.check_rounded, size: 40, color: AppColors.success),
                ),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.textSoft)),
                if (booking.code.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Text(booking.codeLabel, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(bn(booking.code),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                InfoLine(icon: Icons.event_note_outlined, label: 'কী', value: booking.title),
                if (booking.place.isNotEmpty)
                  InfoLine(icon: Icons.place_outlined, label: 'কোথায়', value: booking.place),
                for (final (i, r) in booking.rows.indexed)
                  InfoLine(
                    icon: Icons.chevron_right,
                    label: r.$1,
                    value: r.$2,
                    divider: i < booking.rows.length - 1,
                  ),
              ],
            ),
          ),
          if (booking.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Launch.call(context, booking.phone),
              icon: const Icon(Icons.call_outlined),
              label: Text('${phoneBn(booking.phone)} নম্বরে কল করুন'),
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
