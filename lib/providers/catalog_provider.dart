import 'package:flutter/foundation.dart' hide Category;

import '../config.dart';
import '../data/catalog_repository.dart';
import '../models/catalog.dart';

/// Loads the directory data once and answers questions about it.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({Future<Catalog> Function()? loader}) : _loader = loader ?? CatalogRepository.load;

  final Future<Catalog> Function() _loader;
  Catalog? _data;
  Object? _error;
  bool _loading = false;

  Catalog? get data => _data;
  Object? get error => _error;
  bool get isReady => _data != null;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _loader();
    } catch (e, st) {
      debugPrint('Catalog load failed: $e\n$st');
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  Catalog get catalog => _data!;

  List<Category> get homeCategories => [for (final k in catalog.order) catalog.categories[k]!];

  Category? category(String key) => _data?.categories[key];

  /// Items shown to the user: sample businesses only in demo mode.
  List<Item> itemsOf(Category c) => [
        for (final i in c.items)
          if (AppConfig.demoMode || !i.sample) i,
      ];

  /// Home sections with their categories, empty sections left out.
  List<(HomeSection, List<Category>)> get homeSections => [
        for (final s in catalog.sections)
          if (s.keys.any(catalog.categories.containsKey))
            (s, [for (final k in s.keys) ?catalog.categories[k]]),
      ];

  /// Doctors matching a home search, by name, degree, specialty or chamber.
  List<Doctor> searchDoctors(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return catalog.doctors.where((d) => d.searchText.contains(q)).toList();
  }

  List<Category> searchCategories(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return homeCategories;
    return homeCategories
        .where((c) => c.label.toLowerCase().contains(q) || c.keywords.toLowerCase().contains(q))
        .toList();
  }

  /// Doctor specialty groups, most doctors first.
  List<String> get doctorGroups {
    final counts = <String, int>{};
    for (final d in catalog.doctors) {
      counts[d.group] = (counts[d.group] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        if (a == 'অন্যান্য') return 1;
        if (b == 'অন্যান্য') return -1;
        return counts[b]!.compareTo(counts[a]!);
      });
    return keys;
  }

  /// The centres (hospital, diagnostic) where a doctor is listed.
  List<(Category, Item)> placesOf(Doctor d) {
    final out = <(Category, Item)>[];
    for (final key in const ['hospital', 'diagnostic', 'dental']) {
      final c = catalog.categories[key];
      if (c == null) continue;
      for (final item in itemsOf(c)) {
        if (item.doctors.any((x) => identical(x.doctor, d))) out.add((c, item));
      }
    }
    return out;
  }
}
