import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/app_icons.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/doctor_card.dart';
import '../widgets/item_cards.dart' show vacancyLabel;
import '../widgets/report.dart';
import 'booking/booking_form_screen.dart';
import 'home_screen.dart' show AccentLine;

/// Everything about one place, with call, map, booking and its doctors.
/// Places to visit and rentals open with a picture gallery.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.category, required this.item});
  final Category category;
  final Item item;

  FormConfig? get _book => item.book ?? category.book;

  BookingTarget _target({String? title, String? sub, String? price}) => BookingTarget(
        title: title ?? item.name,
        sub: sub ?? item.sub,
        place: title == null ? item.address : item.name,
        price: price ?? item.price,
        phones: item.phones,
        icon: item.icon.isEmpty ? category.icon : item.icon,
        color: category.color,
        kind: category.key == 'shop' ? 'order' : 'booking',
        services: item.menu,
        // Taken slots are known only for the invented sample parlours.
        bookedSlots: item.sample ? item.bookedSlots : const [],
        demoOnly: item.sample,
      );

  void _openBooking(BuildContext context, FormConfig cfg, BookingTarget target) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingFormScreen(config: cfg, target: target)));
  }

  String _shareText() {
    final b = StringBuffer(item.name);
    if (item.address.isNotEmpty) b.write('\n${item.address}');
    if (item.phones.isNotEmpty) b.write('\nফোন: ${item.phones.join(', ')}');
    if (item.time.isNotEmpty) b.write('\n${item.time}');
    b.write('\n\nJoypurhat অ্যাপ থেকে');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = category;
    final g = Group.of(c.color);
    final catalogChecked = context.read<CatalogProvider>().catalog.checked;
    final cfg = _book;
    // A real place can only get a request when there is a number to send it to.
    final canBook = cfg != null && c.template != 'doc' && (item.sample || item.phones.isNotEmpty);
    final canMap = item.showMap &&
        c.showMap &&
        (item.mapQuery.isNotEmpty || item.address.isNotEmpty || item.lat != null);
    // Any place with real photos gets the gallery; spots and rentals always do.
    final gallery = switch (c.card) {
      'photo' => _GalleryKind.place,
      'rent' => _GalleryKind.rent,
      _ => item.photos.isNotEmpty ? _GalleryKind.place : null,
    };

    final infoLines = <Widget>[
      if (item.address.isNotEmpty)
        InfoLine(
          icon: Icons.place_outlined,
          label: c.labelFor('address', 'ঠিকানা'),
          value: item.address,
          onTap: canMap ? () => _map(context) : null,
        ),
      if (item.time.isNotEmpty)
        InfoLine(icon: Icons.schedule_outlined, label: c.labelFor('time', 'সময়'), value: item.time),
      for (final p in item.phones)
        InfoLine(
          icon: Icons.call_outlined,
          label: c.labelFor('phone', 'ফোন'),
          value: phoneBn(p),
          onTap: () => Launch.call(context, p),
        ),
      if (item.price.isNotEmpty)
        InfoLine(icon: Icons.sell_outlined, label: c.labelFor('price', 'দাম'), value: item.price),
      for (final r in item.rows) InfoLine(icon: iconFor(r.icon, Icons.info_outline), label: r.label, value: r.value),
      if (item.website.isNotEmpty)
        InfoLine(
          icon: Icons.language_outlined,
          label: 'ওয়েবসাইট',
          value: SourcesPanel.host(item.website.startsWith('http') ? item.website : 'https://${item.website}'),
          onTap: () => Launch.web(context, item.website),
        ),
    ];

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gallery == null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: g.gradient,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [BoxShadow(color: g.shadow, blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Icon(iconFor(item.icon.isEmpty ? c.icon : item.icon), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: _titleBlock()),
            ],
          ),
        ] else
          _titleBlock(),
        if (item.tag.isNotEmpty || item.sample || item.isLowConfidence) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (item.sample) const SampleBadge(),
            if (item.tag.isNotEmpty) Pill(item.tag, bg: g.soft, fg: g.deep),
            if (item.isLowConfidence) const CheckBadge(),
          ]),
        ],
        const SizedBox(height: 14),
        _Actions(
          actions: [
            if (item.phones.isNotEmpty) _Act('কল করুন', Icons.call, () => callNumbers(context, item.name, item.phones)),
            if (canMap) _Act('ম্যাপে দেখুন', Icons.map_outlined, () => _map(context)),
            if (item.link != null) _Act(item.link!.label, Icons.open_in_new, () => Launch.web(context, item.link!.url)),
            _Act('শেয়ার', Icons.share_outlined, () => Launch.share(_shareText())),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(c.itemLabel.isEmpty ? c.title : c.itemLabel),
        bottom: AccentLine(g),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (gallery == null)
            Panel(child: header)
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: _Gallery(
                      scenes: gallery == _GalleryKind.rent ? const ['house', 'room', 'park'] : _placeScenes(),
                      captions: gallery == _GalleryKind.rent
                          ? const ['বাইরে থেকে', 'রুমের ভেতর', 'আশপাশ']
                          : const ['সামনে থেকে', 'চারপাশ', 'কাছ থেকে'],
                      name: item.name,
                      photos: item.photos,
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(16), child: header),
                ],
              ),
            ),
          if (item.sample && AppConfig.demoMode) ...[
            const SizedBox(height: 12),
            const DemoBanner('এটি নমুনা তথ্য, আসল প্রতিষ্ঠান নয়। আসল অ্যাপে শুধু যাচাই করা তথ্য দেখাবে।'),
          ],
          if (c.card == 'food' && !item.hasMenu) ...[
            const SizedBox(height: 12),
            const _NoMenu(),
          ],
          if (item.vacancy != null) ...[
            const SizedBox(height: 12),
            _VacancyPanel(item: item, group: g),
          ],
          if (infoLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: infoLines),
            ),
          ],
          if (item.note.isNotEmpty) ...[const SizedBox(height: 12), NoteBanner(item.note)],
          if (item.about.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextPanel(title: c.aboutTitle.isEmpty ? 'বিস্তারিত' : c.aboutTitle, text: item.about),
          ],
          if (item.howTo.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextPanel(title: 'কীভাবে যাবেন', text: item.howTo, icon: Icons.directions_outlined),
          ],
          if (item.chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [SectionTitle(c.chipsTitle.isEmpty ? 'সেবা' : c.chipsTitle), ChipsWrap(item.chips)],
              ),
            ),
          ],
          if (item.units.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(c.menuTitle.isEmpty ? 'রুমগুলো' : c.menuTitle),
                  for (final (i, u) in item.units.indexed)
                    _UnitLine(
                      unit: u,
                      divider: i < item.units.length - 1,
                      bookLabel: canBook && u.free ? (c.menuButton.isEmpty ? 'দেখতে চাই' : c.menuButton) : null,
                      onBook: () => _openBooking(context, cfg!, _target(title: u.name, sub: u.sub, price: u.rent)),
                    ),
                ],
              ),
            ),
          ],
          if (item.menu.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(item.menuTitle.isNotEmpty ? item.menuTitle : (c.menuTitle.isEmpty ? 'তালিকা' : c.menuTitle)),
                  for (final (i, m) in item.menu.indexed)
                    _MenuLine(
                      row: m,
                      divider: i < item.menu.length - 1,
                      bookLabel: (c.menuBook && canBook) ? (c.menuButton.isEmpty ? 'বুক' : c.menuButton) : null,
                      onBook: () => _openBooking(context, cfg!, _target(title: m.name, sub: m.sub, price: m.price)),
                    ),
                  if (item.menuNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 10),
                      child: Text(item.menuNote, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          ],
          if (item.doctors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('ডাক্তারদের তালিকা (${bn(item.doctors.length)} জন)',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            ),
            for (final d in item.doctors)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DoctorCard(
                  doctor: d.doctor,
                  chamber: d.chamber,
                  fallbackPhones: item.phones,
                  sample: item.sample,
                ),
              ),
          ],
          const SizedBox(height: 12),
          SourcesPanel(
            sources: item.sources,
            checked: item.sample ? '' : (item.checked.isNotEmpty ? item.checked : catalogChecked),
          ),
          Align(alignment: Alignment.centerLeft, child: ReportButton(about: '${c.label}: ${item.name}')),
        ],
      ),
      bottomNavigationBar: canBook
          ? BottomAction(
              label: cfg.button.isEmpty ? 'বুক করুন' : cfg.button,
              icon: Icons.event_available_outlined,
              onPressed: () => _openBooking(context, cfg, _target()),
            )
          : null,
    );
  }

  List<String> _placeScenes() {
    final s = item.scenes;
    if (s.isEmpty) return const ['park', 'water', 'river'];
    // Three pictures: repeat the main scene when there are fewer.
    return [for (var i = 0; i < 3; i++) s[i < s.length ? i : 0]];
  }

  Widget _titleBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: const TextStyle(fontSize: 19, height: 1.3, fontWeight: FontWeight.w700)),
          if (item.sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(item.sub, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted)),
          ],
          if (item.nameEn.isNotEmpty && item.nameEn != item.sub) ...[
            const SizedBox(height: 2),
            Text(item.nameEn, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
          if (item.rent.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: item.rent,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Group.of(category.color).deep)),
              TextSpan(text: ' ${item.per}', style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
            ])),
          ],
        ],
      );

  void _map(BuildContext context) => Launch.map(
        context,
        query: item.mapQuery.isNotEmpty ? item.mapQuery : '${item.name}, ${item.address}, Joypurhat',
        lat: item.lat,
        lng: item.lng,
      );
}

