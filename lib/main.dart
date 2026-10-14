import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/booking_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/food_cart_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/transport_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled Hind Siliguri font is under the SIL Open Font License; it is
  // listed on the "অ্যাপ সম্পর্কে" > licences page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Hind Siliguri'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => BookingProvider()..load()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FoodCartProvider()),
        ChangeNotifierProvider(create: (_) => TransportProvider()),
      ],
      child: const JoypurhatApp(),
    ),
  );
}
