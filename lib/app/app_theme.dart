import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const midnight = Color(0xFF111C4E);
  static const indigo = Color(0xFF4338CA);
  static const cobalt = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);
  static const emerald = Color(0xFF10B981);
  static const coral = Color(0xFFF05D6C);
  static const canvas = Color(0xFFE8EDFA);
  static const softIndigo = Color(0xFFE8ECFF);
  static const softCyan = Color(0xFFE3F8FC);
  static const ink = Color(0xFF17203A);
  static const muted = Color(0xFF68738D);
  static const divider = Color(0xFFE3E8F3);
}

enum AppColorTheme {
  royal('Royal indigo'),
  ocean('Ocean teal'),
  emerald('Emerald'),
  plum('Plum dusk'),
  sunset('Sunset amber'),
  graphite('Graphite blue');

  const AppColorTheme(this.label);
  final String label;
}

enum AppBrightnessPreference {
  system('System'),
  light('Light'),
  dark('Night');

  const AppBrightnessPreference(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    AppBrightnessPreference.system => ThemeMode.system,
    AppBrightnessPreference.light => ThemeMode.light,
    AppBrightnessPreference.dark => ThemeMode.dark,
  };
}

enum AppBackgroundStyle {
  cloud('Cloud', Color(0xFFE8EDFA), Color(0xFF111827)),
  snow('Snow', Color(0xFFF1F4FA), Color(0xFF0B1020)),
  mint('Mint mist', Color(0xFFE4F3EE), Color(0xFF092923)),
  sand('Warm sand', Color(0xFFF8EDDF), Color(0xFF2A2119)),
  twilight('Twilight', Color(0xFFE1DFF5), Color(0xFF18152E)),
  slate('Slate', Color(0xFFDCE3EC), Color(0xFF101820)),
  rose('Rose smoke', Color(0xFFF2E1EA), Color(0xFF2A1722));

  const AppBackgroundStyle(this.label, this.lightColor, this.darkColor);
  final String label;
  final Color lightColor;
  final Color darkColor;

  Color get color => lightColor;

  Color colorFor(Brightness brightness) => switch (brightness) {
    Brightness.light => lightColor,
    Brightness.dark => darkColor,
  };
}

class AppAppearance {
  const AppAppearance({
    this.colorTheme = AppColorTheme.royal,
    this.backgroundStyle = AppBackgroundStyle.cloud,
    this.brightnessPreference = AppBrightnessPreference.system,
  });

  final AppColorTheme colorTheme;
  final AppBackgroundStyle backgroundStyle;
  final AppBrightnessPreference brightnessPreference;

  AppAppearance copyWith({
    AppColorTheme? colorTheme,
    AppBackgroundStyle? backgroundStyle,
    AppBrightnessPreference? brightnessPreference,
  }) {
    return AppAppearance(
      colorTheme: colorTheme ?? this.colorTheme,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      brightnessPreference: brightnessPreference ?? this.brightnessPreference,
    );
  }
}

class AppBrandTheme extends ThemeExtension<AppBrandTheme> {
  const AppBrandTheme({
    required this.heroStart,
    required this.heroMiddle,
    required this.heroEnd,
    required this.softAccent,
    required this.mutedText,
    required this.divider,
  });

  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
  final Color softAccent;
  final Color mutedText;
  final Color divider;

  static const fallback = AppBrandTheme(
    heroStart: AppPalette.midnight,
    heroMiddle: AppPalette.indigo,
    heroEnd: AppPalette.cobalt,
    softAccent: AppPalette.softIndigo,
    mutedText: AppPalette.muted,
    divider: AppPalette.divider,
  );

  List<Color> get heroGradient => [heroStart, heroMiddle, heroEnd];

