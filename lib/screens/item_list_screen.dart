import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/item_cards.dart';
import '../widgets/motion.dart';
import 'booking/booking_form_screen.dart';
import 'category_router.dart';
import 'doctors_screen.dart';
import 'home_screen.dart' show AccentLine;

/// Cards for one service: hospitals, banks, hotels and the rest.
class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key, required this.category});
  final Category category;

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  String _tag = '';
  bool _searching = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogProvider>();
    final c = widget.category;
    final all = provider.itemsOf(c);
    // Only chips that have cards in this mode; demo-only tags stay hidden.
    final tags = c.filters.skip(1).where((t) => all.any((i) => i.tag == t)).toList();
    final showFilters = tags.length > 1 || (tags.length == 1 && all.any((i) => i.tag != tags.first));
    final tag = showFilters && tags.contains(_tag) ? _tag : '';
    final items = all.where((i) {
      if (tag.isNotEmpty && i.tag != tag) return false;
      if (_q.isNotEmpty && !i.searchText.contains(_q.toLowerCase())) return false;
      return true;
    }).toList();
    final doctorCount = c.isMedical ? all.fold<int>(0, (a, i) => a + i.doctors.length) : 0;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: InputDecoration(
                  hintText: '${c.title} থেকে খুঁজুন',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              )
            : Text(c.title),
        bottom: AccentLine(Group.of(c.color)),
        actions: [
          IconButton(
            tooltip: _searching ? 'খোঁজা বন্ধ করুন' : 'খুঁজুন',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _q = '';
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          if (showFilters) ...[
            FilterBar(
              filters: [c.filters.first, ...tags],
              selected: tag.isEmpty ? 0 : tags.indexOf(tag) + 1,
              onSelected: (i) => setState(() => _tag = i == 0 ? '' : tags[i - 1]),
            ),
            const SizedBox(height: 12),
          ],
          if (c.isMedical && doctorCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Panel(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorsScreen())),
                  child: Row(
                    children: [
                      const IconBox(Icons.person_search_outlined, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ডাক্তার খুঁজুন', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                            Text('বিশেষজ্ঞতা বা নাম দিয়ে, জেলার ${bn(provider.catalog.doctors.length)} জন ডাক্তার',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          if (c.post != null && c.post!.bannerTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PostBanner(category: c, form: c.post!),
            ),
          if (c.note.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: NoteBanner(c.note)),
          if (c.links.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _Links(c.links)),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${bn(items.length)}${c.unit.isEmpty ? 'টি' : c.unit}',
                  style: const TextStyle(fontSize: 13.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ItemCard(category: c, item: item),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: all.isEmpty
                  ? EmptyState(
                      icon: iconFor(c.icon),
                      title: 'তথ্য যোগ হচ্ছে',
                      text: emptyTextFor(c),
                      actionLabel: c.post != null ? c.post!.title : (c.key == 'shopreg' ? null : 'Shop দিতে চাই'),
                      onAction: () => c.post != null ? openPostForm(context, c) : openCategoryKey(context, 'shopreg'),
                    )
                  : const EmptyState(
                      icon: Icons.search_off,
                      title: 'কিছু পাওয়া যায়নি',
                      text: 'অন্য ফিল্টার বা শব্দ দিয়ে দেখুন।',
                    ),
            ),
        ],
      ),
    );
  }
}

/// Opens the To-Let form of a rent category.
void openPostForm(BuildContext context, Category c) {
  final form = c.post!;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BookingFormScreen(
      config: form,
      target: BookingTarget.support(title: form.title, sub: form.sub, icon: c.icon, color: c.color),
    ),
  ));
}

/// "বাসা খালি? To-Let দিন": the invitation for landlords at the top of the list.
class _PostBanner extends StatelessWidget {
  const _PostBanner({required this.category, required this.form});
  final Category category;
  final FormConfig form;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(category.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: g.shadow, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Pressable(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openPostForm(context, category),
        child: Ink(
          decoration: BoxDecoration(gradient: g.gradient, borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.campaign_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(form.bannerTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                      if (form.bannerSub.isNotEmpty)
                        Text(form.bannerSub, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Websites with more listings for this service, opened in the browser.
class _Links extends StatelessWidget {
  const _Links(this.links);
  final List<WebLink> links;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text('অনলাইনে আরো দেখুন', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          for (final l in links)
            ListTile(
              leading: const Icon(Icons.open_in_new, color: AppColors.accent),
              title: Text(l.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              subtitle: l.sub.isEmpty ? null : Text(l.sub, style: const TextStyle(fontSize: 12.5, height: 1.4)),
              onTap: () => Launch.web(context, l.url),
            ),
        ],
      ),
    );
  }
}
