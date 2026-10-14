import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import 'article_screen.dart';
import 'booking/booking_form_screen.dart';
import 'call_list_screen.dart';
import 'item_detail_screen.dart';
import 'item_list_screen.dart';
import 'restaurant_screen.dart';
import 'shop_screen.dart';
import 'transport/transport_screen.dart';

/// Opens the right screen for a home tile.
void openCategory(BuildContext context, Category c) {
  final Widget screen;
  switch (c.template) {
    case 'call':
      screen = CallListScreen(category: c);
    case 'transport':
      screen = TransportScreen(category: c);
    case 'article':
      screen = ArticleScreen(category: c);
    case 'shop':
      screen = ShopScreen(category: c);
    case 'form':
      screen = BookingFormScreen(
        config: c.form!,
        target: BookingTarget.support(title: c.form!.title, sub: c.form!.sub, icon: c.icon),
      );
    default:
      screen = ItemListScreen(category: c);
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// Opens one entry: restaurants with a menu get the ordering screen.
void openItem(BuildContext context, Category c, Item item) {
  final screen = c.card == 'food' && item.hasMenu
      ? RestaurantScreen(category: c, item: item)
      : ItemDetailScreen(category: c, item: item);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

void openCategoryKey(BuildContext context, String key) {
  final c = context.read<CatalogProvider>().category(key);
  if (c != null) openCategory(context, c);
}

/// Text for a category with no verified entries yet.
String emptyTextFor(Category c) {
  if (c.emptyText.isNotEmpty) return c.emptyText;
  final sampleOnly = c.items.isNotEmpty && c.items.every((i) => i.sample);
  if (sampleOnly && !AppConfig.demoMode) {
    return 'এই সেবার যাচাই করা তথ্য এখনো যোগ হয়নি। আপনার ব্যবসা বা প্রতিষ্ঠান এখানে দেখাতে "Shop দিতে চাই" ফর্ম পূরণ করুন।';
  }
  return 'এই সেবার তথ্য শীঘ্রই যোগ হবে।';
}
