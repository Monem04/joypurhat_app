import 'package:flutter/material.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../screens/category_router.dart';
import '../theme.dart';
import '../utils/bn.dart';
import 'app_icons.dart';
import 'art.dart';
import 'common.dart';
import 'motion.dart';

/// The card for one entry in a list, in the style its category asks for:
/// food (restaurants), photo (places to visit), rent (houses and messes) or
/// the plain card with an icon.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  Widget build(BuildContext context) {
    switch (category.card) {
      case 'food':
        return _FoodCard(category: category, item: item);
      case 'photo':
        return _PhotoCard(category: category, item: item);
      case 'rent':
        return _RentCard(category: category, item: item);
      default:
        return _PlainCard(category: category, item: item);
    }
  }
}

/// White card with a soft shadow and a press effect.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0D10201F), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1210201F), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Pressable(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// A small label laid over a picture.
class _OverPill extends StatelessWidget {
  const _OverPill(this.text, {this.bg = const Color(0xF2FFFFFF), this.fg = AppColors.textSoft, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Sample and "check it" labels for the top right of a picture.
List<Widget> _flags(Item item) => [
      if (item.sample && AppConfig.demoMode) const _OverPill('নমুনা', bg: AppColors.warnBg, fg: AppColors.warnText),
      if (item.isLowConfidence) const _OverPill('যাচাই করে নিন', bg: AppColors.warnBg, fg: AppColors.warnText),
    ];

class _AddressLine extends StatelessWidget {
  const _AddressLine(this.text, this.color, {this.lines = 2});
  final String text;
  final Color color;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.place_outlined, size: 15, color: color)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSoft)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ food

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final sweet = item.tag == 'মিষ্টি ও দই';
    final String deliv;
    final IconData delivIcon;
    if (item.hasMenu) {
      deliv = 'ডেলিভারি ${item.deliveryTime}';
      delivIcon = Icons.delivery_dining_outlined;
    } else if (item.phones.isNotEmpty) {
      deliv = 'কল করে অর্ডার';
      delivIcon = Icons.call_outlined;
    } else {
      deliv = 'ম্যাপে দেখুন';
      delivIcon = Icons.map_outlined;
    }
    return _Shell(
      onTap: () => openItem(context, category, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 118,
            child: Stack(
              children: [
                FoodCoverArt(
                  cover: item.cover.isNotEmpty ? item.cover : (sweet ? sweetCover : restaurantCover),
                  palette: item.palette.isNotEmpty ? item.palette : (sweet ? sweetPalette : restaurantPalette),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  right: 110,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _OverPill(deliv, fg: const Color(0xFF9A3412), icon: delivIcon),
                  ),
                ),
                Positioned(right: 10, top: 10, child: Wrap(spacing: 5, children: _flags(item))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(item.name, style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w700)),
                    ),
                    if (item.price.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(item.price,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFC2410C))),
                      ),
                    ],
                  ],
                ),
                if (item.sub.isNotEmpty)
                  Text(item.sub, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted)),
                if (item.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _AddressLine(item.address, const Color(0xFFEA580C), lines: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ photo

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(category.color);
    return _Shell(
      onTap: () => openItem(context, category, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                if (item.photos.isEmpty)
                  SceneArt(kind: item.art)
                else
                  PhotoArt(photo: item.photos.first, fallback: item.art.isEmpty ? 'park' : item.art),
                if (item.tag.isNotEmpty)
                  Positioned(left: 10, top: 10, child: _OverPill(item.tag, fg: g.deep)),
                Positioned(right: 10, top: 10, child: Wrap(spacing: 5, children: _flags(item))),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: _OverPill(item.photos.isEmpty ? 'ছবি যোগ হবে' : '${bn(item.photos.length)}টি ছবি',
                      bg: const Color(0x52000000), fg: Colors.white, icon: Icons.image_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w700)),
                if (item.sub.isNotEmpty)
                  Text(item.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSoft)),
                if (item.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _AddressLine(item.address, g.deep),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ rent

/// Text and colours for how many rooms or seats are free.
(String, Color, Color) vacancyLabel(Item item) {
  final v = item.vacancy;
  if (v == null) return ('খালি কিনা কল করে জানুন', const Color(0xFFF1F5F9), const Color(0xFF475569));
  if (v.vacant > 0) return ('খালি: ${bn(v.vacant)}টি ${v.unit}', const Color(0xFFDCFCE7), const Color(0xFF15803D));
  return ('এখন খালি নেই', const Color(0xFFF1F5F9), const Color(0xFF475569));
}

class _RentCard extends StatelessWidget {
  const _RentCard({required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final g = Group.of(category.color);
    final (vacText, vacBg, vacFg) = vacancyLabel(item);
    return _Shell(
      onTap: () => openItem(context, category, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              children: [
                RentArt(vacant: item.vacancy?.vacant ?? 0),
                Positioned(
                  left: 10,
                  top: 10,
                  right: 120,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _OverPill(vacText, bg: vacBg, fg: vacFg, icon: Icons.circle),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Wrap(spacing: 5, children: [
                    ..._flags(item),
                    if (item.tag.isNotEmpty) _OverPill(item.tag, fg: g.deep),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.rent.isNotEmpty)
                  Text.rich(TextSpan(children: [
                    TextSpan(text: item.rent, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: g.deep)),
                    TextSpan(text: ' ${item.per}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ]))
                else
                  Text('ভাড়া জানতে কল করুন',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: g.deep)),
                const SizedBox(height: 2),
                Text(item.name, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w700)),
                if (item.address.isNotEmpty) _AddressLine(item.address, g.deep),
                if (item.facts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final f in item.facts)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: g.soft.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: g.soft),
                        ),
                        child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.deep)),
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ plain

class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final g = Group.of(c.color);
    return _Shell(
      onTap: () => openItem(context, c, item),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(iconFor(item.icon.isEmpty ? c.icon : item.icon), bg: g.soft, fg: g.deep),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 15.5, height: 1.3, fontWeight: FontWeight.w700)),
                  if (item.sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ),
                  if (item.address.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 6), child: _AddressLine(item.address, g.deep)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (item.sample && AppConfig.demoMode) const SampleBadge(),
                      if (item.tag.isNotEmpty && c.filters.isNotEmpty) Pill(item.tag, bg: g.soft, fg: g.deep),
                      if (item.doctors.isNotEmpty)
                        Pill('${bn(item.doctors.length)} জন ডাক্তার',
                            icon: Icons.medical_services_outlined, bg: AppColors.infoBg, fg: AppColors.infoText),
                      if (item.price.isNotEmpty) Pill(item.price, bg: AppColors.surfaceAlt, fg: AppColors.textSoft),
                      if (item.isLowConfidence) const CheckBadge(),
                    ],
                  ),
                ],
              ),
            ),
            if (item.phones.isNotEmpty) ...[
              const SizedBox(width: 8),
              CallButton(name: item.name, numbers: item.phones, size: 42),
            ],
          ],
        ),
      ),
    );
  }
}
