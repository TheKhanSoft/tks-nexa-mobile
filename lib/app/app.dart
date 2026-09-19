import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/app/app_appearance_controller.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';

class TksNexaApp extends ConsumerWidget {
  const TksNexaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appearance =
        ref.watch(appAppearanceProvider).value ?? const AppAppearance();
    return MaterialApp.router(
      title: 'TKS Nexa Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forAppearance(appearance, brightness: Brightness.light),
      darkTheme: AppTheme.forAppearance(
        appearance,
        brightness: Brightness.dark,
      ),
      themeMode: appearance.brightnessPreference.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final content = _AppCanvas(child: child ?? const SizedBox.shrink());
        if (!kDebugMode) return content;
        return Banner(
          message: 'DEVELOPMENT SECURITY MODE',
          location: BannerLocation.topEnd,
          color: Colors.deepOrange,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
          child: content,
        );
      },
    );
  }
}

class _AppCanvas extends StatelessWidget {
  const _AppCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final backgroundColor = theme.canvasColor;
    return ColoredBox(
      color: backgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                brand.softAccent.withValues(alpha: .92),
                backgroundColor,
              ),
              backgroundColor,
              Color.alphaBlend(
                theme.colorScheme.secondary.withValues(alpha: .11),
                backgroundColor,
              ),
            ],
            stops: const [0, .54, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    );
  }
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          _AppCanvas(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Secure configuration required',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
