import 'package:flutter/material.dart';

import '../config.dart';
import '../services/launcher.dart';
import '../utils/bn.dart';
import 'common.dart';

/// Lets a user report a wrong number, time or address to the app owner.
Future<void> reportProblem(BuildContext context, String about) async {
  final body = 'Joypurhat অ্যাপে ভুল তথ্য: $about\nকী ভুল আছে: ';
  if (isBdMobile(AppConfig.supportPhone)) {
    return Launch.sms(context, AppConfig.supportPhone, body);
  }
  if (AppConfig.supportEmail.isNotEmpty) {
    return Launch.email(context, AppConfig.supportEmail, 'ভুল তথ্য: $about', body);
  }
  showToast(context, 'ভুল তথ্য জানানোর ব্যবস্থা শীঘ্রই চালু হবে।');
}

class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.about});
  final String about;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => reportProblem(context, about),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('কোনো তথ্য ভুল? জানান'),
    );
  }
}
