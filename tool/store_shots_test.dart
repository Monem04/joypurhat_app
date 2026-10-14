// Takes the phone screenshots used in the Play Store images.
//
//   flutter test tool/store_shots_test.dart
//   python3 tool/store_graphics.py
//
// The screenshots land in build/store_shots/ (1080 x 2340, the app's real
// screens with the bundled font) and the second command puts them into the
// promo images in store/. Only real data is shown: demo mode stays off.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joypurhat/data/catalog_repository.dart';
import 'package:joypurhat/providers/booking_provider.dart';
import 'package:joypurhat/providers/cart_provider.dart';
import 'package:joypurhat/providers/catalog_provider.dart';
import 'package:joypurhat/providers/food_cart_provider.dart';
import 'package:joypurhat/providers/profile_provider.dart';
import 'package:joypurhat/providers/transport_provider.dart';
import 'package:joypurhat/screens/call_list_screen.dart';
import 'package:joypurhat/screens/doctors_screen.dart';
import 'package:joypurhat/screens/home_shell.dart';
import 'package:joypurhat/screens/item_list_screen.dart';
import 'package:joypurhat/screens/transport/train_live_screen.dart';
import 'package:joypurhat/screens/transport/transport_screen.dart';
import 'package:joypurhat/theme.dart';
import 'package:provider/provider.dart';

void main() {
  final catalog = CatalogRepository.parse(File('assets/data/joypurhat.json').readAsStringSync());
  final out = Directory('build/store_shots')..createSync(recursive: true);
  final shotKey = GlobalKey();

  setUpAll(() async {
    Future<ByteData> bytes(String path) async => ByteData.sublistView(File(path).readAsBytesSync());
    final hind = FontLoader(appFont);
    for (final w in ['Regular', 'SemiBold', 'Bold']) {
      hind.addFont(bytes('assets/fonts/HindSiliguri-$w.ttf'));
    }
    await hind.load();
    // The icon font ships with the Flutter SDK, next to the test runner.
    final engine = File(Platform.resolvedExecutable).parent.parent.parent.path;
    await (FontLoader('MaterialIcons')..addFont(bytes('$engine/material_fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> shoot(WidgetTester tester, String name, Widget screen, {Future<void> Function()? before}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Real soft shadows instead of the test runner's flat ones.
    debugDisableShadows = false;
    final provider = CatalogProvider(loader: () async => catalog);
    await provider.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => BookingProvider()),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => FoodCartProvider()),
            ChangeNotifierProvider(create: (_) => TransportProvider()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: const Locale('bn', 'BD'),
            supportedLocales: const [Locale('bn', 'BD'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: screen,
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (before != null) await before();
    await tester.runAsync(() async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    debugDisableShadows = true;
  }

  final c = catalog.categories;
  testWidgets('home', (tester) => shoot(tester, 'home', const HomeShell()));
  testWidgets('doctors', (tester) => shoot(tester, 'doctors', const DoctorsScreen()));
  testWidgets('train live', (tester) => shoot(tester, 'train_live', const TrainLiveScreen()));
  testWidgets('bus', (tester) => shoot(tester, 'bus', TransportScreen(category: c['bus']!)));
  testWidgets('emergency', (tester) => shoot(tester, 'emergency', CallListScreen(category: c['emergency']!)));
  testWidgets('diagnostic', (tester) => shoot(tester, 'diagnostic', ItemListScreen(category: c['diagnostic']!)));
  testWidgets('spots', (tester) => shoot(tester, 'spots', ItemListScreen(category: c['spots']!)));
  testWidgets('restaurants', (tester) => shoot(tester, 'restaurants', ItemListScreen(category: c['restaurant']!)));
}
