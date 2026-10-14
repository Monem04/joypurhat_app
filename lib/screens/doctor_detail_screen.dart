import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';
import '../widgets/doctor_card.dart';
import '../widgets/report.dart';
import 'item_detail_screen.dart';

/// One doctor: degrees, every chamber with its days, call, map and serial.
class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CatalogProvider>();
    final d = doctor;
    final places = provider.placesOf(d);

    (Category, Item)? placeFor(Chamber c) {
      for (final p in places) {
        if (p.$2.doctors.any((x) => identical(x.chamber, c))) return p;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ডাক্তারের তথ্য')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.tint,
                      child: Icon(Icons.person, size: 32, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          if (d.nameEn.isNotEmpty)
                            Text(d.nameEn, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            if (d.group.isNotEmpty) Pill(d.group, icon: Icons.medical_services_outlined),
                            if (d.confidence == 'low') const CheckBadge(),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                if (d.degrees.isNotEmpty || d.specialty.isNotEmpty || d.designation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (d.degrees.isNotEmpty)
                    InfoLine(icon: Icons.school_outlined, label: 'ডিগ্রি', value: d.degrees),
                  if (d.specialty.isNotEmpty)
                    InfoLine(icon: Icons.healing_outlined, label: 'বিশেষজ্ঞতা', value: d.specialty),
                  if (d.designation.isNotEmpty)
                    InfoLine(icon: Icons.work_outline, label: 'পদবি', value: d.designation, divider: false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(d.chambers.length > 1 ? 'চেম্বার (${bn(d.chambers.length)}টি)' : 'চেম্বার',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
          for (final c in d.chambers) ...[
            _ChamberCard(doctor: d, chamber: c, place: placeFor(c)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          const NoteBanner('চেম্বারের দিন ও সময় বদলাতে পারে। যাওয়ার আগে ফোন করে নিশ্চিত হয়ে নিন।'),
          const SizedBox(height: 12),
          SourcesPanel(sources: d.sources, checked: provider.catalog.checked),
          Align(alignment: Alignment.centerLeft, child: ReportButton(about: 'ডাক্তার: ${d.name}')),
        ],
      ),
    );
  }
}

class _ChamberCard extends StatelessWidget {
  const _ChamberCard({required this.doctor, required this.chamber, required this.place});
  final Doctor doctor;
  final Chamber chamber;
  final (Category, Item)? place;

  @override
  Widget build(BuildContext context) {
    final c = chamber;
    final item = place?.$2;
    final phones = c.phones.isNotEmpty ? c.phones : (item?.phones ?? const <String>[]);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(Icons.local_hospital_outlined, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (c.upazila.isNotEmpty)
                      Text(c.upazila, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (c.address.isNotEmpty) InfoLine(icon: Icons.place_outlined, label: 'ঠিকানা', value: c.address),
          if (c.days.isNotEmpty) InfoLine(icon: Icons.calendar_today_outlined, label: 'দিন', value: c.days),
          if (c.time.isNotEmpty) InfoLine(icon: Icons.schedule_outlined, label: 'সময়', value: c.time),
          if (c.fee.isNotEmpty) InfoLine(icon: Icons.payments_outlined, label: 'ভিজিট', value: c.fee),
          for (final p in phones)
            InfoLine(
              icon: Icons.call_outlined,
              label: 'সিরিয়ালের ফোন',
              value: phoneBn(p),
              onTap: () => Launch.call(context, p),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (phones.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => callNumbers(context, c.name, phones),
                    icon: const Icon(Icons.call_outlined, size: 19),
                    label: const Text('কল'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Launch.map(
                    context,
                    query: item?.mapQuery.isNotEmpty == true
                        ? item!.mapQuery
                        : '${c.name}, ${c.address.isEmpty ? 'Joypurhat' : c.address}',
                    lat: item?.lat,
                    lng: item?.lng,
                  ),
                  icon: const Icon(Icons.map_outlined, size: 19),
                  label: const Text('ম্যাপ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openSerialBooking(context, doctor, c, phones, sample: item?.sample ?? false),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('সিরিয়াল দিন'),
            ),
          ),
          if (place != null)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ItemDetailScreen(category: place!.$1, item: place!.$2)),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('${place!.$2.name} এর সব তথ্য'),
            ),
        ],
      ),
    );
  }
}
