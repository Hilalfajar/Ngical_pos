import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app.dart';

/// Skala font responsif berdasarkan lebar layar.
/// Pakai: fontSize: rFont(context, 14)
/// Catatan: MaterialApp di main.dart sudah set textScaler global;
/// helper ini untuk kasus yang butuh ukuran eksplisit (mis. icon label).
double rFont(BuildContext context, double base) {
  final w = MediaQuery.sizeOf(context).width;
  final scale = w >= 1400
      ? 1.12
      : w >= 1100
          ? 1.08
          : w >= 900
              ? 1.04
              : 1.0;
  return base * scale;
}

class C {
  // Brand  indigo modern
  static const brand = Color(0xFF4F46E5);
  static const brandDark = Color(0xFF3730A3);
  static const brandMid = Color(0xFF6366F1);
  static const brandLight = Color(0xFFEEF2FF);
  static const brandSoft = Color(0xFFF5F3FF);

  // Surfaces
  static const bg = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF1F5F9);

  // Text
  static const text = Color(0xFF0F172A);
  static const text2 = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);

  // Borders & dividers
  static const border = Color(0xFFE2E8F0);
  static const borderSoft = Color(0xFFF1F5F9);

  // Semantic
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFFBEB);
}

/// Soft card shadow used across the app
List<BoxShadow> get cardShadow => [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.02),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];

List<BoxShadow> get cardShadowHover => [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.brand,
      primary: C.brand,
      surface: C.card,
    ),
    scaffoldBackgroundColor: C.bg,
    fontFamily: null, // system default  clean & readable
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: C.text,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: C.text,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: C.text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: C.text,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: C.text2, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13, color: C.muted, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: C.text,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.brand, width: 1.5),
      ),
      hintStyle: const TextStyle(color: C.faint, fontSize: 14),
      labelStyle: const TextStyle(color: C.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.brand,
        side: const BorderSide(color: C.brand, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: C.brand,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14))),
      backgroundColor: Color(0xFF1E293B),
      contentTextStyle: TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      // Tampil di atas
      insetPadding: EdgeInsets.fromLTRB(16, 60, 16, 0),
    ),
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1),
  );
}

/// Reusable page header used across non-POS screens
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tab = Provider.of<App>(context, listen: false).tab;
    final canBack = tab != 'POS';
    // Dari halaman settings detail kembali ke menu Pengaturan
    const settingsDetail = {
      'Settings',
      'Printer',
      'Staff',
      'Backup',
      'About',
    };
    final backTab = settingsDetail.contains(tab) ? 'SettingsMenu' : 'POS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canBack)
            IconButton(
              onPressed: () => context.read<App>().setTab(backTab),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: C.brand),
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
              constraints: const BoxConstraints(),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: C.text,
                    letterSpacing: -0.6,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: C.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Section label used in lists / settings
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: C.faint,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Batasi lebar konten di tablet agar form tidak melebar kosong.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final target = w < maxWidth ? w : maxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: target,
        child: child,
      ),
    );
  }
}
