import 'package:flutter/material.dart';

import 'bookings_screen.dart';
import 'home_screen.dart';
import 'notices_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation: home, my bookings, notices, profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [HomeScreen(), BookingsScreen(), NoticesScreen(), ProfileScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'হোম'),
            NavigationDestination(
                icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'আমার বুকিং'),
            NavigationDestination(
                icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'নোটিশ'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'প্রোফাইল'),
          ],
        ),
      ),
    );
  }
}
