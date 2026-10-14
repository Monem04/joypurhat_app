/// Settings to fill in before publishing on the Play Store.
class AppConfig {
  AppConfig._();

  static const appName = 'Joypurhat';
  static const version = '1.1.0';

  /// Demo mode shows the invented sample businesses from the prototype and
  /// the simulated bus seat booking and payment, each marked "নমুনা" or
  /// "ডেমো". Keep it off for the Play Store build.
  ///
  /// Turn it on for a test run with:
  ///   flutter run --dart-define=DEMO=true
  static const bool demoMode = bool.fromEnvironment('DEMO');

  /// The app owner's mobile number. Requests from the "Shop দিতে চাই" form
  /// and "ভুল তথ্য জানান" reports go here by SMS. Example: '017XXXXXXXX'.
  static const String supportPhone = '';

  /// The app owner's email, shown on the contact page and used for feedback.
  static const String supportEmail = '';

  /// Public link to the privacy policy (see PRIVACY_POLICY.md). The Play
  /// Console asks for the same link.
  static const String privacyPolicyUrl = '';

  /// Play Store link used by "অ্যাপ শেয়ার করুন". Matches applicationId in
  /// android/app/build.gradle.kts.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.joypurhat.app';
}
