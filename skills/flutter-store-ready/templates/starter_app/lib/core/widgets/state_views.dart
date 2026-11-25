import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../l10n/app_localizations.dart';
import '../responsive/breakpoints.dart';

/// Every screen that loads data must render all four states:
/// loading, error (with retry), empty, data. This widget makes that the
/// default instead of an afterthought.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    super.key,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    // Keep showing previous data while refreshing (no flicker).
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (d) {
        if (isEmpty?.call(d) ?? false) {
          return empty ?? const SizedBox.shrink();
        }
        return data(d);
      },
      loading: () => const LoadingView(),
      error: (error, stack) =>
          ErrorView(failure: mapToFailure(error, stack), onRetry: onRetry),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(Insets.lg),
      child: CircularProgressIndicator.adaptive(),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, super.key, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRetry = onRetry != null && failure.isRetryable;
    return _MessageView(
      icon: switch (failure) {
        NetworkFailure() || TimeoutFailure() => Icons.wifi_off_rounded,
        SecurityFailure() => Icons.gpp_bad_outlined,
        NotFoundFailure() => Icons.search_off_rounded,
        ForbiddenFailure() || UnauthorizedFailure() => Icons.lock_outline,
        _ => Icons.error_outline_rounded,
      },
      title: l10n.somethingWentWrong,
      message: l10n.failureMessage(failure),
      action: canRetry
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            )
          : null,
      isError: true,
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _MessageView(icon: icon, title: title, message: message, action: action);
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    // Scrollable so large fonts / landscape phones never overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Insets.maxFormWidth),
          child: Semantics(
            liveRegion: isError,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: color),
                const SizedBox(height: Insets.md),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  const SizedBox(height: Insets.lg),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
