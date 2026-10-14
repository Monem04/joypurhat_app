import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/bn.dart';

/// Opens the phone's dialer, SMS app, Google Maps, browser or share sheet.
/// Calls go through the dialer (tel: link), so no call permission is needed.
class Launch {
  Launch._();

  static Future<void> call(BuildContext context, String number) =>
      _open(context, Uri(scheme: 'tel', path: dialable(number)));

  /// Opens the SMS app with the message filled in; the user presses send.
  static Future<void> sms(BuildContext context, String number, String body) => _open(
        context,
        Uri.parse('sms:${dialable(number)}?body=${Uri.encodeComponent(body)}'),
      );

  static Future<void> email(BuildContext context, String to, String subject, String body) => _open(
        context,
        Uri.parse('mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}'),
      );

  /// Google Maps search for a place; uses coordinates when known.
  static Future<void> map(BuildContext context, {String query = '', double? lat, double? lng}) {
    final q = (lat != null && lng != null) ? '$lat,$lng' : query;
    return _open(
      context,
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'),
    );
  }

  static Future<void> web(BuildContext context, String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    return _open(context, Uri.parse(u));
  }

  /// Opens an app's Play Store page.
  static Future<void> playStore(BuildContext context, String package) =>
      _open(context, Uri.parse('https://play.google.com/store/apps/details?id=$package'));

  static Future<void> share(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));

  static Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('এই কাজের জন্য ফোনে কোনো অ্যাপ পাওয়া যায়নি।')),
      );
    }
  }
}
