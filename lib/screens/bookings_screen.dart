import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking.dart';
import '../providers/booking_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';
import 'booking/order_track_screen.dart';
import 'transport/ticket_screen.dart';

/// Serials, bookings, orders and tickets made from this phone.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<BookingProvider>().items;
    return Scaffold(
      appBar: AppBar(title: const Text('আমার বুকিং')),
      body: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: EmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'এখনো কোনো বুকিং নেই',
                  text: 'ডাক্তারের সিরিয়াল, হোটেল, রেস্টুরেন্ট বা অন্য বুকিং করলে এখানে দেখাবে।',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const NoteBanner('বুকিংয়ের তালিকা শুধু এই ফোনে রাখা আছে। অ্যাপ মুছে ফেললে তালিকাও মুছে যাবে।'),
                const SizedBox(height: 12),
                for (final b in items) ...[
                  _BookingCard(booking: b),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

IconData _iconFor(String kind) {
  switch (kind) {
    case 'serial':
      return Icons.medical_services_outlined;
    case 'order':
      return Icons.shopping_bag_outlined;
    case 'request':
      return Icons.storefront_outlined;
    case 'ticket':
      return Icons.confirmation_number_outlined;
    default:
      return Icons.event_available_outlined;
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('তালিকা থেকে মুছবেন?'),
        content: const Text('এটি শুধু এই ফোনের তালিকা থেকে মুছবে। বুকিং বাতিল করতে প্রতিষ্ঠানে ফোন করুন।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('মুছুন')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<BookingProvider>().remove(booking.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (b.isTicket) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketScreen(booking: b)));
          } else if (b.track) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderTrackScreen(booking: b)));
          } else {
            _showDetails(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(_iconFor(b.kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (b.place.isNotEmpty)
                      Text(b.place, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Pill(b.track ? '${b.steps[b.stepAt(DateTime.now())].title} (ডেমো)' : b.status,
                          bg: b.isDemo ? AppColors.warnBg : AppColors.successBg,
                          fg: b.isDemo ? AppColors.warnText : AppColors.successText),
                      if (b.code.isNotEmpty) Pill('${b.codeLabel}: ${bn(b.code)}', bg: AppColors.surfaceAlt, fg: AppColors.textSoft),
                    ]),
                    const SizedBox(height: 6),
                    Text('${dateBn(b.createdAt)}, ${timeOfBn(b.createdAt)}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'তালিকা থেকে মুছুন',
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final b = booking;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (b.place.isNotEmpty) Text(b.place, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              if (b.code.isNotEmpty) InfoLine(icon: Icons.tag, label: b.codeLabel, value: bn(b.code)),
              InfoLine(icon: Icons.info_outline, label: 'অবস্থা', value: b.status),
              for (final r in b.rows) InfoLine(icon: Icons.chevron_right, label: r.$1, value: r.$2),
              InfoLine(
                icon: Icons.schedule_outlined,
                label: 'তৈরি',
                value: '${fullDateBn(b.createdAt)}, ${timeOfBn(b.createdAt)}',
                divider: false,
              ),
              if (b.phone.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Launch.call(context, b.phone),
                    icon: const Icon(Icons.call),
                    label: Text('${phoneBn(b.phone)} নম্বরে কল করুন'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
