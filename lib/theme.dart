import 'package:flutter/material.dart';

/// The bundled Bangla typeface (SIL Open Font License, see assets/fonts/OFL.txt).
const appFont = 'HindSiliguri';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF115E59);
  static const accent = Color(0xFF0E7490);
  static const background = Color(0xFFEAF3F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7FAFA);
  static const tint = Color(0xFFE0F2EF);
  static const text = Color(0xFF10201F);
  static const textSoft = Color(0xFF24403D);
  static const muted = Color(0xFF4A5B5A);
  static const border = Color(0xFFCFE3E0);
  static const divider = Color(0xFFEEF3F2);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFEF3F2);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFECFDF3);
  static const successText = Color(0xFF14532D);
  static const warnBg = Color(0xFFFEF3C7);
  static const warnText = Color(0xFF78350F);
  static const infoBg = Color(0xFFDBEAFE);
  static const infoText = Color(0xFF1E3A8A);
}

/// One colour group: a tile gradient (light to dark), its shadow, and the
/// soft background and deep text colour used for accents on that group.
class Group {
  const Group(this.light, this.dark, this.shadow, this.soft, this.deep);
  final Color light;
  final Color dark;
  final Color shadow;
  final Color soft;
  final Color deep;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, dark],
      );

  static const red = Group(Color(0xFFFB7185), Color(0xFFE11D48), Color(0x4DE11D48), Color(0xFFFFE4E6), Color(0xFFBE123C));
  static const teal = Group(Color(0xFF2DD4BF), Color(0xFF0E7490), Color(0x4D0E7490), Color(0xFFDDF3F0), Color(0xFF0E7490));
  static const orange = Group(Color(0xFFFDBA74), Color(0xFFEA580C), Color(0x4DEA580C), Color(0xFFFFEDD5), Color(0xFFC2410C));
  static const indigo = Group(Color(0xFFA5B4FC), Color(0xFF4F46E5), Color(0x4D4F46E5), Color(0xFFE0E7FF), Color(0xFF4338CA));
  static const blue = Group(Color(0xFF7DD3FC), Color(0xFF0369A1), Color(0x4D0369A1), Color(0xFFE0F2FE), Color(0xFF0369A1));
  static const green = Group(Color(0xFF86EFAC), Color(0xFF15803D), Color(0x4D15803D), Color(0xFFDCFCE7), Color(0xFF15803D));
  static const purple = Group(Color(0xFFD8B4FE), Color(0xFF7E22CE), Color(0x4D7E22CE), Color(0xFFF3E8FF), Color(0xFF7E22CE));
  static const slate = Group(Color(0xFF94A3B8), Color(0xFF334155), Color(0x4D334155), Color(0xFFE2E8F0), Color(0xFF334155));
  static const amber = Group(Color(0xFFFCD34D), Color(0xFFD97706), Color(0x52D97706), Color(0xFFFEF3C7), Color(0xFFB45309));
  static const cyan = Group(Color(0xFF67E8F9), Color(0xFF0891B2), Color(0x4D0891B2), Color(0xFFCFFAFE), Color(0xFF0E7490));
  static const pink = Group(Color(0xFFF9A8D4), Color(0xFFDB2777), Color(0x4DDB2777), Color(0xFFFCE7F3), Color(0xFFBE185D));
  static const emerald = Group(Color(0xFF6EE7B7), Color(0xFF047857), Color(0x4D047857), Color(0xFFD1FAE5), Color(0xFF047857));

  static const _byName = {
    'red': red,
    'teal': teal,
    'orange': orange,
    'indigo': indigo,
    'blue': blue,
    'green': green,
    'purple': purple,
    'slate': slate,
    'amber': amber,
    'cyan': cyan,
    'pink': pink,
    'emerald': emerald,
  };

  /// The group named in the data file; teal when unknown.
  static Group of(String name) => _byName[name] ?? teal;
}

/// True when the phone asks for less motion (Settings > Accessibility).
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// New pages slide in a little from the right while fading in. With
/// reduced motion they simply appear.
class _SlideFadeTransitions extends PageTransitionsBuilder {
  const _SlideFadeTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: appFont);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SlideFadeTransitions(),
        TargetPlatform.iOS: _SlideFadeTransitions(),
      },
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: appFont,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: appFont, fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: appFont, fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontFamily: appFont, fontSize: 14, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.tint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: appFont, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
