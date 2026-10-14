import 'package:flutter/material.dart';

import '../config.dart';
import '../services/launcher.dart';
import '../theme.dart';
import 'about_screen.dart';
import 'bookings_screen.dart';
import 'category_router.dart';
import 'contact_screen.dart';
import 'doctors_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Row(
                children: [
                  Icon(Icons.place, color: AppColors.primary, size: 30),
                  SizedBox(width: 8),
                  Text(AppConfig.appName,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ],
              ),
            ),
            const Divider(height: 1),
            _item(Icons.event_note_outlined, 'আমার বুকিং', () => go(const BookingsScreen())),
            _item(Icons.medical_services_outlined, 'সব ডাক্তার', () => go(const DoctorsScreen())),
            _item(Icons.emergency_outlined, 'জরুরি নম্বর', () {
              Navigator.pop(context);
              openCategoryKey(context, 'emergency');
            }),
            _item(Icons.train_outlined, 'ট্রেনের সময়', () {
              Navigator.pop(context);
              openCategoryKey(context, 'train');
            }),
            const Divider(height: 1),
            _item(Icons.support_agent_outlined, 'যোগাযোগ ও মতামত', () => go(const ContactScreen())),
            _item(Icons.info_outline, 'অ্যাপ সম্পর্কে', () => go(const AboutScreen())),
            _item(Icons.privacy_tip_outlined, 'প্রাইভেসি পলিসি', () => go(const PrivacyScreen())),
            _item(Icons.share_outlined, 'অ্যাপ শেয়ার করুন', () {
              Navigator.pop(context);
              Launch.share('জয়পুরহাট জেলার হাসপাতাল, ডাক্তার, ট্রেন, বাস ও জরুরি নম্বর এক অ্যাপে: ${AppConfig.playStoreUrl}');
            }),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Text('ভার্সন ${AppConfig.version}', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
        onTap: onTap,
      );
}
