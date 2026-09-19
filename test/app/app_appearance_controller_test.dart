import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/app/app_appearance_controller.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

import '../support/fakes.dart';

void main() {
  test('loads, applies, and securely persists appearance choices', () async {
    final storage = InMemorySecureStorage();
    final container = ProviderContainer(
      overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(appAppearanceProvider.future);
    expect(initial.colorTheme, AppColorTheme.royal);
    expect(initial.backgroundStyle, AppBackgroundStyle.cloud);
    expect(initial.brightnessPreference, AppBrightnessPreference.system);

    await container
        .read(appAppearanceProvider.notifier)
        .setColorTheme(AppColorTheme.ocean);
    await container
        .read(appAppearanceProvider.notifier)
        .setBackgroundStyle(AppBackgroundStyle.sand);
    await container
        .read(appAppearanceProvider.notifier)
        .setBrightnessPreference(AppBrightnessPreference.dark);

    final updated = container.read(appAppearanceProvider).requireValue;
    expect(updated.colorTheme, AppColorTheme.ocean);
    expect(updated.backgroundStyle, AppBackgroundStyle.sand);
    expect(updated.brightnessPreference, AppBrightnessPreference.dark);
    expect(
      storage.values['preference:appearance:color_theme'],
      AppColorTheme.ocean.name,
    );
    expect(
      storage.values['preference:appearance:background'],
      AppBackgroundStyle.sand.name,
    );
    expect(
      storage.values['preference:appearance:brightness'],
      AppBrightnessPreference.dark.name,
    );
  });

  test('builds the selected app color and background theme', () {
    final theme = AppTheme.forAppearance(
      const AppAppearance(
        colorTheme: AppColorTheme.emerald,
        backgroundStyle: AppBackgroundStyle.mint,
      ),
    );

    expect(theme.colorScheme.primary, const Color(0xFF078A65));
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.canvasColor, AppBackgroundStyle.mint.color);
    expect(
      theme.extension<AppBrandTheme>()?.heroStart,
      const Color(0xFF063F36),
    );
  });

  test('builds an adaptive night palette for every background family', () {
    for (final background in AppBackgroundStyle.values) {
      final theme = AppTheme.forAppearance(
        AppAppearance(
          colorTheme: AppColorTheme.graphite,
          backgroundStyle: background,
          brightnessPreference: AppBrightnessPreference.dark,
        ),
        brightness: Brightness.dark,
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.canvasColor, background.darkColor);
      expect(theme.colorScheme.surface.computeLuminance(), lessThan(.2));
    }
  });
}
