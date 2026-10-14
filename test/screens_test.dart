import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joypurhat/config.dart';
import 'package:joypurhat/data/catalog_repository.dart';
import 'package:joypurhat/models/catalog.dart';
import 'package:joypurhat/providers/booking_provider.dart';
import 'package:joypurhat/providers/cart_provider.dart';
import 'package:joypurhat/providers/catalog_provider.dart';
import 'package:joypurhat/providers/food_cart_provider.dart';
import 'package:joypurhat/providers/profile_provider.dart';
import 'package:joypurhat/providers/transport_provider.dart';
import 'package:joypurhat/models/booking.dart';
import 'package:joypurhat/screens/about_screen.dart';
import 'package:joypurhat/screens/booking/booking_form_screen.dart';
import 'package:joypurhat/screens/booking/order_track_screen.dart';
import 'package:joypurhat/screens/bookings_screen.dart';
import 'package:joypurhat/screens/contact_screen.dart';
import 'package:joypurhat/screens/doctor_detail_screen.dart';
import 'package:joypurhat/screens/doctors_screen.dart';
import 'package:joypurhat/screens/home_screen.dart';
import 'package:joypurhat/screens/item_detail_screen.dart';
import 'package:joypurhat/screens/notices_screen.dart';
import 'package:joypurhat/screens/profile_screen.dart';
import 'package:joypurhat/screens/restaurant_screen.dart';
import 'package:joypurhat/screens/transport/train_detail_screen.dart';
import 'package:joypurhat/screens/transport/train_live_screen.dart';
import 'package:joypurhat/screens/transport/trip_screen.dart';
import 'package:joypurhat/theme.dart';
import 'package:joypurhat/widgets/common.dart' show FilterBar;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:joypurhat/screens/article_screen.dart';
import 'package:joypurhat/screens/call_list_screen.dart';
import 'package:joypurhat/screens/item_list_screen.dart';
import 'package:joypurhat/screens/shop_screen.dart';
import 'package:joypurhat/screens/transport/transport_screen.dart';

