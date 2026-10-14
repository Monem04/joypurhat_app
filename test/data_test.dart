import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:joypurhat/data/catalog_repository.dart';
import 'package:joypurhat/models/catalog.dart';
import 'package:joypurhat/models/transport.dart';
import 'package:joypurhat/services/train_live.dart';
import 'package:joypurhat/services/train_schedule.dart';
import 'package:joypurhat/utils/bn.dart';

void main() {
  final catalog = CatalogRepository.parse(File('assets/data/joypurhat.json').readAsStringSync());

  test('every home tile has a category', () {
    expect(catalog.order.length, greaterThan(30));
    for (final key in catalog.order) {
      expect(catalog.categories[key], isNotNull, reason: key);
    }
  });

  test('form fields resolve', () {
    expect(catalog.docBook.fields.map((f) => f.key), containsAll(['pname', 'phone']));
    expect(catalog.categories['shopreg']!.form, isNotNull);
  });

  test('medical centres list their doctors', () {
    final withDoctors = [
      for (final k in ['hospital', 'diagnostic', 'dental'])
        ...catalog.categories[k]!.items.where((i) => i.doctors.isNotEmpty),
    ];
    expect(withDoctors, isNotEmpty);
    expect(catalog.doctors.length, greaterThan(100));
  });

  test('call lists have numbers', () {
    for (final key in ['emergency', 'fire', 'ambulance']) {
      final c = catalog.categories[key]!;
      final entries = [for (final s in c.sections) ...s.items];
      expect(entries, isNotEmpty, reason: key);
      expect(entries.every((e) => e.numbers.isNotEmpty), isTrue, reason: key);
    }
  });

  test('train timetable gives the next departures', () {
    final now = DateTime(2026, 10, 11, 16, 0);
    final deps = upcomingDepartures(catalog.transport.trains, now);
    expect(deps, isNotEmpty);
    expect(deps.first.minutesAway, greaterThanOrEqualTo(-5));
    for (var i = 1; i < deps.length; i++) {
      expect(deps[i].at.isBefore(deps[i - 1].at), isFalse);
    }
    final dhaka = upcomingDepartures(catalog.transport.trains, now, filter: 'ঢাকা');
    expect(dhaka.every((d) => d.run.to == 'ঢাকা'), isTrue);
  });

  test('Bangla helpers', () {
    expect(bn(2026), '২০২৬');
    expect(money(12500), '১২,৫০০');
    expect(isBdMobile('01712345678'), isTrue);
    expect(isBdMobile('০১৭১২৩৪৫৬৭৮'), isTrue);
    expect(isBdMobile('0571-62111'), isFalse);
    expect(dialable('+880 1712-345678'), '+8801712345678');
    expect(hmBn('16:53'), 'বিকাল ৪:৫৩');
    expect(durationBn(135), '২ ঘণ্টা ১৫ মিনিট');
  });

  test('home has ten coloured sections that hold every category once', () {
    expect(catalog.sections.map((s) => s.title), [
      'জরুরি সেবা',
      'স্বাস্থ্য',
      'যাতায়াত',
      'খাবার ও থাকা',
      'বাসা ও মেস',
      'ঘোরাঘুরি',
      'শিক্ষা',
      'কেনাকাটা ও সার্ভিস',
      'অনুষ্ঠান ও সাজ',
      'সরকারি ও তথ্য',
    ]);
    final keys = [for (final s in catalog.sections) ...s.keys];
    expect(keys.toSet().length, keys.length);
    expect(keys.toSet(), catalog.order.toSet());
    for (final c in catalog.categories.values) {
      expect(c.color, isNotEmpty, reason: c.title);
    }
  });

  test('every real item names its sources and a confidence level', () {
    for (final c in catalog.categories.values) {
      for (final i in c.items.where((i) => !i.sample)) {
        expect(i.sources, isNotEmpty, reason: '${c.title}: ${i.name}');
        expect(['high', 'medium', 'low'], contains(i.confidence), reason: '${c.title}: ${i.name}');
      }
    }
  });

  test('invented details appear only on sample items', () {
    for (final c in catalog.categories.values) {
      for (final i in c.items.where((i) => !i.sample)) {
        final why = '${c.title}: ${i.name}';
        expect(i.foodMenu, isEmpty, reason: why);
        expect(i.bookedSlots, isEmpty, reason: why);
        expect(i.vacancy, isNull, reason: why);
        expect(i.units, isEmpty, reason: why);
      }
    }
    final menus = catalog.categories['restaurant']!.items.where((i) => i.hasMenu);
    expect(menus, isNotEmpty);
    expect(menus.every((i) => i.sample), isTrue);
  });

  test('round 2 medical data is merged', () {
    List<Item> real(String k) => catalog.categories[k]!.items.where((i) => !i.sample).toList();
    expect(real('diagnostic').length, greaterThan(40));
    expect(real('hospital').length, greaterThanOrEqualTo(25));
    expect(real('dental').any((i) => i.name.contains('গ্রাজুয়েট')), isTrue);
    // Names and addresses are shown in Bangla.
    for (final i in real('diagnostic')) {
      expect(RegExp('[A-Za-z]').hasMatch(i.address), isFalse, reason: i.name);
    }
  });

  test('bus tickets link to the two confirmed sites', () {
    final sites = catalog.transport.busOnline;
    expect(sites.map((s) => s.url), [
      'https://www.shohoz.com/bus-tickets',
      'https://shyamolitickets.com/search/DHAKA/JOYPURHAT',
    ]);
    expect(sites.first.sub.contains('এসি'), isFalse);
    expect(sites.last.sub.contains('এসি'), isTrue);
  });

  test('house and mess link to the rent sites instead of copying their ads', () {
    expect(catalog.categories['house']!.links.map((l) => l.label), ['thetolet.com', 'toletbd.app']);
    expect(catalog.categories['mess']!.links, isNotEmpty);
    for (final l in [...catalog.categories['house']!.links, ...catalog.categories['mess']!.links]) {
      expect(l.url.startsWith('https://'), isTrue);
    }
  });

  test('services that had only samples now have real listings with sources', () {
    for (final key in ['serviceman', 'it', 'coaching', 'library', 'probashi', 'wifi', 'community']) {
      final real = catalog.categories[key]!.items.where((i) => !i.sample).toList();
      expect(real, isNotEmpty, reason: key);
      for (final i in real.where((i) => i.checked == '2026-10-13')) {
        expect(i.sources, isNotEmpty, reason: i.name);
        expect(['high', 'medium', 'low'], contains(i.confidence), reason: i.name);
      }
    }
    // Motorbike showrooms are the only real service people found so far.
    final service = catalog.categories['serviceman']!;
    expect(service.items.where((i) => !i.sample).every((i) => i.tag == 'মোটরসাইকেল'), isTrue);
    expect(service.filters, contains('মোটরসাইকেল'));
  });

  group('estimated train position', () {
    final line = catalog.transport.line;
    const south = TrainRun(number: '1', to: 'ঢাকা', origin: 'পঞ্চগড়', dep: '12:00');
    const north = TrainRun(number: '2', to: 'পঞ্চগড়', origin: 'ঢাকা', dep: '12:00');
    DateTime at(int h, int m) => DateTime(2026, 10, 12, h, m);

    test('the line runs north to south through Joypurhat', () {
      expect(line.first.min, greaterThan(0));
      expect(line.last.min, lessThan(0));
      expect(line.where((s) => s.min == 0).single.name, 'জয়পুরহাট');
      for (var i = 1; i < line.length; i++) {
        expect(line[i].min, lessThan(line[i - 1].min));
      }
    });

    test('at the Joypurhat time the train is at Joypurhat', () {
      for (final run in [south, north]) {
        final e = estimatePosition(line, run, at(12, 0))!;
        expect(e.headline, 'ট্রেন এখন জয়পুরহাট স্টেশনে');
        expect(e.onLine, isTrue);
      }
    });

    test('before Joypurhat a southbound train is to the north', () {
      final e = estimatePosition(line, south, at(11, 50))!;
      expect(e.headline, contains('পাঁচবিবি'));
      expect(e.detail, startsWith('জয়পুরহাট পৌঁছাবে'));
      final joy = line.indexWhere((s) => s.min == 0);
      expect(e.passed[joy], isFalse);
      expect(e.passed.first, isTrue);
    });

    test('after Joypurhat a northbound train is to the north', () {
      final e = estimatePosition(line, north, at(12, 20))!;
      expect(e.detail, startsWith('জয়পুরহাট ছেড়েছে'));
      expect(e.passed[line.indexWhere((s) => s.min == 0)], isTrue);
      expect(e.y, lessThan(line.firstWhere((s) => s.min == 0).y));
    });

    test('far from the line it says which end', () {
      expect(estimatePosition(line, south, at(9, 0))!.onLine, isFalse);
      expect(estimatePosition(line, south, at(15, 0))!.headline, contains('পার হয়েছে'));
    });
  });
}
