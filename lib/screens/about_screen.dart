import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/catalog_provider.dart';
import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';

/// What the app is, where its data comes from, and that it is not a
/// government app (Play Store policy for apps showing government info).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>().catalog;
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ সম্পর্কে')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              children: [
                const IconBox(Icons.place, size: 64),
                const SizedBox(height: 12),
                const Text(AppConfig.appName,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
                Text('ভার্সন ${bn(AppConfig.version)}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                const Text(
                  'জয়পুরহাট জেলার হাসপাতাল, ডাক্তার, জরুরি নম্বর, ট্রেন, বাস, ব্যাংক, শিক্ষাপ্রতিষ্ঠান, হোটেল ও অন্যান্য সেবার তথ্য এক জায়গায়।',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const NoteBanner(
            'এটি কোনো সরকারি অ্যাপ নয় এবং কোনো সরকারি প্রতিষ্ঠানের প্রতিনিধিত্ব করে না। সরকারি অফিস, হাসপাতাল ও হটলাইনের তথ্য সরকারি ওয়েবসাইট (যেমন joypurhat.gov.bd এর উপজেলা পোর্টাল, hris.mohfw.gov.bd, railway.gov.bd) ও অন্যান্য প্রকাশ্য উৎস থেকে নেওয়া। প্রতিটি তথ্যের নিচে উৎসের লিংক দেওয়া আছে।',
            icon: Icons.gavel_outlined,
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('তথ্য নিয়ে'),
                Text(
                  'শেষ যাচাই: ${fullDateBn(DateTime.parse(catalog.checked))}। ডাক্তারের চেম্বারের সময়, বাস ভাড়া ও ট্রেনের সময় বদলাতে পারে, তাই যাওয়ার আগে ফোন করে নিশ্চিত হয়ে নিন। "যাচাই করে নিন" চিহ্ন থাকা তথ্য একটি মাত্র বা পুরনো উৎস থেকে পাওয়া।',
                  style: const TextStyle(fontSize: 14.5, height: 1.55),
                ),
                const SizedBox(height: 10),
                const Text(
                  'বুকিং বা সিরিয়ালের অনুরোধ আপনার ফোন থেকে এসএমএস বা কলে সরাসরি প্রতিষ্ঠানে যায়। অ্যাপ নিজে কোনো টাকা নেয় না।',
                  style: TextStyle(fontSize: 14.5, height: 1.55),
                ),
              ],
            ),
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: 12),
            const DemoBanner('ডেমো মোড চালু আছে। "নমুনা" লেখা দোকান ও বাসের সিট বুকিং আসল নয়।'),
          ],
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
                  title: const Text('প্রাইভেসি পলিসি'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.star_outline, color: AppColors.accent),
                  title: const Text('Play Store এ রেটিং দিন'),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () => Launch.web(context, AppConfig.playStoreUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.accent),
                  title: const Text('ওপেন সোর্স লাইসেন্স'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: AppConfig.version,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The privacy policy, in Bangla. The same text is in PRIVACY_POLICY.md for
/// the public link the Play Console asks for.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = [
    (
      'কী তথ্য রাখা হয়',
      'আপনি প্রোফাইলে নাম, মোবাইল নম্বর ও উপজেলা দিলে তা শুধু আপনার ফোনে রাখা হয়, যাতে ফর্ম নিজে থেকে পূরণ হয়। আপনার বুকিংয়ের তালিকাও শুধু ফোনে থাকে। আমাদের কোনো সার্ভারে এসব পাঠানো হয় না।'
    ),
    (
      'বুকিং ও অনুরোধ',
      'বুকিং, সিরিয়াল বা অর্ডারের ফর্ম জমা দিলে আপনার ফোনের এসএমএস অ্যাপে মেসেজ তৈরি হয়। আপনি Send চাপলে তা আপনার নম্বর থেকে সরাসরি সেই প্রতিষ্ঠানে যায়। খাবারের অর্ডারে ডেলিভারির ঠিকানাও এই মেসেজে থাকে। To-Let, দোকান যুক্ত করা বা ভুল তথ্য জানানোর মেসেজ যায় অ্যাপের মালিকের নম্বরে। কল করলে ফোনের ডায়ালার খোলে। অ্যাপ নিজে কোনো কল বা এসএমএস পাঠায় না।'
    ),
    (
      'অনুমতি',
      'অ্যাপটি ফোনের কন্টাক্ট, লোকেশন, ক্যামেরা বা ফাইল পড়ার অনুমতি চায় না। ম্যাপ দেখতে চাইলে Google Maps খোলে।'
    ),
    (
      'অন্য অ্যাপ ও ওয়েবসাইট',
      'ম্যাপ, রেলের টিকিট সাইট বা উৎসের লিংকে গেলে সেই অ্যাপ বা সাইটের নিজস্ব প্রাইভেসি নীতি প্রযোজ্য।'
    ),
    (
      'তথ্য মুছে ফেলা',
      'প্রোফাইল পাতা থেকে নিজের তথ্য মুছতে পারবেন। অ্যাপ আনইনস্টল করলে ফোনে রাখা সব তথ্য মুছে যায়।'
    ),
    (
      'শিশু',
      'অ্যাপটি সাধারণ মানুষের জন্য, শিশুদের লক্ষ্য করে বানানো নয়, এবং শিশুদের কাছ থেকে জেনে বুঝে কোনো তথ্য নেয় না।'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('প্রাইভেসি পলিসি')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, s) in sections.indexed) ...[
                  Text(s.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(s.$2, style: const TextStyle(fontSize: 14.5, height: 1.55)),
                  if (i < sections.length - 1) const SizedBox(height: 14),
                ],
                if (AppConfig.supportEmail.isNotEmpty || AppConfig.supportPhone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('যোগাযোগ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (AppConfig.supportEmail.isNotEmpty) AppConfig.supportEmail,
                      if (AppConfig.supportPhone.isNotEmpty) phoneBn(AppConfig.supportPhone),
                    ].join(', '),
                    style: const TextStyle(fontSize: 14.5),
                  ),
                ],
              ],
            ),
          ),
          if (AppConfig.privacyPolicyUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Launch.web(context, AppConfig.privacyPolicyUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('ওয়েবসাইটে পড়ুন'),
            ),
          ],
        ],
      ),
    );
  }
}
