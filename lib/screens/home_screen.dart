import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/doctor_card.dart';
import '../widgets/motion.dart';
import 'app_drawer.dart';
import 'category_router.dart';
import 'doctors_screen.dart';
import 'notices_screen.dart';

/// Home: search, the announcement ticker, one-tap emergency calls, then the
/// services in coloured sections. A search shows one flat list of matching
/// services and doctors instead.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};
  String _jumped = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String title) => _sectionKeys.putIfAbsent(title, GlobalKey.new);

  void _jumpTo(String title) {
    setState(() => _jumped = title);
    final ctx = _sectionKeys[title]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final query = _search.text.trim();
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place, color: AppColors.primary),
            SizedBox(width: 6),
            Text(AppConfig.appName),
          ],
        ),
        bottom: const AccentLine(Group.teal),
      ),
      body: CustomScrollView(
        // Lays out every section, so the section chips can jump to any.
        //scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'সেবা বা ডাক্তারের নাম খুঁজুন',
                  prefixIcon: const Icon(Icons.search),
                  fillColor: AppColors.surface,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'খোঁজা মুছুন',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
          ),
          if (query.isEmpty) ..._sections(context, catalog) else ..._results(context, catalog, query),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, CatalogProvider catalog) {
    final sections = catalog.homeSections;
    final ticker = catalog.catalog.ticker;
    var tileIndex = 0;
    return [
      if (ticker.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _TickerCard(lines: ticker),
          ),
        ),
      const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: EmergencyStrip()),
      ),
      if (AppConfig.demoMode)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DemoBanner(
                'ডেমো মোড চালু: নমুনা দোকান, রেস্টুরেন্টের মেনু ও বাস বুকিং দেখাচ্ছে। Play Store এর জন্য বিল্ড করার আগে ডেমো মোড বন্ধ রাখুন।'),
          ),
        ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = sections[i].$1;
              return _SectionChip(section: s, on: _jumped == s.title, onTap: () => _jumpTo(s.title));
            },
          ),
        ),
      ),
      for (final (s, cats) in sections)
        SliverToBoxAdapter(
          child: Padding(
            key: _keyFor(s.title),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _SectionPanel(section: s, categories: cats, firstIndex: (tileIndex += cats.length) - cats.length),
          ),
        ),
    ];
  }

  List<Widget> _results(BuildContext context, CatalogProvider catalog, String query) {
    final tiles = catalog.searchCategories(query);
    final doctors = catalog.searchDoctors(query).where((d) => d.chambers.isNotEmpty).toList();
    const shown = 5;
    return [
      if (doctors.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _CountTitle('ডাক্তার', '${bn(doctors.length)} জন'),
          ),
        ),
        for (final d in doctors.take(shown))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DoctorCard(doctor: d, chamber: d.chambers.first, showPlace: true),
            ),
          ),
        if (doctors.length > shown)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => DoctorsScreen(initialQuery: query))),
                icon: const Icon(Icons.person_search_outlined),
                label: Text('সব ${bn(doctors.length)} জন ডাক্তার দেখুন'),
              ),
            ),
          ),
      ],
      if (tiles.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _CountTitle('সেবা', '${bn(tiles.length)}টি পাওয়া গেছে'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TileWrap(categories: tiles, columns: 3, card: true),
          ),
        ),
      ],
      if (tiles.isEmpty && doctors.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: EmptyState(
              icon: Icons.search_off,
              title: 'কিছু পাওয়া যায়নি',
              text: 'অন্য শব্দ দিয়ে খুঁজুন, যেমন: ডাক্তার, বাস, ব্যাংক, শিশু।',
            ),
          ),
        ),
    ];
  }
}

class _CountTitle extends StatelessWidget {
  const _CountTitle(this.title, this.count);
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        Text(count, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}

/// A thin gradient line under an app bar, in the screen's colour group.
class AccentLine extends StatelessWidget implements PreferredSizeWidget {
  const AccentLine(this.group, {super.key});
  final Group group;

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) =>
      Container(height: 3, decoration: BoxDecoration(gradient: group.gradient));
}