enum _GalleryKind { place, rent }

/// Swipeable pictures with a counter and dots: the place's real photos with
/// their credits, or drawn pictures marked "ছবি যোগ হবে" until photos are added.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.scenes, required this.captions, required this.name, this.photos = const []});
  final List<String> scenes;
  final List<String> captions;
  final String name;
  final List<Photo> photos;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  int _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    final to = i.clamp(0, _count - 1);
    if (reduceMotion(context)) {
      _pages.jumpToPage(to);
    } else {
      _pages.animateToPage(to, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
    }
  }

  int get _count => widget.photos.isNotEmpty ? widget.photos.length : widget.scenes.length;

  Widget _caption(String text) => Positioned(
        left: 12,
        right: 12,
        bottom: 26,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x61000000), borderRadius: BorderRadius.circular(8)),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _page(BuildContext context, int i) {
    if (widget.photos.isNotEmpty) {
      final p = widget.photos[i];
      return Stack(
        fit: StackFit.expand,
        children: [
          PhotoArt(photo: p, fallback: widget.scenes.isEmpty ? 'park' : widget.scenes.first),
          if (p.credit.isNotEmpty) _caption('ছবি: ${p.credit}'),
        ],
      );
    }
    return Stack(
      children: [
        SceneArt(kind: widget.scenes[i], sunX: const [264.0, 64.0, 176.0][i % 3]),
        _caption('${widget.captions[i % widget.captions.length]} · ছবি যোগ হবে'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _count;
    final real = widget.photos.isNotEmpty;
    return Semantics(
      label: real
          ? '${widget.name}, ছবি ${bn(_at + 1)} / ${bn(n)}'
          : '${widget.name}, আঁকা ছবি ${bn(_at + 1)} / ${bn(n)}। আসল ছবি যোগ হবে।',
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: n,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: _page,
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(999)),
                child: Text('${bn(_at + 1)}/${bn(n)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            if (_at > 0)
              Positioned(
                left: 8,
                top: 85,
                child: _RoundButton(icon: Icons.chevron_left, tooltip: 'আগের ছবি', onTap: () => _go(_at - 1)),
              ),
            if (_at < n - 1)
              Positioned(
                right: 8,
                top: 85,
                child: _RoundButton(icon: Icons.chevron_right, tooltip: 'পরের ছবি', onTap: () => _go(_at + 1)),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < n; i++)
                    AnimatedContainer(
                      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _at ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _at ? Colors.white : const Color(0x8CFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6FFFFFF),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: AppColors.text)),
    );
  }
}

/// How many flats, rooms or seats are free, with a bar.
class _VacancyPanel extends StatelessWidget {
  const _VacancyPanel({required this.item, required this.group});
  final Item item;
  final Group group;

  @override
  Widget build(BuildContext context) {
    final v = item.vacancy!;
    final (text, bg, fg) = vacancyLabel(item);
    Widget stat(String n, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(n, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${v.unit} খালি আছে কি?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Pill(text, bg: bg, fg: fg),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(bn(v.total), 'মোট ${v.unit}', AppColors.text),
              const SizedBox(width: 8),
              stat(bn(v.vacant), 'খালি', const Color(0xFF15803D)),
              const SizedBox(width: 8),
              stat(bn(v.total - v.vacant), 'ভাড়া হয়েছে', AppColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: v.total == 0 ? 0 : v.vacant / v.total,
              minHeight: 8,
              backgroundColor: group.soft,
              color: const Color(0xFF16A34A),
            ),
          ),
          if (item.updated.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('খালির হিসাব হালনাগাদ: ${item.updated}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({required this.title, required this.text, this.icon});
  final String title;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title, trailing: icon == null ? null : Icon(icon, color: AppColors.accent)),
          Text(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}

/// Restaurants without a menu yet: order by phone.
class _NoMenu extends StatelessWidget {
  const _NoMenu();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Group.orange.soft, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.restaurant_menu_outlined, color: Group.orange.dark, size: 28),
          ),
          const SizedBox(height: 8),
          const Text('মেনু এখনো যোগ হয়নি', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'এই রেস্টুরেন্ট অ্যাপে যুক্ত হলে মেনু দেখে অর্ডার করা যাবে। এখন কল করে অর্ডার দিন।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }
}

class _Act {
  const _Act(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions});
  final List<_Act> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, a) in actions.indexed)
          i == 0
              ? FilledButton.icon(onPressed: a.onTap, icon: Icon(a.icon, size: 20), label: Text(a.label))
              : OutlinedButton.icon(onPressed: a.onTap, icon: Icon(a.icon, size: 20), label: Text(a.label)),
      ],
    );
  }
}

