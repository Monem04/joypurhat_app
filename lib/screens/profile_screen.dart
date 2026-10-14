import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/booking_provider.dart';
import '../providers/profile_provider.dart';
import '../theme.dart';
import '../utils/bn.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'bookings_screen.dart';
import 'contact_screen.dart';

const upazilas = ['জয়পুরহাট সদর', 'আক্কেলপুর', 'কালাই', 'ক্ষেতলাল', 'পাঁচবিবি'];

/// Name and number for filling forms, kept on this phone only.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _upazila = '';
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.watch<ProfileProvider>();
    // Fill the fields once the saved profile has loaded.
    if (!_filled && !p.isEmpty) {
      _name.text = p.name;
      _phone.text = p.phone;
      _upazila = p.upazila;
      _filled = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<ProfileProvider>().save(name: _name.text, phone: _phone.text, upazila: _upazila);
    _filled = true;
    if (mounted) showToast(context, 'সেভ হয়েছে');
  }

  Future<void> _clear() async {
    await context.read<ProfileProvider>().clear();
    setState(() {
      _name.clear();
      _phone.clear();
      _upazila = '';
    });
    if (mounted) showToast(context, 'আপনার তথ্য মুছে ফেলা হয়েছে');
  }

  @override
  Widget build(BuildContext context) {
    final bookings = context.watch<BookingProvider>().items.length;
    return Scaffold(
      appBar: AppBar(title: const Text('প্রোফাইল')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('আপনার তথ্য'),
                  const Text('বুকিং ফর্মে নিজে থেকে বসবে। শুধু এই ফোনে থাকে, কোথাও পাঠানো হয় না।',
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.muted)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'নাম', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'মোবাইল নম্বর', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty && !isBdMobile(s)) return 'সঠিক মোবাইল নম্বর দিন, ০১ দিয়ে শুরু, মোট ১১ সংখ্যা';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('উপজেলা', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final u in upazilas)
                        ChoiceChip(
                          label: Text(u),
                          selected: _upazila == u,
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _upazila == u ? Colors.white : AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _upazila = _upazila == u ? '' : u),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('সেভ করুন')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const IconBox(Icons.event_note_outlined, size: 40),
                    title: const Text('আমার বুকিং', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(bookings == 0 ? 'এখনো কিছু নেই' : '${bn(bookings)}টি'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen())),
                  ),
                  ListTile(
                    leading: const IconBox(Icons.support_agent_outlined, size: 40),
                    title: const Text('যোগাযোগ ও মতামত', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
                  ),
                  ListTile(
                    leading: const IconBox(Icons.info_outline, size: 40),
                    title: const Text('অ্যাপ সম্পর্কে', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                  ),
                  ListTile(
                    leading: const IconBox(Icons.privacy_tip_outlined, size: 40),
                    title: const Text('প্রাইভেসি পলিসি', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text('আমার তথ্য মুছে ফেলুন', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
