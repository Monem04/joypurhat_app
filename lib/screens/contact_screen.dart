import 'package:flutter/material.dart';

import '../config.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';
import '../widgets/report.dart';
import 'category_router.dart';

/// Ways to reach the app team, plus the most used hotlines.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasPhone = AppConfig.supportPhone.isNotEmpty;
    final hasEmail = AppConfig.supportEmail.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('যোগাযোগ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('অ্যাপ টিম'),
                if (!hasPhone && !hasEmail)
                  const Text('অ্যাপ টিমের নম্বর ও ইমেইল শীঘ্রই যোগ হবে।',
                      style: TextStyle(fontSize: 14.5, color: AppColors.muted)),
                if (hasPhone)
                  InfoLine(
                    icon: Icons.call_outlined,
                    label: 'ফোন',
                    value: phoneBn(AppConfig.supportPhone),
                    onTap: () => Launch.call(context, AppConfig.supportPhone),
                  ),
                if (hasEmail)
                  InfoLine(
                    icon: Icons.email_outlined,
                    label: 'ইমেইল',
                    value: AppConfig.supportEmail,
                    onTap: () => Launch.email(context, AppConfig.supportEmail, 'Joypurhat অ্যাপ', ''),
                    divider: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Row(
                  icon: Icons.flag_outlined,
                  title: 'ভুল তথ্য জানান',
                  sub: 'কোনো নম্বর, সময় বা ঠিকানা ভুল পেলে',
                  onTap: () => reportProblem(context, 'সাধারণ'),
                ),
                _Row(
                  icon: Icons.storefront_outlined,
                  title: 'Shop দিতে চাই',
                  sub: 'আপনার দোকান বা প্রতিষ্ঠান অ্যাপে যোগ করুন',
                  onTap: () => openCategoryKey(context, 'shopreg'),
                ),
                _Row(
                  icon: Icons.share_outlined,
                  title: 'অ্যাপ শেয়ার করুন',
                  sub: 'পরিচিতদের পাঠান',
                  onTap: () => Launch.share(
                      'জয়পুরহাট জেলার হাসপাতাল, ডাক্তার, ট্রেন, বাস ও জরুরি নম্বর এক অ্যাপে: ${AppConfig.playStoreUrl}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('দরকারি নম্বর', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Row(
                  icon: Icons.emergency_outlined,
                  title: 'জরুরি সেবা',
                  sub: 'পুলিশ, ফায়ার সার্ভিস, এম্বুলেন্স: ৯৯৯',
                  onTap: () => openCategoryKey(context, 'emergency'),
                ),
                _Row(
                  icon: Icons.support_agent_outlined,
                  title: 'হেল্পলাইন',
                  sub: 'স্বাস্থ্য, নারী ও শিশু, সরকারি তথ্য সেবা',
                  onTap: () => openCategoryKey(context, 'helpline'),
                ),
                _Row(
                  icon: Icons.account_balance_outlined,
                  title: 'উপজেলা অফিস',
                  sub: 'ইউএনও অফিসের ঠিকানা ও ফোন',
                  onTap: () => openCategoryKey(context, 'upazila'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBox(icon, size: 40),
      title: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }
}
