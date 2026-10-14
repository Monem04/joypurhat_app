import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/booking.dart';
import '../../services/launcher.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';

/// A bus ticket with a QR code the counter can scan.
class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.booking});
  final Booking booking;

  String get _shareText {
    final b = StringBuffer('${booking.title}\n${booking.codeLabel}: ${booking.code}\n');
    for (final r in booking.rows) {
      b.writeln('${r.$1}: ${r.$2}');
    }
    if (booking.isDemo) b.writeln('(ডেমো টিকিট, আসল নয়)');
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Scaffold(
      appBar: AppBar(title: const Text('টিকিট')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (b.isDemo) ...[
            const DemoBanner('এটি ডেমো টিকিট। এটি দিয়ে বাসে ওঠা যাবে না।'),
            const SizedBox(height: 12),
          ],
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(b.status, style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 14)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      QrImageView(
                        data: 'JOYPURHAT|${b.code}|${b.id}',
                        size: 180,
                        backgroundColor: Colors.white,
                        semanticsLabel: 'টিকিটের কিউআর কোড',
                      ),
                      const SizedBox(height: 6),
                      Text(b.codeLabel, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      Text(bn(b.code),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(height: 10),
                      for (final (i, r) in b.rows.indexed)
                        InfoLine(icon: Icons.chevron_right, label: r.$1, value: r.$2, divider: i < b.rows.length - 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const NoteBanner('বাস ছাড়ার অন্তত ৩০ মিনিট আগে কাউন্টারে এসে টিকিটের কিউআর কোড বা নম্বর দেখান।'),
        ],
      ),
      bottomNavigationBar: BottomAction(
        label: 'হোমে ফিরুন',
        icon: Icons.home_outlined,
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        leading: OutlinedButton.icon(
          onPressed: () => Launch.share(_shareText, subject: b.title),
          icon: const Icon(Icons.share_outlined),
          label: const Text('শেয়ার'),
        ),
      ),
    );
  }
}
