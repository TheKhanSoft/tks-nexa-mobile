import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  sunset('Sunset amber'),
  royal('Royal indigo'),
  ocean('Ocean teal'),
  emerald('Emerald'),
  plum('Plum dusk'),
  graphite('Graphite blue');

  const AppColorTheme(this.label);
  final String label;
}

extension AppThemeBackgrounds on AppColorTheme {
  List<AppBackgroundStyle> get availableBackgrounds => switch (this) {
    AppColorTheme.sunset => const [
      AppBackgroundStyle.cloud,
      AppBackgroundStyle.rose,
      AppBackgroundStyle.sand,
      AppBackgroundStyle.midnight,
      AppBackgroundStyle.pitch,
    ],
    AppColorTheme.royal => const [
      AppBackgroundStyle.cloud,
      AppBackgroundStyle.snow,
      AppBackgroundStyle.twilight,
      AppBackgroundStyle.deepSlate,
      AppBackgroundStyle.midnight,
      AppBackgroundStyle.pitch,
    ],
    AppColorTheme.ocean => const [
      AppBackgroundStyle.cloud,
      AppBackgroundStyle.mint,
      AppBackgroundStyle.midnight,
      AppBackgroundStyle.pitch,
    ],
    AppColorTheme.emerald => const [
      AppBackgroundStyle.mint,
      AppBackgroundStyle.snow,
      AppBackgroundStyle.deepSlate,
      AppBackgroundStyle.pitch,
    ],
    AppColorTheme.plum => const [
      AppBackgroundStyle.twilight,
      AppBackgroundStyle.rose,
      AppBackgroundStyle.snow,
      AppBackgroundStyle.midnight,
      AppBackgroundStyle.pitch,
    ],
    AppColorTheme.graphite => const [
      AppBackgroundStyle.snow,
      AppBackgroundStyle.cloud,
      AppBackgroundStyle.deepSlate,
      AppBackgroundStyle.pitch,
    ],
  };
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
  midnight('Midnight Dark', Color(0xFF13192B), Color(0xFF0B0F19)),
  pitch('OLED Black', Color(0xFF0D111A), Color(0xFF000000)),
  deepSlate('Deep Slate', Color(0xFF1E293B), Color(0xFF0F172A)),
  mint('Mint mist', Color(0xFFE4F3EE), Color(0xFF092923)),
  sand('Warm sand', Color(0xFFF8EDDF), Color(0xFF2A2119)),
  twilight('Twilight', Color(0xFFE1DFF5), Color(0xFF18152E)),
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
    this.colorTheme = AppColorTheme.sunset,
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
    heroStart: Color(0xFF501A2A),
    heroMiddle: Color(0xFFCF3F51),
    heroEnd: Color(0xFFF59E0B),
    softAccent: Color(0xFFFDE8E8),
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

    final rawBg = appearance.backgroundStyle.colorFor(brightness);
    final isDarkBg = rawBg.computeLuminance() < 0.22 || isDark;

    // Theme-specific distinct page background canvas
    final pageBackground = appearance.backgroundStyle == AppBackgroundStyle.cloud
        ? (isDarkBg ? preset.darkCanvas : preset.lightCanvas)
        : (isDarkBg
            ? Color.alphaBlend(preset.heroStart.withValues(alpha: .5), rawBg)
            : Color.alphaBlend(preset.primary.withValues(alpha: .05), rawBg));

    final surfaceBase = isDarkBg ? preset.cardSurfaceDark : preset.cardSurfaceLight;
    final surface = Color.alphaBlend(
      preset.primary.withValues(alpha: isDarkBg ? .08 : .03),
      surfaceBase,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: preset.primary,
      brightness: isDarkBg ? Brightness.dark : Brightness.light,
      primary: preset.primary,
      secondary: preset.secondary,
      tertiary: preset.tertiary,
      surface: surface,
    );
    final mutedText = isDarkBg ? const Color(0xFFACB7CD) : AppPalette.muted;
    final divider = isDarkBg ? const Color(0xFF354057) : AppPalette.divider;
    final brand = AppBrandTheme(
      heroStart: preset.heroStart,
      heroMiddle: preset.heroMiddle,
      heroEnd: preset.heroEnd,
      softAccent: Color.alphaBlend(
        preset.primary.withValues(alpha: isDarkBg ? .22 : .11),
        surface,
      ),
      mutedText: mutedText,
      divider: divider,
    );
    final baseTextTheme = isDarkBg
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textColor = isDarkBg ? const Color(0xFFEAF0FC) : AppPalette.ink;

