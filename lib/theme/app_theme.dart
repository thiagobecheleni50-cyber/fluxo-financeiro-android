import 'package:material_ui/material_ui.dart';

class AppColors {
  // Soft teal / blue-green gradient background tokens
  static const Color pageTop = Color(0xFFECF8F7);
  static const Color pageMid = Color(0xFFD9F0EE);
  static const Color pageBottom = Color(0xFFE7F4F6);

  // Hero teal gradient
  static const Color tealDeep = Color(0xFF0A6665);
  static const Color tealMid = Color(0xFF0F888B);
  static const Color tealLight = Color(0xFF28ADA8);

  // Accent & semantics
  static const Color primary = Color(0xFF0D8584);
  static const Color primarySoft = Color(0xFFE0F4F2);
  static const Color income = Color(0xFF0D9488);
  static const Color incomeSoft = Color(0xFFE3F7F4);
  static const Color expense = Color(0xFFD4636B);
  static const Color expenseSoft = Color(0xFFFCEEEF);

  // Neutrals with teal undertone
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGlass = Color(0xF5FFFFFF);
  static const Color border = Color(0xFFCDE6E4);
  static const Color textPrimary = Color(0xFF103537);
  static const Color textSecondary = Color(0xFF4C7274);
  static const Color textMuted = Color(0xFF77989A);
}

class AppGradients {
  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.pageTop,
      AppColors.pageMid,
      AppColors.pageBottom,
    ],
    stops: [0.0, 0.52, 1.0],
  );

  static const LinearGradient heroCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.tealDeep,
      AppColors.tealMid,
      AppColors.tealLight,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient incomeAction = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0C857D),
      Color(0xFF19AC9F),
    ],
  );

  static const LinearGradient expenseAction = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC95A63),
      Color(0xFFDE787E),
    ],
  );
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.pageTop,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
