import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart' show rootBundle;

import '../models/catalog.dart';
import '../models/transport.dart';

/// Everything in assets/data/joypurhat.json, parsed.
class Catalog {
  Catalog({
    required this.checked,
    required this.fields,
    required this.docBook,
    required this.order,
    required this.categories,
    required this.doctors,
    required this.transport,
    required this.notices,
    this.sections = const [],
    this.ticker = const [],
  });

  /// The date the data was last checked against its sources.
  final String checked;
  final Map<String, FieldDef> fields;
  final FormConfig docBook;
  final List<String> order;
  final Map<String, Category> categories;
  final List<Doctor> doctors;
  final TransportData transport;
  final List<Notice> notices;

  /// Home screen groups, in order; every category is in one.
  final List<HomeSection> sections;

  /// Lines of the scrolling announcement.
  final List<TickerLine> ticker;

  factory Catalog.fromJson(Map<String, dynamic> j) {
    final fields = <String, FieldDef>{
      for (final e in (j['fields'] as Map<String, dynamic>).entries)
        e.key: FieldDef.fromJson(e.key, e.value as Map<String, dynamic>),
    };
    final rawDoctors = j['doctors'] as List;
    final doctors = [
      for (var i = 0; i < rawDoctors.length; i++) Doctor.fromJson(i, rawDoctors[i] as Map<String, dynamic>),
    ];
    final cats = <String, Category>{
      for (final e in (j['categories'] as Map<String, dynamic>).entries)
        e.key: Category.fromJson(e.key, e.value as Map<String, dynamic>, fields),
    };
    for (final c in cats.values) {
      for (final item in c.items) {
        item.doctors = _doctorsAt(item, doctors);
      }
    }
    return Catalog(
      checked: (j['meta'] as Map)['checked'].toString(),
      fields: fields,
      docBook: FormConfig.fromJson(j['docBook'], fields)!,
      order: (j['order'] as List).map((e) => e.toString()).where(cats.containsKey).toList(),
      categories: cats,
      doctors: doctors,
      transport: TransportData.fromJson(j['transport'] as Map<String, dynamic>),
      notices: (j['notices'] as List).map((n) => Notice.fromJson(n as Map<String, dynamic>)).toList(),
      sections: (j['homeSections'] as List? ?? const [])
          .map((s) => HomeSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      ticker: [
        for (final t in (j['ticker'] as List? ?? const []))
          TickerLine((t['text'] ?? '').toString(), (t['color'] ?? '').toString()),
      ],
    );
  }

  static List<DoctorAtPlace> _doctorsAt(Item item, List<Doctor> doctors) {
    final out = <DoctorAtPlace>[];
    for (final (d, c) in item.doctorRefs) {
      if (d < 0 || d >= doctors.length) continue;
      final doc = doctors[d];
      if (doc.chambers.isEmpty) continue;
      out.add(DoctorAtPlace(doc, doc.chambers[c < doc.chambers.length ? c : 0]));
    }
    // Doctors written inside an item (the centre from Monem's own app).
    for (final j in item.inlineDoctors) {
      final days = (j['days'] as List? ?? const []).map((e) => (e as num).toInt()).toList();
      final chamber = Chamber(
        name: item.name,
        address: item.address,
        time: (j['schedule'] ?? '').toString(),
        fee: j['fee'] == null ? '' : '${j['fee']} টাকা',
        phones: item.phones,
        weekdays: days,
      );
      final doc = Doctor(
        index: -1,
        name: (j['name'] ?? '').toString(),
        degrees: (j['degrees'] ?? '').toString(),
        specialty: (j['specialty'] ?? '').toString(),
        group: '',
        chambers: [chamber],
        sources: item.sources,
      );
      out.add(DoctorAtPlace(doc, chamber));
    }
    return out;
  }
}

Catalog _parse(String raw) => Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

class CatalogRepository {
  static const assetPath = 'assets/data/joypurhat.json';

  static Future<Catalog> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return compute(_parse, raw);
  }

  /// For tests, which read the file without the asset bundle.
  static Catalog parse(String raw) => _parse(raw);
}
