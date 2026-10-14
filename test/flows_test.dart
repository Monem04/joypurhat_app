import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joypurhat/config.dart';
import 'package:joypurhat/data/catalog_repository.dart';
import 'package:joypurhat/providers/booking_provider.dart';
import 'package:joypurhat/providers/cart_provider.dart';
import 'package:joypurhat/providers/catalog_provider.dart';
import 'package:joypurhat/providers/food_cart_provider.dart';
import 'package:joypurhat/providers/profile_provider.dart';
import 'package:joypurhat/providers/transport_provider.dart';
import 'package:joypurhat/screens/booking/booking_form_screen.dart';
import 'package:joypurhat/screens/booking/order_track_screen.dart';
import 'package:joypurhat/screens/item_detail_screen.dart';
import 'package:joypurhat/screens/restaurant_screen.dart';
import 'package:joypurhat/screens/transport/trip_screen.dart';
import 'package:joypurhat/theme.dart';
import 'package:joypurhat/utils/bn.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final catalog = CatalogRepository.parse(File('assets/data/joypurhat.json').readAsStringSync());
  late BookingProvider bookings;
  final launched = <String>[];

  setUp(() {
    launched.clear();
    // The order tracker's glowing dot repeats forever unless motion is off.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    // Stands in for the phone's SMS app, dialer and browser.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launched.add((call.arguments as Map)['url'].toString());
        return true;
      },
    );
  });

  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.clearAccessibilityFeaturesTestValue());

  // Scrolls [f] to the middle of the screen, clear of bars at the edges.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final provider = CatalogProvider(loader: () async => catalog);
    await provider.load();
    bookings = BookingProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider.value(value: bookings),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => FoodCartProvider()),
          ChangeNotifierProvider(create: (_) => TransportProvider(trips: catalog.transport.demoTrips)),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          locale: const Locale('bn', 'BD'),
          supportedLocales: const [Locale('bn', 'BD'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('serial request checks the phone number and is saved', (tester) async {
    final d = catalog.doctors.first;
    await show(
      tester,
      BookingFormScreen(
        config: catalog.docBook,
        target: BookingTarget(title: d.name, place: d.chambers.first.name, phones: d.chambers.first.phones, kind: 'serial'),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'রহিম উদ্দিন');
    await tester.enterText(fields.at(1), '12345');
    await tester.tap(find.text('সিরিয়াল নিশ্চিত করুন'));
    await tester.pumpAndSettle();
    expect(find.textContaining('সঠিক মোবাইল নম্বর দিন'), findsOneWidget);
    expect(bookings.items, isEmpty);

    await tester.enterText(fields.at(1), '01712345678');
    await tester.tap(find.text('সিরিয়াল নিশ্চিত করুন'));
    await tester.pumpAndSettle();
    expect(bookings.items.length, 1);
    expect(bookings.items.first.kind, 'serial');
    if (!AppConfig.demoMode) {
      // The request goes to the chamber's mobile by SMS.
      expect(launched.single, startsWith('sms:${d.chambers.first.phones.first.replaceAll('-', '')}?body='));
      expect(Uri.decodeComponent(launched.single), contains('রহিম উদ্দিন'));
    }
    expect(find.text('আমার বুকিং'), findsOneWidget);
  });

  testWidgets('demo bus ticket: pick a seat, pay, get a ticket', (tester) async {
    final trip = catalog.transport.demoTrips.firstWhere((t) => t.fare > 0);
    await show(tester, TripScreen(trip: trip));
    final tp = Provider.of<TransportProvider>(tester.element(find.byType(TripScreen)), listen: false);
    final free = TransportProvider.seatIds(trip.rows).firstWhere((s) => !tp.sold(trip, 1).contains(s));
    await tester.tap(find.textContaining('আগামীকাল').first);
    await tester.pump();
    await tester.ensureVisible(find.text(free));
    await tester.pumpAndSettle();
    await tester.tap(find.text(free));
    await tester.pump();
    await tester.tap(find.text('এগিয়ে যান'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'রহিম');
    await tester.enterText(fields.at(1), '01812345678');
    await tester.tap(find.text('পেমেন্ট করুন (ডেমো)'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('টিকিট নম্বর'), findsOneWidget);
    expect(bookings.items.single.isTicket, isTrue);
    expect(tp.sold(trip, 1).contains(free), isTrue);
  }, skip: !AppConfig.demoMode);

  test('the food cart holds dishes from one restaurant at a time', () {
    final menus = catalog.categories['restaurant']!.items.where((i) => i.hasMenu).toList();
    expect(menus.length, greaterThanOrEqualTo(2));
    final cart = FoodCartProvider();
    final a = menus[0], b = menus[1];
    final dish = a.foodMenu.first.dishes.first;
    cart.setQty(a, dish, 3);
    expect(cart.count, 3);
    expect(cart.subtotal, dish.price * 3);
    expect(cart.canAdd(b), isFalse);
    cart.setQty(a, dish, 0);
    expect(cart.count, 0);
    expect(cart.canAdd(b), isTrue);
  });

  testWidgets('a listed restaurant has no invented menu and asks you to call', (tester) async {
    final c = catalog.categories['restaurant']!;
    final item = c.items.firstWhere((i) => !i.sample && i.phones.isNotEmpty);
    expect(item.hasMenu, isFalse);
    await show(tester, ItemDetailScreen(category: c, item: item));
    await tester.scrollUntilVisible(find.text('মেনু এখনো যোগ হয়নি'), 300);
    expect(find.text('মেনু এখনো যোগ হয়নি'), findsOneWidget);
  });

  testWidgets('demo food order: add dishes, check out and follow the order', (tester) async {
    final c = catalog.categories['restaurant']!;
    final item = c.items.firstWhere((i) => i.sample && i.hasMenu);
    final dish = item.foodMenu.first.dishes.first;
    await show(tester, RestaurantScreen(category: c, item: item));
    await reveal(tester, find.byTooltip('${dish.name} কার্টে যোগ করুন'));
    await tester.tap(find.byTooltip('${dish.name} কার্টে যোগ করুন'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('একটি বাড়ান').first);
    await tester.pumpAndSettle();
    final cart = Provider.of<FoodCartProvider>(tester.element(find.byType(RestaurantScreen)), listen: false);
    expect(cart.count, 2);

    await tester.tap(find.text('চেকআউট'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'রহিম উদ্দিন');
    await tester.enterText(fields.at(1), '01712345678');
    await tester.enterText(fields.at(2), 'স্টেশন রোড, জয়পুরহাট');
    final total = dish.price * 2 + item.deliveryFee;
    await tester.tap(find.text('অর্ডার করুন · ৳${money(total)}'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackScreen), findsOneWidget);
    final saved = bookings.items.single;
    expect(saved.track, isTrue);
    expect(saved.isDemo, isTrue);
    expect(saved.total, total);
    expect(cart.count, 0);
    expect(launched, isEmpty);
  }, skip: !AppConfig.demoMode);

  testWidgets('parlour booking: slots that are taken cannot be picked', (tester) async {
    final c = catalog.categories['parlour']!;
    final item = c.items.firstWhere((i) => i.sample && i.bookedSlots.isNotEmpty && i.bookedSlots.first.isNotEmpty);
    await show(
      tester,
      BookingFormScreen(
        config: c.book!,
        target: BookingTarget(title: item.name, phones: item.phones, services: item.menu, bookedSlots: item.bookedSlots),
      ),
    );
    ChoiceChip chip(String label) =>
        tester.widget<ChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)));
    final slots = c.book!.fields.firstWhere((f) => f.type == 'slots').options;
    final taken = item.bookedSlots.first.first;
    final free = slots.firstWhere((s) => !item.bookedSlots.first.contains(s));
    expect(chip(taken).onSelected, isNull);
    await reveal(tester, find.text(free));
    await tester.tap(find.text(free));
    await tester.pumpAndSettle();
    expect(chip(free).selected, isTrue);
  }, skip: !AppConfig.demoMode);
}
