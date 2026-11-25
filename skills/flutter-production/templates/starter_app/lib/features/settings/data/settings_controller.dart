import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/responsive/text_scaling.dart';

@immutable
final class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.textScale = 1,
  });

  final ThemeMode themeMode;

  /// Null = follow the device language.
  final Locale? locale;

  /// In-app text size, multiplied with the system font size setting.
  final double textScale;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? Function()? locale,
    double? textScale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    locale: locale != null ? locale() : this.locale,
    textScale: textScale ?? this.textScale,
  );
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

final class SettingsController extends AsyncNotifier<AppSettings> {
  static const _themeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';
  static const _textScaleKey = 'settings.text_scale';

  @override
  Future<AppSettings> build() async {
    final prefs = ref.watch(preferencesStoreProvider);
    // Stored values are untrusted (old versions, corruption): parse safely.
    final themeName = await prefs.getString(_themeKey);
    final localeCode = await prefs.getString(_localeKey);
    final scale = double.tryParse(await prefs.getString(_textScaleKey) ?? '');
    final supported = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[themeName] ?? ThemeMode.system,
      locale: supported.contains(localeCode) ? Locale(localeCode!) : null,
      textScale: TextScaling.appScaleOptions.contains(scale) ? scale! : 1,
    );
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(_current.copyWith(themeMode: mode));
    await ref.read(preferencesStoreProvider).setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(_current.copyWith(locale: () => locale));
    await ref
        .read(preferencesStoreProvider)
        .setString(_localeKey, locale?.languageCode ?? 'system');
  }

  Future<void> setTextScale(double scale) async {
    if (!TextScaling.appScaleOptions.contains(scale)) return;
    state = AsyncData(_current.copyWith(textScale: scale));
    await ref
        .read(preferencesStoreProvider)
        .setString(_textScaleKey, scale.toString());
  }
}
