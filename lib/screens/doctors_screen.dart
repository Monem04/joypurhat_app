import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';
import 'doctor_detail_screen.dart';

/// Every doctor in the district, searchable and grouped by specialty.
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key, this.initialQuery = ''});

  /// The words already typed in the home search.
  final String initialQuery;

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  int _group = 0;
  late String _q = widget.initialQuery.trim();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogProvider>();
    final groups = ['সব', ...provider.doctorGroups];
    final group = _group < groups.length ? groups[_group] : 'সব';
    final q = _q.toLowerCase();
    final doctors = provider.catalog.doctors.where((d) {
      if (group != 'সব' && d.group != group) return false;
      if (q.isNotEmpty && !d.searchText.contains(q)) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ডাক্তার খুঁজুন')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextFormField(
              initialValue: widget.initialQuery,
              onChanged: (v) => setState(() => _q = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'নাম, রোগ বা চেম্বার দিয়ে খুঁজুন',
                prefixIcon: Icon(Icons.search),
                fillColor: AppColors.surface,
              ),
            ),
          ),
          FilterBar(filters: groups, selected: _group, onSelected: (i) => setState(() => _group = i)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text('${bn(doctors.length)} জন ডাক্তার',
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          for (final d in doctors)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _DoctorRow(doctor: d),
            ),
          if (doctors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.person_search_outlined,
                title: 'কাউকে পাওয়া যায়নি',
                text: 'অন্য নাম বা বিশেষজ্ঞতা দিয়ে খুঁজুন, যেমন: শিশু, হৃদরোগ, গাইনি।',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: NoteBanner(
                'ডাক্তারদের চেম্বারের দিন ও সময় বিভিন্ন অনলাইন তালিকা থেকে নেওয়া, শেষ যাচাই ${fullDateBn(DateTime.parse(provider.catalog.checked))}। যাওয়ার আগে চেম্বারে ফোন করে নিশ্চিত হয়ে নিন।'),
          ),
        ],
      ),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final first = d.chambers.isEmpty ? null : d.chambers.first;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: d))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.tint,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (d.degrees.isNotEmpty)
                      Text(d.degrees,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSoft)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Pill(d.group, icon: Icons.medical_services_outlined),
                      if (d.confidence == 'low') const CheckBadge(),
                    ]),
                    if (first != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              d.chambers.length > 1
                                  ? '${first.name} ও আরও ${bn(d.chambers.length - 1)}টি চেম্বার'
                                  : first.name,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
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
