import 'package:flutter/foundation.dart';

import '../models/catalog.dart';

/// The online shop cart (product index to quantity).
class CartProvider extends ChangeNotifier {
  final Map<int, int> _qty = {};

  int qtyOf(int index) => _qty[index] ?? 0;

  int get count => _qty.values.fold(0, (a, b) => a + b);

  int total(List<Product> products) {
    var sum = 0;
    _qty.forEach((i, q) {
      if (i < products.length) sum += products[i].price * q;
    });
    return sum;
  }

  List<(Product, int)> lines(List<Product> products) => [
        for (final e in _qty.entries)
          if (e.value > 0 && e.key < products.length) (products[e.key], e.value),
      ];

  void set(int index, int qty) {
    if (qty <= 0) {
      _qty.remove(index);
    } else {
      _qty[index] = qty;
    }
    notifyListeners();
  }

  void clear() {
    _qty.clear();
    notifyListeners();
  }
}