/// Opens every screen on a small phone (360 x 640) and fails on any layout
/// overflow or exception. Run it in both modes:
///   flutter test
///   flutter test --dart-define=DEMO=true
void main() {
  final raw = File('assets/data/joypurhat.json').readAsStringSync();
  final catalog = CatalogRepository.parse(raw);

  Future<void> show(WidgetTester tester, Widget screen, {Future<void> Function()? before}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final provider = CatalogProvider(loader: () async => catalog);
    await provider.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => BookingProvider()),
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    if (before != null) await before();
    // Scroll through the page so every lazily built part is laid out.
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      for (var i = 0; i < 40; i++) {
        await tester.drag(scrollables.first, const Offset(0, -500), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

  }

  Widget screenFor(Category c) {
    switch (c.template) {
      case 'call':
        return CallListScreen(category: c);
      case 'transport':
        return TransportScreen(category: c);
      case 'article':
        return ArticleScreen(category: c);
      case 'shop':
        return ShopScreen(category: c);
      case 'form':
        return BookingFormScreen(
          config: c.form!,
          target: BookingTarget.support(title: c.form!.title, sub: c.form!.sub, icon: c.icon),
        );
      default:
        return ItemListScreen(category: c);
    }
  }

  for (final key in catalog.order) {
    final c = catalog.categories[key]!;
    testWidgets('category $key', (tester) => show(tester, screenFor(c)));
    for (final (i, item) in c.items.indexed) {
      if (item.sample && !AppConfig.demoMode) continue;
      testWidgets('item $key #$i', (tester) => show(tester, ItemDetailScreen(category: c, item: item)));
    }
    final book = c.book;
    if (book != null) {
      testWidgets('booking form $key', (tester) async {
        await show(
          tester,
          BookingFormScreen(config: book, target: BookingTarget(title: c.title, phones: const ['01712345678'])),
        );
      });
      // The same form for each listed place, with its services and, for
      // samples, the slots that are already taken.
      for (final (i, item) in c.items.indexed) {
        if (item.menu.isEmpty && item.bookedSlots.isEmpty) continue;
        if (item.sample && !AppConfig.demoMode) continue;
        testWidgets('booking form $key #$i', (tester) async {
          await show(
            tester,
            BookingFormScreen(
              config: book,
              target: BookingTarget(
                title: item.name,
                phones: const ['01712345678'],
                services: item.menu,
                bookedSlots: item.sample ? item.bookedSlots : const [],
                color: c.color,
              ),
            ),
          );
        });
      }
    }
    final post = c.post;
    if (post != null) {
      testWidgets('post form $key', (tester) async {
        await show(
          tester,
          BookingFormScreen(
            config: post,
            target: BookingTarget.support(title: post.title, sub: post.sub, icon: c.icon, color: c.color),
          ),
        );
      });
    }
    final order = c.order;
    for (final (i, item) in c.items.indexed) {
      if (!item.hasMenu || (item.sample && !AppConfig.demoMode)) continue;
      testWidgets('restaurant $key #$i', (tester) => show(tester, RestaurantScreen(category: c, item: item)));
      testWidgets('restaurant $key #$i with a full cart', (tester) async {
        await show(
          tester,
          RestaurantScreen(category: c, item: item),
          before: () async {
            final cart = tester.element(find.byType(RestaurantScreen)).read<FoodCartProvider>();
            for (final d in item.foodMenu.expand((s) => s.dishes).take(4)) {
              cart.setQty(item, d, 2);
            }
            await tester.pump(const Duration(milliseconds: 400));
          },
        );
      });
      if (order != null) {
        final dishes = item.foodMenu.expand((s) => s.dishes).take(3).toList();
        testWidgets('checkout $key #$i', (tester) async {
          await show(
            tester,
            BookingFormScreen(
              config: order,
              target: BookingTarget(
                title: item.name,
                kind: 'order',
                phones: item.phones,
                lines: [for (final d in dishes) (d.name, 2, d.price)],
                deliveryFee: item.deliveryFee,
                demoOnly: item.sample,
                color: c.color,
              ),
            ),
          );
        });
      }
    }
  }

  testWidgets('home', (tester) => show(tester, const HomeScreen()));
  testWidgets('home with a search', (tester) async {
    await show(
      tester,
      const HomeScreen(),
      before: () async {
        await tester.enterText(find.byType(TextField).first, 'ডা');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });
  testWidgets('home search with no match', (tester) async {
    await show(
      tester,
      const HomeScreen(),
      before: () async {
        await tester.enterText(find.byType(TextField).first, 'zzzzqq');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });
  for (final pickup in [false, true]) {
    for (final minutes in [1, 10, 30, 90]) {
      final title = pickup ? 'pickup' : 'delivery';
      testWidgets('order tracker $title $minutes min', (tester) async {
        final b = Booking(
          id: 'T1',
          kind: 'order',
          title: 'নমুনা রেস্টুরেন্ট',
          status: 'অর্ডার চলছে (ডেমো)',
          createdAt: DateTime.now().subtract(Duration(minutes: minutes)),
          place: 'জয়পুরহাট সদর',
          code: 'JH-1234',
          codeLabel: 'অর্ডার নম্বর',
          rows: const [('খাবার', 'কাচ্চি বিরিয়ানি × ২'), ('মোট বিল', '৳ ৫৮০')],
          phone: '01712345678',
          isDemo: true,
          track: true,
          pickup: pickup,
          total: 580,
        );
        await show(tester, OrderTrackScreen(booking: b));
      });
    }
  }
  testWidgets('train live, nearest run', (tester) => show(tester, const TrainLiveScreen()));
  for (final t in catalog.transport.trains) {
    for (final r in t.runs) {
      testWidgets('train live ${t.nameEn} ${r.number}', (tester) => show(tester, TrainLiveScreen(train: t, run: r)));
    }
  }

  testWidgets('doctors', (tester) => show(tester, const DoctorsScreen()));
  for (final d in catalog.doctors) {
    testWidgets('doctor ${d.index}', (tester) => show(tester, DoctorDetailScreen(doctor: d)));
  }
  testWidgets('serial form', (tester) async {
    final d = catalog.doctors.first;
    await show(
      tester,
      BookingFormScreen(
        config: catalog.docBook,
        target: BookingTarget(title: d.name, kind: 'serial', weekdays: const [0, 2, 4]),
      ),
    );
  });
  for (final t in catalog.transport.trains) {
    testWidgets('train ${t.nameEn}', (tester) => show(tester, TrainDetailScreen(train: t)));
  }
  for (final t in catalog.transport.demoTrips) {
    testWidgets('trip ${t.id}', (tester) => show(tester, TripScreen(trip: t)));
  }
  testWidgets('notices', (tester) => show(tester, const NoticesScreen()));
  testWidgets('contact', (tester) => show(tester, const ContactScreen()));
  testWidgets('profile', (tester) => show(tester, const ProfileScreen()));
  testWidgets('bookings', (tester) => show(tester, const BookingsScreen()));
  testWidgets('about', (tester) => show(tester, const AboutScreen()));
  testWidgets('privacy', (tester) => show(tester, const PrivacyScreen()));

  // Real photos (data_sources/photos.json). Web photos cannot load in tests,
  // so this also checks that a broken photo falls back to the drawn picture.
  group('photos', () {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    for (final key in ['spots', 'hospital']) {
      final first = ((j['categories'] as Map<String, dynamic>)[key]['items'] as List).first as Map<String, dynamic>;
      first['photos'] = [
        {'src': 'https://example.invalid/a.jpg', 'credit': 'পরীক্ষার ছবি, CC BY-SA 4.0'},
        'https://example.invalid/b.jpg',
      ];
    }
    final withPhotos = CatalogRepository.parse(jsonEncode(j));

    test('are read from the data', () {
      final item = withPhotos.categories['spots']!.items.first;
      expect(item.photos.length, 2);
      expect(item.photos.first.credit, 'পরীক্ষার ছবি, CC BY-SA 4.0');
      expect(item.photos.last.isWeb, isTrue);
      expect(catalog.categories['spots']!.items.first.photos, isEmpty);
    });
    for (final key in ['spots', 'hospital']) {
      final c = withPhotos.categories[key]!;
      testWidgets('show in the $key gallery with their credit', (tester) async {
        await show(tester, ItemDetailScreen(category: c, item: c.items.first), before: () async {
          expect(find.text('ছবি: পরীক্ষার ছবি, CC BY-SA 4.0'), findsOneWidget);
          expect(find.textContaining('ছবি যোগ হবে'), findsNothing);
        });
      });
    }
    testWidgets('show on the spot card with a count', (tester) async {
      await show(tester, ItemListScreen(category: withPhotos.categories['spots']!), before: () async {
        expect(find.text('২টি ছবি'), findsOneWidget);
      });
    });
  });

  group('filters', () {
    testWidgets('show only chips that have cards in this mode', (tester) async {
      final c = catalog.categories['serviceman']!;
      await show(tester, ItemListScreen(category: c), before: () async {
        if (AppConfig.demoMode) {
          final bar = tester.widget<FilterBar>(find.byType(FilterBar));
          expect(bar.filters, containsAll(['সব', 'মোটরসাইকেল', 'প্লাম্বার']));
          bar.onSelected(bar.filters.indexOf('প্লাম্বার'));
          await tester.pump();
          expect(find.text('পানি প্লাম্বিং সার্ভিস'), findsOneWidget);
          expect(find.text('হাসান ট্রেডিং (বাজাজ)'), findsNothing);
        } else {
          // Only motorbike showrooms are real, so there is nothing to filter.
          expect(find.byType(FilterBar), findsNothing);
          expect(find.text('হাসান ট্রেডিং (বাজাজ)'), findsOneWidget);
        }
      });
    });
  });
}
