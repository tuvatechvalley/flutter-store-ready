import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/text_scaling.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        // Scrollable: with very large text the dialog must not overflow.
        scrollable: true,
        content: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = Theme.of(context).colorScheme.error;
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('settings.deleteAccount.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: error),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountDone)));
    } on Object catch (e, st) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(mapToFailure(e, st)))),
      );
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context, Uri url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false; // No browser / blocked: handled by the message below.
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    final controller = ref.read(settingsControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth case Authenticated(:final user))
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                  ),
                const Divider(),
                _SectionTitle(l10n.theme),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                  // Wraps to a second line on narrow screens / large fonts.
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final (mode, label) in [
                        (ThemeMode.system, l10n.themeSystem),
                        (ThemeMode.light, l10n.themeLight),
                        (ThemeMode.dark, l10n.themeDark),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: settings.themeMode == mode,
                          onSelected: (_) =>
                              unawaited(controller.setThemeMode(mode)),
                        ),
                    ],
                  ),
                ),
                _SectionTitle(l10n.language),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final (locale, label) in [
                        (null, l10n.languageSystem),
                        (const Locale('tr'), 'Türkçe'),
                        (const Locale('en'), 'English'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: settings.locale == locale,
                          onSelected: (_) =>
                              unawaited(controller.setLocale(locale)),
                        ),
                    ],
                  ),
                ),
                _SectionTitle(l10n.textSize),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      for (final (i, scale)
                          in TextScaling.appScaleOptions.indexed)
                        ChoiceChip(
                          key: Key('settings.textScale.$i'),
                          label: Text(l10n.textSizeOptions[i]),
                          selected: settings.textScale == scale,
                          onSelected: (_) =>
                              unawaited(controller.setTextScale(scale)),
                        ),
                    ],
                  ),
                ),
                Text(
                  l10n.textSizeHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Insets.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Text(l10n.textSizePreview),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.about),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: l10n.appTitle,
                  ),
                ),
                if (ref.watch(envProvider).privacyPolicyUrl case final url?)
                  ListTile(
                    key: const Key('settings.privacyPolicy'),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l10n.privacyPolicy),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => unawaited(_openPrivacyPolicy(context, url)),
                  ),
                ListTile(
                  key: const Key('settings.deleteAccount'),
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(l10n.deleteAccount),
                  onTap: () => unawaited(_confirmDeleteAccount(context, ref)),
                ),
                ListTile(
                  key: const Key('settings.signOut'),
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(l10n.signOut),
                  onTap: () => unawaited(_confirmSignOut(context, ref)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Insets.md),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
