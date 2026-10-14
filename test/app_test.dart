import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joypurhat/app.dart';
import 'package:joypurhat/data/catalog_repository.dart';
import 'package:joypurhat/providers/booking_provider.dart';
import 'package:joypurhat/providers/cart_provider.dart';
import 'package:joypurhat/providers/catalog_provider.dart';
import 'package:joypurhat/providers/food_cart_provider.dart';
import 'package:joypurhat/providers/profile_provider.dart';
import 'package:joypurhat/providers/transport_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final raw = File('assets/data/joypurhat.json').readAsStringSync();

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The home ticker loops forever; with reduced motion it stands still,
    // so pumpAndSettle can finish.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CatalogProvider(loader: () async => CatalogRepository.parse(raw))..load(),
          ),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => BookingProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => FoodCartProvider()),
          ChangeNotifierProvider(create: (_) => TransportProvider()),
        ],
        child: const JoypurhatApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the emergency strip and the service sections', (tester) async {
    await pumpApp(tester);
    expect(find.text('বিপদে এক চাপে কল করুন', skipOffstage: false), findsOneWidget);
    expect(find.text('১৬১৬৩', skipOffstage: false), findsOneWidget);
    // Section chips, then the sections themselves.
    expect(find.text('স্বাস্থ্য', skipOffstage: false), findsWidgets);
    expect(find.text('হাসপাতাল', skipOffstage: false), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'হাসপা');
    await tester.pump();
    await tester.ensureVisible(find.text('হাসপাতাল', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হাসপাতাল'));
    await tester.pumpAndSettle();
    expect(find.text('ডাক্তার খুঁজুন'), findsOneWidget);
  });

  testWidgets('a section chip scrolls to its section', (tester) async {
    await pumpApp(tester);
    final tile = find.text('আন্তনগর বাস', skipOffstage: false);
    final before = tester.getTopLeft(tile).dy;
    final chip = find.text('যাতায়াত', skipOffstage: false).first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tile).dy, lessThan(before));
    expect(tester.getTopLeft(tile).dy, greaterThanOrEqualTo(0));
  });

  testWidgets('search shows one flat list of services and doctors', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'ট্রেন');
    await tester.pump();
    expect(find.text('আন্তনগর ট্রেন'), findsOneWidget);
    expect(find.text('হাসপাতাল'), findsNothing);
    expect(find.text('বিপদে এক চাপে কল করুন'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'শিশু');
    await tester.pump();
    expect(find.text('ডাক্তার'), findsOneWidget);
    expect(find.text('সিরিয়াল দিন'), findsWidgets);
  });

  testWidgets('train screen shows the timetable', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'ট্রেন');
    await tester.pump();
    await tester.tap(find.text('আন্তনগর ট্রেন'));
    await tester.pumpAndSettle();
    expect(find.text('অনলাইনে টিকিট'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('জয়পুরহাট স্টেশন, এখন'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('জয়পুরহাট স্টেশন, এখন'), findsOneWidget);
  });

  testWidgets('bottom tabs open', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('আমার বুকিং').last);
    await tester.pumpAndSettle();
    expect(find.text('এখনো কোনো বুকিং নেই'), findsOneWidget);
    await tester.tap(find.text('নোটিশ').last);
    await tester.pumpAndSettle();
    expect(find.text('নতুন তথ্য যোগ হলো'), findsOneWidget);
    await tester.tap(find.text('প্রোফাইল').last);
    await tester.pumpAndSettle();
    expect(find.text('আপনার তথ্য'), findsOneWidget);
  });
}
