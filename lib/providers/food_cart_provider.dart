import 'package:flutter/foundation.dart';

import '../models/catalog.dart';

/// The food cart. It holds dishes from one restaurant at a time, like the
/// big delivery apps, so one order goes to one kitchen.
class FoodCartProvider extends ChangeNotifier {
  Item? _restaurant;
  final Map<String, (Dish, int)> _lines = {};

  Item? get restaurant => _restaurant;

  bool isFrom(Item item) => identical(_restaurant, item);

  int qtyOf(Dish d) => _lines[d.name]?.$2 ?? 0;

  int get count => _lines.values.fold(0, (a, l) => a + l.$2);

  int get subtotal => _lines.values.fold(0, (a, l) => a + l.$1.price * l.$2);

  /// Name, quantity and line total, in the order they were added.
  List<(String, int, int)> get lines => [for (final (d, q) in _lines.values) (d.name, q, d.price * q)];

  /// False when the cart already has food from another restaurant; ask the
  /// user, then call [clear] and add again.
  bool canAdd(Item restaurant) => _restaurant == null || identical(_restaurant, restaurant);

  void setQty(Item restaurant, Dish dish, int qty) {
    if (!canAdd(restaurant)) return;
    if (qty <= 0) {
      _lines.remove(dish.name);
    } else {
      _lines[dish.name] = (dish, qty);
    }
    _restaurant = _lines.isEmpty ? null : restaurant;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _restaurant = null;
    notifyListeners();
  }
}