/// A flat, room or seat with whether it is free.
class _UnitLine extends StatelessWidget {
  const _UnitLine({required this.unit, required this.divider, this.bookLabel, required this.onBook});
  final RentUnit unit;
  final bool divider;
  final String? bookLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (unit.sub.isNotEmpty) Text(unit.sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (unit.rent.isNotEmpty)
                  Text(unit.rent,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (bookLabel != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
              onPressed: onBook,
              child: Text(bookLabel!),
            )
          else
            unit.free
                ? const Pill('খালি', bg: AppColors.successBg, fg: AppColors.successText)
                : const Pill('ভাড়া হয়েছে', bg: Color(0xFFF1F5F9), fg: Color(0xFF475569)),
        ],
      ),
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.row, required this.divider, this.bookLabel, required this.onBook});
  final MenuRow row;
  final bool divider;
  final String? bookLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (row.sub.isNotEmpty) Text(row.sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (row.phone.isNotEmpty)
                  Text(phoneBn(row.phone), style: const TextStyle(fontSize: 14, color: AppColors.primary)),
                if (row.price.isNotEmpty)
                  Text(row.price, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
          if (row.phone.isNotEmpty) ...[
            const SizedBox(width: 8),
            CallButton(name: row.name, numbers: [row.phone], size: 38),
          ],
          if (row.url.isNotEmpty)
            IconButton(
              tooltip: 'ওয়েবসাইট খুলুন',
              onPressed: () => Launch.web(context, row.url),
              icon: const Icon(Icons.open_in_new, color: AppColors.primary),
            ),
          if (bookLabel != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
              onPressed: onBook,
              child: Text(bookLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
