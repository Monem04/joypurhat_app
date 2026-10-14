import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transport.dart';
import '../../providers/catalog_provider.dart';
import '../../services/launcher.dart';
import '../../services/train_schedule.dart';
import '../../theme.dart';
import '../../utils/bn.dart';
import '../../widgets/common.dart';
import '../../widgets/report.dart';
import 'train_live_screen.dart';

/// One train: its times at Joypurhat both ways, off days, fares and tickets.
class TrainDetailScreen extends StatelessWidget {
  const TrainDetailScreen({super.key, required this.train});
  final Train train;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>().catalog;
    final rail = catalog.transport.rail;
    final station = catalog.transport.place('Joypurhat Railway Station');
    final t = train;
    return Scaffold(
      appBar: AppBar(title: const Text('ট্রেনের তথ্য')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Row(
              children: [
                const IconBox(Icons.train_outlined, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      if (t.nameEn.isNotEmpty)
                        Text(t.nameEn, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(t.termini, style: const TextStyle(fontSize: 14.5, color: AppColors.textSoft)),
                      if (t.confidence == 'low') ...[const SizedBox(height: 6), const CheckBadge()],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (t.offNote.isNotEmpty) ...[const SizedBox(height: 12), NoteBanner(t.offNote, icon: Icons.warning_amber_outlined)],
          for (final r in t.runs) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('${bn(r.number)} নং: ${r.origin} থেকে ${r.to}'),
                  if (r.arr.isEmpty && r.dep.isEmpty)
                    const Text('জয়পুরহাটে থামার সময় যাচাই করা যায়নি। স্টেশনে বা ১৩১ নম্বরে জেনে নিন।',
                        style: TextStyle(fontSize: 14, color: AppColors.muted))
                  else ...[
                    if (r.arr.isNotEmpty)
                      InfoLine(icon: Icons.login, label: 'জয়পুরহাটে পৌঁছায়', value: hmBn(r.arr)),
                    if (r.dep.isNotEmpty)
                      InfoLine(icon: Icons.logout, label: 'জয়পুরহাট থেকে ছাড়ে', value: hmBn(r.dep)),
                  ],
                  InfoLine(
                    icon: Icons.event_busy_outlined,
                    label: 'সাপ্তাহিক বন্ধ (${r.origin} থেকে ছাড়ার দিন)',
                    value: offDayText(r),
                    divider: false,
                  ),
                  const SizedBox(height: 8),
                  if (r.time.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TrainLiveScreen(train: t, run: r)),
                        ),
                        icon: const Icon(Icons.share_location_outlined),
                        label: const Text('এখন আনুমানিক কোথায়'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Launch.sms(context, rail.smsNumber, rail.smsBody(r.number)),
                      icon: const Icon(Icons.share_location_outlined),
                      label: Text('ট্রেন কোথায় আছে? (এসএমএস ${bn(rail.smsNumber)})'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          for (final f in t.fares) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('ভাড়া: জয়পুরহাট থেকে ${f.to}'),
                  for (final (i, cl) in f.classes.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        border: i < f.classes.length - 1
                            ? const Border(bottom: BorderSide(color: AppColors.divider))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(cl.cls, style: const TextStyle(fontSize: 14.5))),
                          Text(cl.fare,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text('ভাড়া আসন ও সময়ভেদে বদলায়। সঠিক ভাড়া টিকিট কাটার সময় দেখাবে।',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('টিকিট'),
                FilledButton.icon(
                  onPressed: () => Launch.web(context, rail.ticketUrl),
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('অনলাইনে টিকিট কাটুন'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Launch.playStore(context, rail.appPackage),
                  icon: const Icon(Icons.install_mobile_outlined),
                  label: Text('${rail.appName} অ্যাপ'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Launch.call(context, rail.callCentre),
                      icon: const Icon(Icons.call_outlined),
                      label: Text('কল ${bn(rail.callCentre)}'),
                    ),
                  ),
                  if (station != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Launch.map(context, query: station.mapQuery, lat: station.lat, lng: station.lng),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('স্টেশন'),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                const Text('স্টেশনের কাউন্টারেও টিকিট পাওয়া যায়।',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                if (rail.ticketNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NoteBanner(rail.ticketNote,
                      icon: Icons.gpp_maybe_outlined, bg: AppColors.warnBg, fg: AppColors.warnText),
                ],
              ],
            ),
          ),
          if (rail.smsNote.isNotEmpty) ...[const SizedBox(height: 12), NoteBanner(rail.smsNote)],
          const SizedBox(height: 12),
          SourcesPanel(sources: t.sources, checked: catalog.checked, note: catalog.transport.note),
          Align(alignment: Alignment.centerLeft, child: ReportButton(about: 'ট্রেন: ${t.name}')),
        ],
      ),
    );
  }
}
