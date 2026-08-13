import 'package:flutter/material.dart';

/// Status colours Material's [ColorScheme] does not define.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.onStatus,
  });

  final Color success;
  final Color warning;
  final Color info;

  /// Foreground colour for text and icons drawn on any status colour.
  final Color onStatus;

  /// Foreground for content sitting on a photo scrim, which is dark in both
  /// themes — so this stays light regardless of brightness.
  static const Color onScrim = Color(0xFFFFFFFF);

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? onStatus,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      onStatus: onStatus ?? this.onStatus,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  AppSemanticColors get statusColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

/// Daisy's Kitchen visual language.
///
/// Every colour used by the app should come from [ColorScheme] so both themes
/// stay coherent; screens should not reach for `Colors.*` directly.
class AppTheme {
  const AppTheme._();

  /// Bundled serif used for headings. Web renders through CanvasKit, which has
  /// no access to system faces, so the font must ship with the app.
  static const String _serifFamily = 'DaisySerif';

  /// Widest comfortable measure for page content on large displays.
  static const double maxContentWidth = 1200;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF025159),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD5EBED),
    onPrimaryContainer: Color(0xFF02333A),
    secondary: Color(0xFF8C5F45),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF4E3D8),
    onSecondaryContainer: Color(0xFF46291A),
    tertiary: Color(0xFF3E848C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDDEEF0),
    onTertiaryContainer: Color(0xFF02333A),
    error: Color(0xFF9B2C22),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF7DDDA),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFBFCFC),
    onSurface: Color(0xFF192224),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F8F8),
    surfaceContainer: Color(0xFFF0F4F4),
    surfaceContainerHigh: Color(0xFFE9EFEF),
    surfaceContainerHighest: Color(0xFFE2EAEA),
    onSurfaceVariant: Color(0xFF4C6165),
    outline: Color(0xFF7A9094),
    outlineVariant: Color(0xFFD3DDDE),
    shadow: Color(0x1A000000),
    scrim: Color(0x66000000),
    inverseSurface: Color(0xFF192224),
    onInverseSurface: Color(0xFFEFF4F4),
    inversePrimary: Color(0xFF7AB8BF),
    surfaceTint: Color(0xFF025159),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7AB8BF),
    onPrimary: Color(0xFF00343A),
    primaryContainer: Color(0xFF1D4A50),
    onPrimaryContainer: Color(0xFFC4EEF2),
    secondary: Color(0xFFD3A489),
    onSecondary: Color(0xFF412716),
    secondaryContainer: Color(0xFF5A3A28),
    onSecondaryContainer: Color(0xFFF4E3D8),
    tertiary: Color(0xFF9CCDD3),
    onTertiary: Color(0xFF00343A),
    tertiaryContainer: Color(0xFF24565C),
    onTertiaryContainer: Color(0xFFC4EEF2),
    error: Color(0xFFEFB4AE),
    onError: Color(0xFF5A140F),
    errorContainer: Color(0xFF7A241C),
    onErrorContainer: Color(0xFFF7DDDA),
    surface: Color(0xFF0F1719),
    onSurface: Color(0xFFE0E8E9),
    surfaceContainerLowest: Color(0xFF0A1113),
    surfaceContainerLow: Color(0xFF141E20),
    surfaceContainer: Color(0xFF182225),
    surfaceContainerHigh: Color(0xFF1E2A2D),
    surfaceContainerHighest: Color(0xFF243133),
    onSurfaceVariant: Color(0xFFB1C2C4),
    outline: Color(0xFF7A9094),
    outlineVariant: Color(0xFF2C3A3D),
    shadow: Color(0xCC000000),
    scrim: Color(0xCC000000),
    inverseSurface: Color(0xFFE0E8E9),
    onInverseSurface: Color(0xFF192224),
    inversePrimary: Color(0xFF025159),
    surfaceTint: Color(0xFF7AB8BF),
  );

  static const AppSemanticColors _lightStatus = AppSemanticColors(
    success: Color(0xFF2F6B4F),
    warning: Color(0xFF8A5A1B),
    info: Color(0xFF2C5D77),
    onStatus: Color(0xFFFFFFFF),
  );

  static const AppSemanticColors _darkStatus = AppSemanticColors(
    success: Color(0xFF8ECBA8),
    warning: Color(0xFFE0B577),
    info: Color(0xFF9FC5DA),
    onStatus: Color(0xFF10191B),
  );

  static ThemeData get light => _build(lightScheme, _lightStatus);

  static ThemeData get dark => _build(darkScheme, _darkStatus);

  static ThemeData _build(ColorScheme colors, AppSemanticColors status) {
    final textTheme = _textTheme(colors);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      textTheme: textTheme,
      extensions: [status],
      scaffoldBackgroundColor: colors.surface,
      dividerColor: colors.outlineVariant,
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _inputBorder(colors.outlineVariant),
        enabledBorder: _inputBorder(colors.outlineVariant),
        focusedBorder: _inputBorder(colors.primary, width: 1.5),
        errorBorder: _inputBorder(colors.error),
        focusedErrorBorder: _inputBorder(colors.error, width: 1.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: textTheme.headlineSmall,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(ColorScheme colors) {
    final base = ThemeData(brightness: colors.brightness).textTheme;

    TextStyle serif(TextStyle? style, double size, FontWeight weight) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: _serifFamily,
        fontSize: size,
        fontWeight: weight,
        color: colors.onSurface,
        height: 1.2,
        letterSpacing: -0.2,
      );
    }

    TextStyle sans(TextStyle? style, double size, FontWeight weight,
        {Color? color, double height = 1.45}) {
      return (style ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? colors.onSurface,
        height: height,
      );
    }

    return base.copyWith(
      displaySmall: serif(base.displaySmall, 34, FontWeight.w600),
      headlineLarge: serif(base.headlineLarge, 30, FontWeight.w600),
      headlineMedium: serif(base.headlineMedium, 26, FontWeight.w600),
      headlineSmall: serif(base.headlineSmall, 22, FontWeight.w600),
      titleLarge: serif(base.titleLarge, 20, FontWeight.w600),
      titleMedium: serif(base.titleMedium, 17, FontWeight.w600),
      titleSmall: sans(base.titleSmall, 14, FontWeight.w600, height: 1.3),
      bodyLarge: sans(base.bodyLarge, 16, FontWeight.w400),
      bodyMedium: sans(base.bodyMedium, 14, FontWeight.w400),
      bodySmall: sans(base.bodySmall, 13, FontWeight.w400,
          color: colors.onSurfaceVariant),
      labelLarge: sans(base.labelLarge, 14, FontWeight.w600, height: 1.2),
      labelMedium: sans(base.labelMedium, 12, FontWeight.w500,
          color: colors.onSurfaceVariant, height: 1.2),
      labelSmall: sans(base.labelSmall, 11, FontWeight.w500,
          color: colors.onSurfaceVariant, height: 1.2),
    );
  }
}
