import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';

/// Emergency, fire, ambulance and helpline numbers.
class CallListScreen extends StatefulWidget {
  const CallListScreen({super.key, required this.category});
  final Category category;

  @override
  State<CallListScreen> createState() => _CallListScreenState();
}

class _CallListScreenState extends State<CallListScreen> {
  String _q = '';

  bool _matches(CallEntry e) {
    if (_q.isEmpty) return true;
    final hay = '${e.name} ${e.sub} ${e.numbers.join(' ')} ${e.numbers.map(phoneBn).join(' ')}'.toLowerCase();
    return hay.contains(_q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final checked = context.read<CatalogProvider>().catalog.checked;
    final sections = [
      for (final s in c.sections) CallSection(s.title, s.items.where(_matches).toList()),
    ].where((s) => s.items.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (c.hero != null) ...[
            _Hero(entry: c.hero!),
            const SizedBox(height: 12),
          ],
          TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(
              hintText: 'নাম বা নম্বর দিয়ে খুঁজুন',
              prefixIcon: Icon(Icons.search),
              fillColor: AppColors.surface,
            ),
          ),
          if (c.note.isNotEmpty) ...[const SizedBox(height: 12), NoteBanner(c.note)],
          for (final s in sections) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(s.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final (i, e) in s.items.indexed) _EntryRow(entry: e, divider: i < s.items.length - 1),
                ],
              ),
            ),
          ],
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyState(icon: Icons.search_off, title: 'কিছু পাওয়া যায়নি', text: 'অন্য নাম বা নম্বর দিয়ে খুঁজুন।'),
            ),
          if (c.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(c.tipsTitle.isEmpty ? 'জেনে রাখুন' : c.tipsTitle),
                  for (final (i, t) in c.tips.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.tint,
                            child: Text(bn(i + 1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t, style: const TextStyle(fontSize: 14.5, height: 1.45))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SourcesPanel(
            sources: {
              for (final s in c.sections)
                for (final e in s.items) ...e.sources,
            }.toList(),
            checked: checked,
            note: 'জাতীয় হটলাইনগুলো সরকারি নম্বর। জেলার নম্বর বিভিন্ন সরকারি তালিকা থেকে নেওয়া; একাধিক নম্বর থাকলে একটিতে না পেলে অন্যটিতে চেষ্টা করুন।',
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.entry});
  final CallEntry entry;

  @override
  Widget build(BuildContext context) {
    final number = entry.numbers.isEmpty ? '' : entry.numbers.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB42318), Color(0xFFD92D20)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(phoneBn(number),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                Text(entry.sub, style: const TextStyle(color: Color(0xFFFFE4E1), fontSize: 13.5)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${entry.name}, ${phoneBn(number)} নম্বরে কল করুন',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => callNumbers(context, entry.name, entry.numbers),
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.call, color: AppColors.danger, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.divider});
  final CallEntry entry;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Row(
        children: [
          IconBox(iconFor(entry.icon, Icons.call_outlined), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (entry.sub.isNotEmpty)
                  Text(entry.sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(entry.numbers.map(phoneBn).join(', '),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                if (entry.confidence == 'low')
                  const Padding(padding: EdgeInsets.only(top: 4), child: CheckBadge()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CallButton(name: entry.name, numbers: entry.numbers),
        ],
      ),
    );
  }
}
