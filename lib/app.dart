import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/catalog_provider.dart';
import 'providers/transport_provider.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';

class JoypurhatApp extends StatelessWidget {
  const JoypurhatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('bn', 'BD'),
      supportedLocales: const [Locale('bn', 'BD'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _LoadGate(),
    );
  }
}

/// Shows a loader until the directory data is read from the app bundle.
class _LoadGate extends StatelessWidget {
  const _LoadGate();

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.isReady) {
      final transport = context.read<TransportProvider>();
      if (transport.trips.isEmpty && AppConfig.demoMode) {
        transport.setTrips(catalog.catalog.transport.demoTrips);
      }
      return const HomeShell();
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: catalog.error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 56, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(AppConfig.appName,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                )
              : EmptyState(
                  icon: Icons.error_outline,
                  title: 'তথ্য খোলা যায়নি',
                  text: 'অ্যাপটি বন্ধ করে আবার খুলুন। সমস্যা থাকলে অ্যাপটি আপডেট করুন।',
                  actionLabel: 'আবার চেষ্টা করুন',
                  onAction: () => context.read<CatalogProvider>().load(),
                ),
        ),
      ),
    );
  }
}