    return ThemeData(
      useMaterial3: true,
      brightness: isDarkBg ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
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
        systemOverlayStyle: isDarkBg
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
            color: preset.primary.withValues(alpha: isDarkBg ? .18 : .08),
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
        backgroundColor: isDarkBg ? const Color(0xFF283044) : preset.heroStart,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static _ThemePreset _presetFor(AppColorTheme theme) => switch (theme) {
    AppColorTheme.sunset => const _ThemePreset(
      primary: Color(0xFFD9383A),
      secondary: Color(0xFFD97706),
      tertiary: Color(0xFFDB2777),
      heroStart: Color(0xFF3F121C),
      heroMiddle: Color(0xFFB91C1C),
      heroEnd: Color(0xFFD97706),
      lightCanvas: Color(0xFFFAF0EE),
      darkCanvas: Color(0xFF1E0A10),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF2B1218),
    ),
    AppColorTheme.royal => const _ThemePreset(
      primary: Color(0xFF5145CD),
      secondary: Color(0xFF06B6D4),
      tertiary: Color(0xFF10B981),
      heroStart: Color(0xFF111C4E),
      heroMiddle: Color(0xFF4338CA),
      heroEnd: Color(0xFF2563EB),
      lightCanvas: Color(0xFFEEF2FF),
      darkCanvas: Color(0xFF0C102B),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF1A2142),
    ),
    AppColorTheme.ocean => const _ThemePreset(
      primary: Color(0xFF008A91),
      secondary: Color(0xFF0891B2),
      tertiary: Color(0xFF22C55E),
      heroStart: Color(0xFF073B4C),
      heroMiddle: Color(0xFF007F86),
      heroEnd: Color(0xFF0EA5A4),
      lightCanvas: Color(0xFFE6FFFA),
      darkCanvas: Color(0xFF052026),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF12333B),
    ),
    AppColorTheme.emerald => const _ThemePreset(
      primary: Color(0xFF078A65),
      secondary: Color(0xFF0D9488),
      tertiary: Color(0xFF3B82F6),
      heroStart: Color(0xFF063F36),
      heroMiddle: Color(0xFF047857),
      heroEnd: Color(0xFF10B981),
      lightCanvas: Color(0xFFE6F4EA),
      darkCanvas: Color(0xFF05221A),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF0F3A2D),
    ),
    AppColorTheme.plum => const _ThemePreset(
      primary: Color(0xFF8B4BE8),
      secondary: Color(0xFFDB2777),
      tertiary: Color(0xFFF59E0B),
      heroStart: Color(0xFF351451),
      heroMiddle: Color(0xFF7C3AED),
      heroEnd: Color(0xFFC026D3),
      lightCanvas: Color(0xFFF8EEFE),
      darkCanvas: Color(0xFF1C0828),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF311642),
    ),
    AppColorTheme.graphite => const _ThemePreset(
      primary: Color(0xFF52677F),
      secondary: Color(0xFF0EA5E9),
      tertiary: Color(0xFF14B8A6),
      heroStart: Color(0xFF111827),
      heroMiddle: Color(0xFF334155),
      heroEnd: Color(0xFF64748B),
      lightCanvas: Color(0xFFF0F4F8),
      darkCanvas: Color(0xFF0B1220),
      cardSurfaceLight: Color(0xFFFFFFFF),
      cardSurfaceDark: Color(0xFF1E293B),
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
    required this.lightCanvas,
    required this.darkCanvas,
    required this.cardSurfaceLight,
    required this.cardSurfaceDark,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
  final Color lightCanvas;
  final Color darkCanvas;
  final Color cardSurfaceLight;
  final Color cardSurfaceDark;
}
