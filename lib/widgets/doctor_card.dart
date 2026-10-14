import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../screens/booking/booking_form_screen.dart';
import '../screens/doctor_detail_screen.dart';
import '../theme.dart';
import 'common.dart';

void openSerialBooking(BuildContext context, Doctor doctor, Chamber chamber, List<String> phones, {bool sample = false}) {
  final cfg = context.read<CatalogProvider>().catalog.docBook;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BookingFormScreen(
      config: cfg,
      target: BookingTarget(
        title: doctor.name,
        sub: [doctor.degrees, doctor.specialty].where((e) => e.isNotEmpty).join(' · '),
        place: chamber.name,
        price: chamber.fee.isEmpty ? '' : 'ভিজিট: ${chamber.fee}',
        phones: phones,
        icon: 'medbag',
        kind: 'serial',
        weekdays: chamber.weekdays,
        demoOnly: sample,
      ),
    ),
  ));
}

/// A doctor at one centre: degrees, days, time, fee, call and serial.
class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.doctor,
    required this.chamber,
    this.fallbackPhones = const [],
    this.sample = false,
    this.showPlace = false,
  });

  final Doctor doctor;
  final Chamber chamber;
  final List<String> fallbackPhones;
  final bool sample;

  /// Shows where this chamber is (search results, where the centre is not
  /// on screen already).
  final bool showPlace;

  List<String> get _phones => chamber.phones.isNotEmpty ? chamber.phones : fallbackPhones;

  @override
  Widget build(BuildContext context) {
    final phones = _phones;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: doctor.index < 0
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: doctor))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.tint,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      if (doctor.degrees.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(doctor.degrees,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
                        ),
                      if (doctor.specialty.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(doctor.specialty,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      if (showPlace && chamber.name.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.apartment_outlined, size: 16, color: AppColors.accent),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(chamber.name,
                                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                if (doctor.index >= 0) const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
          if (chamber.schedule.isNotEmpty || chamber.fee.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chamber.schedule.isNotEmpty)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.schedule_outlined, size: 17, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(chamber.schedule, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                    ]),
                  if (chamber.fee.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.payments_outlined, size: 17, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('ভিজিট: ${chamber.fee}',
                            style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
          if (doctor.confidence == 'low') ...[const SizedBox(height: 8), const CheckBadge()],
          const SizedBox(height: 10),
          Row(
            children: [
              if (phones.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => callNumbers(context, chamber.name, phones),
                    icon: const Icon(Icons.call_outlined, size: 19),
                    label: const Text('কল করুন'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openSerialBooking(context, doctor, chamber, phones, sample: sample),
                  icon: const Icon(Icons.event_available_outlined, size: 19),
                  label: const Text('সিরিয়াল দিন'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