class _TickerCard extends StatelessWidget {
  const _TickerCard({required this.lines});
  final List<TickerLine> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0D10201F), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F10201F), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Pressable(
        color: AppColors.surface,
        semanticLabel: 'ঘোষণা, সব নোটিশ দেখুন',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoticesScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 9, 6, 9),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: Color(0x400F766E), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 5),
                    Text('ঘোষণা', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExcludeSemantics(
                  child: NewsTicker(lines: [for (final l in lines) (l.text, Group.of(l.color).dark)]),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// "বিপদে এক চাপে কল করুন": 999, fire service and the health line.
class EmergencyStrip extends StatelessWidget {
  const EmergencyStrip({super.key});

  static const calls = [
    ('৯৯৯', 'পুলিশ, ফায়ার, অ্যাম্বুলেন্স', '999', 'জাতীয় জরুরি সেবা'),
    ('১৬১৬৩', 'ফায়ার সার্ভিস', '16163', 'ফায়ার সার্ভিস হটলাইন'),
    ('১৬২৬৩', 'ডাক্তারের পরামর্শ', '16263', 'স্বাস্থ্য বাতায়ন'),
  ];

  @override
  Widget build(BuildContext context) {
    const deep = Color(0xFFBE123C);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(gradient: Group.red.gradient, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.emergency_outlined, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('বিপদে এক চাপে কল করুন',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF881337))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, c) in calls.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x14881337), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Pressable(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      semanticLabel: '${c.$4}, ${c.$1} নম্বরে কল করুন',
                      onTap: () => Launch.call(context, c.$3),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 76),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call, size: 15, color: deep),
                                      const SizedBox(width: 4),
                                      Text(c.$1,
                                          style: const TextStyle(
                                              fontSize: 19, height: 1.2, fontWeight: FontWeight.w700, color: deep)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  c.$2,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF4C0519)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.section, required this.on, required this.onTap});
  final HomeSection section;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(section.color);
    return Semantics(
      selected: on,
      child: Pressable(
        color: on ? g.deep : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? g.deep : const Color(0xFFD6E6E4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: on ? Colors.white : g.deep, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(section.title,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.textSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.section, required this.categories, required this.firstIndex});
  final HomeSection section;
  final List<Category> categories;

  /// Position of the first tile on the page, for the staggered entrance.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(section.color);
    return Semantics(
      container: true,
      label: section.title,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(gradient: g.gradient, borderRadius: BorderRadius.circular(11)),
                    child: Icon(iconFor(section.icon), size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title, style: const TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w700)),
                        Text(section.sub, style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: g.soft, borderRadius: BorderRadius.circular(999)),
                    child: Text('${bn(categories.length)}টি',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g.deep)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _TileWrap(categories: categories, columns: 4, firstIndex: firstIndex),
          ],
        ),
      ),
    );
  }
}

/// Service tiles in equal columns that grow with the text size.
class _TileWrap extends StatelessWidget {
  const _TileWrap({required this.categories, required this.columns, this.card = false, this.firstIndex = 0});
  final List<Category> categories;
  final int columns;

  /// White card tiles (search results) instead of bare ones (sections).
  final bool card;
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final gap = card ? 10.0 : 4.0;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, c) in categories.indexed)
              SizedBox(
                width: w,
                child: PopIn(
                  delay: Duration(milliseconds: ((firstIndex + i) * 22).clamp(0, 600)),
                  child: ServiceTile(category: c, card: card),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A service on the home screen: a glossy gradient icon and its name.
class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.category, this.card = false});
  final Category category;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(category.color);
    final size = card ? 54.0 : 50.0;
    final tile = Pressable(
      color: card ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(card ? 18 : 14),
      onTap: () => openCategory(context, category),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: card ? 120 : 96),
        child: Padding(
          padding: card ? const EdgeInsets.fromLTRB(6, 14, 6, 12) : const EdgeInsets.fromLTRB(2, 8, 2, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: g.gradient,
                  borderRadius: BorderRadius.circular(size * 0.32),
                  boxShadow: [BoxShadow(color: g.shadow, blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Stack(
                  children: [
                    // A soft highlight in the top corner gives the icon its gloss.
                    Positioned(
                      left: size * 0.12,
                      top: size * 0.1,
                      child: Transform.rotate(
                        angle: -0.31,
                        child: Container(
                          width: size * 0.36,
                          height: size * 0.18,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    Center(child: Icon(iconFor(category.icon), color: Colors.white, size: size * 0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
    if (!card) return tile;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0D10201F), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0D10201F), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: tile,
    );
  }
}
