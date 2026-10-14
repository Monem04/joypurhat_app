import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../providers/food_cart_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/report.dart';
import 'booking/booking_form_screen.dart';

/// A restaurant with a menu: pick dishes, see the bill, order. Only sample
/// restaurants have menus for now, so this shows in demo mode.
class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key, required this.category, required this.item});
  final Category category;
  final Item item;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _keys = <String, GlobalKey>{};
  int _tab = 0;

  void _jump(int i, MenuSection s) {
    setState(() => _tab = i);
    final ctx = _keys[s.title]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _setQty(Dish d, int qty) async {
    final cart = context.read<FoodCartProvider>();
    if (!cart.canAdd(widget.item)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('নতুন কার্ট শুরু করবেন?'),
          content: Text('কার্টে ${cart.restaurant!.name} এর খাবার আছে। এক অর্ডারে একটি রেস্টুরেন্ট থেকেই নেওয়া যায়।'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('আগেরটা মুছুন')),
          ],
        ),
      );
      if (ok != true) return;
      cart.clear();
    }
    cart.setQty(widget.item, d, qty);
  }

  void _checkout() {
    final c = widget.category;
    final item = widget.item;
    final cart = context.read<FoodCartProvider>();
    final form = c.order;
    if (form == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingFormScreen(
        config: form,
        target: BookingTarget(
          title: item.name,
          sub: item.sub,
          place: item.address,
          phones: item.phones,
          icon: 'utensils',
          color: c.color,
          kind: 'order',
          lines: cart.lines,
          deliveryFee: item.deliveryFee,
          demoOnly: item.sample,
          onSent: cart.clear,
        ),
      ),
    ));
  }

  void _bookTable() {
    final c = widget.category;
    final item = widget.item;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingFormScreen(
        config: c.book!,
        target: BookingTarget(
          title: item.name,
          sub: item.sub,
          place: item.address,
          phones: item.phones,
          icon: 'utensils',
          color: c.color,
          demoOnly: item.sample,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final item = widget.item;
    final cart = context.watch<FoodCartProvider>();
    final mine = cart.isFrom(item) && cart.count > 0;
    final checked = context.read<CatalogProvider>().catalog.checked;
    final sections = item.foodMenu.where((s) => s.dishes.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: FoodCoverArt(
                cover: item.cover.isNotEmpty ? item.cover : restaurantCover,
                palette: item.palette.isNotEmpty ? item.palette : restaurantPalette,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (item.sample) const SampleBadge(),
                    if (item.tag.isNotEmpty) Pill(item.tag, bg: Group.orange.soft, fg: Group.orange.deep),
                    if (item.isLowConfidence) const CheckBadge(),
                  ]),
                  const SizedBox(height: 8),
                  Text(item.name, style: const TextStyle(fontSize: 21, height: 1.3, fontWeight: FontWeight.w800)),
                  if (item.sub.isNotEmpty)
                    Text(item.sub, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (item.deliveryTime.isNotEmpty)
                      Pill('ডেলিভারি ${item.deliveryTime}',
                          icon: Icons.delivery_dining_outlined, bg: AppColors.surface, fg: AppColors.textSoft),
                    if (item.deliveryFee > 0)
                      Pill('ডেলিভারি চার্জ ৳${money(item.deliveryFee)}',
                          icon: Icons.two_wheeler_outlined, bg: AppColors.surface, fg: AppColors.textSoft),
                    if (item.time.isNotEmpty)
                      Pill(item.time, icon: Icons.schedule_outlined, bg: AppColors.surface, fg: AppColors.textSoft),
                  ]),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.place_outlined, size: 18, color: Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.address, style: const TextStyle(fontSize: 14, height: 1.45))),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (item.phones.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => callNumbers(context, item.name, item.phones),
                        icon: const Icon(Icons.call_outlined, size: 19),
                        label: const Text('কল করুন'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Launch.map(
                        context,
                        query: item.mapQuery.isNotEmpty ? item.mapQuery : '${item.name}, ${item.address}',
                        lat: item.lat,
                        lng: item.lng,
                      ),
                      icon: const Icon(Icons.map_outlined, size: 19),
                      label: const Text('ম্যাপ'),
                    ),
                    if (c.book != null)
                      OutlinedButton.icon(
                        onPressed: _bookTable,
                        icon: const Icon(Icons.table_restaurant_outlined, size: 19),
                        label: Text(c.book!.button.isEmpty ? 'টেবিল বুক' : c.book!.button),
                      ),
                  ]),
                  if (item.sample && AppConfig.demoMode) ...[
                    const SizedBox(height: 12),
                    const DemoBanner('নমুনা রেস্টুরেন্ট ও মেনু, শুধু ডেমো দেখানোর জন্য। অর্ডার কোথাও যাবে না।'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (sections.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ChoiceChip(
                    label: Text(sections[i].title),
                    selected: _tab == i,
                    showCheckmark: false,
                    selectedColor: Group.orange.dark,
                    labelStyle: TextStyle(
                      color: _tab == i ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => _jump(i, sections[i]),
                  ),
                ),
              ),
            for (final s in sections)
              Padding(
                key: _keys.putIfAbsent(s.title, GlobalKey.new),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    for (final d in s.dishes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DishCard(
                          dish: d,
                          qty: cart.isFrom(item) ? cart.qtyOf(d) : 0,
                          onQty: (q) => _setQty(d, q),
                        ),
                      ),
                  ],
                ),
              ),
            if (item.menuNote.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: NoteBanner(item.menuNote)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SourcesPanel(sources: item.sources, checked: item.sample ? '' : checked),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportButton(about: '${c.label}: ${item.name}'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: mine ? _CartBar(count: cart.count, total: cart.subtotal, onTap: _checkout) : null,
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.qty, required this.onQty});
  final Dish dish;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFEA580C);
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w700)),
                if (dish.desc.isNotEmpty)
                  Text(dish.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text('৳${money(dish.price)}',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFFC2410C))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 104, height: 96, child: DishArt(kind: dish.art)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 180),
                    child: qty == 0
                        ? Material(
                            key: const ValueKey('add'),
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: '${dish.name} কার্টে যোগ করুন',
                              onPressed: () => onQty(1),
                              icon: const Icon(Icons.add, color: orange),
                            ),
                          )
                        : Container(
                            key: const ValueKey('qty'),
                            height: 40,
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [BoxShadow(color: Color(0x59EA580C), blurRadius: 12, offset: Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'একটি কমান',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onQty(qty - 1),
                                  icon: const Icon(Icons.remove, size: 18, color: Colors.white),
                                ),
                                Text(bn(qty),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                                IconButton(
                                  tooltip: 'একটি বাড়ান',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onQty(qty + 1),
                                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.total, required this.onTap});
  final int count;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Group.orange.shadow, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Pressable(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                      child: Text(bn(count),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('চেকআউট',
                          style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                    Text('৳${money(total)}',
                        style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
