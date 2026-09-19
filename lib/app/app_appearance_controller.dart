import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

final appAppearanceProvider =
    AsyncNotifierProvider<AppAppearanceController, AppAppearance>(
      AppAppearanceController.new,
    );

class AppAppearanceController extends AsyncNotifier<AppAppearance> {
  static const _themeKey = 'preference:appearance:color_theme';
  static const _backgroundKey = 'preference:appearance:background';
  static const _brightnessKey = 'preference:appearance:brightness';

  @override
  Future<AppAppearance> build() async {
    final storage = ref.watch(secureStorageServiceProvider);
    final values = await Future.wait([
      storage.read(_themeKey),
      storage.read(_backgroundKey),
      storage.read(_brightnessKey),
    ]);
    return AppAppearance(
      colorTheme: _enumByName(
        AppColorTheme.values,
        values[0],
        AppColorTheme.royal,
      ),
      backgroundStyle: _enumByName(
        AppBackgroundStyle.values,
        values[1],
        AppBackgroundStyle.cloud,
      ),
      brightnessPreference: _enumByName(
        AppBrightnessPreference.values,
        values[2],
        AppBrightnessPreference.system,
      ),
    );
  }

  Future<void> setColorTheme(AppColorTheme theme) async {
    final current = state.value ?? const AppAppearance();
    state = AsyncData(current.copyWith(colorTheme: theme));
    await ref.read(secureStorageServiceProvider).write(_themeKey, theme.name);
  }

  Future<void> setBackgroundStyle(AppBackgroundStyle style) async {
    final current = state.value ?? const AppAppearance();
    state = AsyncData(current.copyWith(backgroundStyle: style));
    await ref
        .read(secureStorageServiceProvider)
        .write(_backgroundKey, style.name);
  }

  Future<void> setBrightnessPreference(
    AppBrightnessPreference preference,
  ) async {
    final current = state.value ?? const AppAppearance();
    state = AsyncData(current.copyWith(brightnessPreference: preference));
    await ref
        .read(secureStorageServiceProvider)
        .write(_brightnessKey, preference.name);
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