  @override
  AppBrandTheme copyWith({
    Color? heroStart,
    Color? heroMiddle,
    Color? heroEnd,
    Color? softAccent,
    Color? mutedText,
    Color? divider,
  }) {
    return AppBrandTheme(
      heroStart: heroStart ?? this.heroStart,
      heroMiddle: heroMiddle ?? this.heroMiddle,
      heroEnd: heroEnd ?? this.heroEnd,
      softAccent: softAccent ?? this.softAccent,
      mutedText: mutedText ?? this.mutedText,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppBrandTheme lerp(covariant AppBrandTheme? other, double t) {
    if (other == null) return this;
    return AppBrandTheme(
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMiddle: Color.lerp(heroMiddle, other.heroMiddle, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      softAccent: Color.lerp(softAccent, other.softAccent, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light =>
      forAppearance(const AppAppearance(), brightness: Brightness.light);

  static ThemeData get dark =>
      forAppearance(const AppAppearance(), brightness: Brightness.dark);

  static ThemeData forAppearance(
    AppAppearance appearance, {
    Brightness brightness = Brightness.light,
  }) {
    final preset = _presetFor(appearance.colorTheme);
    final isDark = brightness == Brightness.dark;
    final pageBackground = appearance.backgroundStyle.colorFor(brightness);
    final surfaceBase = isDark ? const Color(0xFF151B29) : Colors.white;
    final surface = Color.alphaBlend(
      preset.primary.withValues(alpha: isDark ? .12 : .055),
      surfaceBase,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.primary,
      brightness: brightness,
      primary: preset.primary,
      secondary: preset.secondary,
      tertiary: preset.tertiary,
      surface: surface,
    );
    final mutedText = isDark ? const Color(0xFFACB7CD) : AppPalette.muted;
    final divider = isDark ? const Color(0xFF354057) : AppPalette.divider;
    final brand = AppBrandTheme(
      heroStart: preset.heroStart,
      heroMiddle: preset.heroMiddle,
      heroEnd: preset.heroEnd,
      softAccent: Color.alphaBlend(
        preset.primary.withValues(alpha: isDark ? .22 : .11),
        surface,
      ),
      mutedText: mutedText,
      divider: divider,
    );
    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textColor = isDark ? const Color(0xFFEAF0FC) : AppPalette.ink;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: pageBackground,
      extensions: [brand],
      textTheme: baseTextTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText.withValues(alpha: .82)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: preset.primary, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: preset.primary.withValues(alpha: isDark ? .18 : .08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor: brand.softAccent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: textColor)),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(color: surface, elevation: 10),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      popupMenuTheme: PopupMenuThemeData(color: surface),
      chipTheme: ChipThemeData(
        backgroundColor: brand.softAccent,
        selectedColor: preset.primary.withValues(alpha: .22),
        side: BorderSide(color: divider),
        labelStyle: TextStyle(color: textColor),
      ),
      dividerTheme: DividerThemeData(color: divider),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: textColor,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF283044) : preset.heroStart,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static _ThemePreset _presetFor(AppColorTheme theme) => switch (theme) {
    AppColorTheme.royal => const _ThemePreset(
      primary: Color(0xFF5145CD),
      secondary: Color(0xFF06B6D4),
      tertiary: Color(0xFF10B981),
      heroStart: Color(0xFF111C4E),
      heroMiddle: Color(0xFF4338CA),
      heroEnd: Color(0xFF2563EB),
    ),
    AppColorTheme.ocean => const _ThemePreset(
      primary: Color(0xFF008A91),
      secondary: Color(0xFF0891B2),
      tertiary: Color(0xFF22C55E),
      heroStart: Color(0xFF073B4C),
      heroMiddle: Color(0xFF007F86),
      heroEnd: Color(0xFF0EA5A4),
    ),
    AppColorTheme.emerald => const _ThemePreset(
      primary: Color(0xFF078A65),
      secondary: Color(0xFF0D9488),
      tertiary: Color(0xFF3B82F6),
      heroStart: Color(0xFF063F36),
      heroMiddle: Color(0xFF047857),
      heroEnd: Color(0xFF10B981),
    ),
    AppColorTheme.plum => const _ThemePreset(
      primary: Color(0xFF8B4BE8),
      secondary: Color(0xFFDB2777),
      tertiary: Color(0xFFF59E0B),
      heroStart: Color(0xFF351451),
      heroMiddle: Color(0xFF7C3AED),
      heroEnd: Color(0xFFC026D3),
    ),
    AppColorTheme.sunset => const _ThemePreset(
      primary: Color(0xFFE25545),
      secondary: Color(0xFFF59E0B),
      tertiary: Color(0xFFEC4899),
      heroStart: Color(0xFF501A2A),
      heroMiddle: Color(0xFFCF3F51),
      heroEnd: Color(0xFFF59E0B),
    ),
    AppColorTheme.graphite => const _ThemePreset(
      primary: Color(0xFF52677F),
      secondary: Color(0xFF0EA5E9),
      tertiary: Color(0xFF14B8A6),
      heroStart: Color(0xFF111827),
      heroMiddle: Color(0xFF334155),
      heroEnd: Color(0xFF64748B),
    ),
  };
}

class _ThemePreset {
  const _ThemePreset({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.heroStart,
    required this.heroMiddle,
    required this.heroEnd,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
}
