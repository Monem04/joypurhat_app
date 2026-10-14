import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';

/// A reading page, used for the district history.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final a = category.article;
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: a == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(icon: iconFor(category.icon), title: 'তথ্য যোগ হচ্ছে', text: 'শীঘ্রই এখানে পড়তে পারবেন।'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBox(iconFor(category.icon), size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(a.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(a.sub, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSoft)),
                    ],
                  ),
                ),
                if (a.facts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final f in a.facts)
                            SizedBox(
                              width: w,
                              child: Panel(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.$1, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                    const SizedBox(height: 3),
                                    Text(f.$2,
                                        style: const TextStyle(
                                            fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                for (final p in a.parts) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(p.$1),
                        Text(p.$2, style: const TextStyle(fontSize: 15, height: 1.6)),
                      ],
                    ),
                  ),
                ],
                for (final g in a.groups) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [SectionTitle(g.$1), ChipsWrap(g.$2)],
                    ),
                  ),
                ],
                if (a.source.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  NoteBanner(a.source, icon: Icons.verified_outlined),
                ],
              ],
            ),
    );
  }
}
