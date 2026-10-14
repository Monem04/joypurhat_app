import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';

/// App notices shipped with the data file.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<CatalogProvider>().catalog.notices;
    return Scaffold(
      appBar: AppBar(title: const Text('নোটিশ')),
      body: notices.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(icon: Icons.notifications_none, title: 'কোনো নোটিশ নেই', text: 'নতুন নোটিশ এলে এখানে দেখাবে।'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = notices[i];
                final date = DateTime.tryParse(n.date);
                return Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBox(Icons.campaign_outlined, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                if (date != null)
                                  Text(fullDateBn(date), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(n.body, style: const TextStyle(fontSize: 14.5, height: 1.55)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
