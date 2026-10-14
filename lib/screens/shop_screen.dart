import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../providers/booking_provider.dart';
import '../providers/cart_provider.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import 'booking/booking_form_screen.dart';
import 'category_router.dart';

/// The local online shop. Sample products show only in demo mode, so the
/// release build shows an invitation to sellers until real ones join.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.category});
  final Category category;

  Future<void> _checkout(BuildContext context, List<Product> all) async {
    final cart = context.read<CartProvider>();
    final bookings = context.read<BookingProvider>();
    final cfg = category.order;
    if (cfg == null) return;
    final lines = [for (final (p, q) in cart.lines(all)) (p.name, q, p.price * q)];
    final before = bookings.items.length;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingFormScreen(
        config: cfg,
        target: BookingTarget(
          title: 'অনলাইন শপ অর্ডার',
          sub: '${bn(cart.count)}টি পণ্য',
          price: 'মোট: ৳${money(cart.total(all))}',
          icon: category.icon,
          kind: 'order',
          lines: lines,
          demoOnly: all.any((p) => p.sample),
        ),
      ),
    ));
    if (bookings.items.length > before) cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = category;
    final cart = context.watch<CartProvider>();
    final visible = [
      for (final (i, p) in c.products.indexed)
        if (AppConfig.demoMode || !p.sample) (i, p),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: visible.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyState(
                  icon: iconFor(c.icon),
                  title: 'শীঘ্রই আসছে',
                  text: c.emptyText.isEmpty ? emptyTextFor(c) : c.emptyText,
                  actionLabel: 'Shop দিতে চাই',
                  onAction: () => openCategoryKey(context, 'shopreg'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (c.intro.isNotEmpty) NoteBanner(c.intro, icon: Icons.storefront_outlined),
                if (AppConfig.demoMode) ...[
                  const SizedBox(height: 10),
                  const DemoBanner('এগুলো নমুনা পণ্য। আসল বিক্রেতা যুক্ত হলে তাদের পণ্য দেখাবে।'),
                ],
                const SizedBox(height: 12),
                for (final (i, p) in visible) ...[
                  _ProductRow(product: p, qty: cart.qtyOf(i), onChanged: (q) => cart.set(i, q)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
      bottomNavigationBar: cart.count == 0
          ? null
          : BottomAction(
              label: 'অর্ডার করুন',
              icon: Icons.shopping_cart_checkout,
              onPressed: () => _checkout(context, c.products),
              leading: Text(
                '${bn(cart.count)}টি পণ্য\nমোট ৳${money(cart.total(c.products))}',
                style: const TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.qty, required this.onChanged});
  final Product product;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBox(iconFor(p.icon, Icons.shopping_basket_outlined), size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                Text('${p.unit} · ${p.seller}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('৳${money(p.price)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  if (p.sample) const SampleBadge(),
                ]),
              ],
            ),
          ),
          if (qty == 0)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(72, 42)),
              onPressed: () => onChanged(1),
              child: const Text('যোগ'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: 'কমান',
                  onPressed: () => onChanged(qty - 1),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 28,
                  child: Text(bn(qty), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton.filled(
                  tooltip: 'বাড়ান',
                  onPressed: qty >= 20 ? null : () => onChanged(qty + 1),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
