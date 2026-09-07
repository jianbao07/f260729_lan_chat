import 'package:flutter/material.dart';

class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.raised,
    required this.border,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentDim,
    required this.online,
    required this.onlineDim,
    required this.danger,
    required this.onAccent,
    required this.onAccentMuted,
    required this.bubbleBorder,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color raised;
  final Color border;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentDim;
  final Color online;
  final Color onlineDim;
  final Color danger;
  final Color onAccent;
  final Color onAccentMuted;
  final Color bubbleBorder;
  final List<BoxShadow> shadow;

  static const dark = AppColors(
    bg: Color(0xFF15171C),
    surface: Color(0xFF1C1F26),
    surfaceAlt: Color(0xFF20242C),
    raised: Color(0xFF262A33),
    border: Color(0xFF2A2E37),
    hairline: Color(0xFF23262E),
    textPrimary: Color(0xFFECE9E2),
    textSecondary: Color(0xFF8D9099),
    textTertiary: Color(0xFF5C6169),
    accent: Color(0xFFE8A33D),
    accentDim: Color(0x24E8A33D),
    online: Color(0xFF7FBF6E),
    onlineDim: Color(0x297FBF6E),
    danger: Color(0xFFD9634F),
    onAccent: Color(0xFF15171C),
    onAccentMuted: Color(0xA615171C),
    bubbleBorder: Color(0x00000000),
    shadow: [BoxShadow(color: Color(0x73000000), blurRadius: 60, offset: Offset(0, 30))],
  );

  static const light = AppColors(
    bg: Color(0xFFF4F2EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEBE8E1),
    raised: Color(0xFFFFFFFF),
    border: Color(0xFFD8D3C8),
    hairline: Color(0xFFE6E2D8),
    textPrimary: Color(0xFF1C1F26),
    textSecondary: Color(0xFF6B6E76),
    textTertiary: Color(0xFF8A8E96),
    accent: Color(0xFFE8A33D),
    accentDim: Color(0x2EE8A33D),
    online: Color(0xFF5FA34F),
    onlineDim: Color(0x295FA34F),
    danger: Color(0xFFC24B3A),
    onAccent: Color(0xFF15171C),
    onAccentMuted: Color(0xA615171C),
    bubbleBorder: Color(0xFFE0DBD1),
    shadow: [BoxShadow(color: Color(0x1F3C321E), blurRadius: 48, offset: Offset(0, 24))],
  );

  static const avatarInk = Color(0xFF15171C);
  static const avatarPalette = [
    Color(0xFFE8A33D),
    Color(0xFF6F9BD1),
    Color(0xFF7FBF6E),
    Color(0xFFC97BAF),
    Color(0xFFBF8F5E),
    Color(0xFF5CA6A6),
  ];

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static ThemeData theme(AppColors c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.online,
        onSecondary: c.onAccent,
        error: c.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      dividerColor: c.hairline,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.raised,
        contentTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}

const kMonoFont = 'monospace';
