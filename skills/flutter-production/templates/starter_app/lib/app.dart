import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/app_localizations.dart';
import 'core/responsive/text_scaling.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'core/widgets/privacy_shield.dart';
import 'features/settings/data/settings_controller.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) {
        // System font size × in-app text size, capped at 3x. Every screen is
        // tested up to that scale (see test/responsive_test.dart).
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaling.combine(
              media.textScaler,
              settings.textScale,
            ),
          ),
          child: PrivacyShield(
            child: OfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
