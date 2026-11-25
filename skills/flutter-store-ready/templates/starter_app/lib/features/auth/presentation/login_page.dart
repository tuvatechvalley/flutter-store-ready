import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/security/input_validators.dart';
import 'auth_controller.dart';
import 'login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  Timer? _lockTicker;

  @override
  void dispose() {
    _lockTicker?.cancel();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (ref.read(loginControllerProvider).lockedUntil != null) {
      _startLockTicker();
    } else {
      // Don't keep the password in memory longer than needed.
      _password.clear();
    }
  }

  void _startLockTicker() {
    _lockTicker?.cancel();
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final left = ref
          .read(loginControllerProvider.notifier)
          .remainingLockSeconds();
      setState(() {});
      if (left == 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(loginControllerProvider);
    final lockSeconds = ref
        .read(loginControllerProvider.notifier)
        .remainingLockSeconds();
    final auth = ref.watch(authControllerProvider);
    final sessionExpired = auth is Unauthenticated && auth.sessionExpired;
    final busy = state.isSubmitting || lockSeconds > 0;

    String? errorText;
    if (lockSeconds > 0) {
      errorText = l10n.tooManyAttempts(lockSeconds);
    } else if (state.failure case final failure?) {
      errorText = failure is UnauthorizedFailure
          ? l10n.invalidCredentials
          : l10n.failureMessage(failure);
    } else if (sessionExpired) {
      errorText = l10n.sessionExpired;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          // Scrollable: keyboard + small phones + 200% font never overflow.
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(Insets.page(WindowSize.of(context))),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Insets.maxFormWidth),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_person_outlined,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        l10n.loginTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        l10n.loginSubtitle,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.xl),
                      TextFormField(
                        key: const Key('login.email'),
                        controller: _email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            InputValidators.maxEmailLength,
                          ),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const Icon(Icons.alternate_email),
                        ),
                        validator: (v) {
                          final e = InputValidators.email(v);
                          return e == null
                              ? null
                              : l10n.validationMessage(
                                  e,
                                  max: InputValidators.maxEmailLength,
                                );
                        },
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: Insets.md),
                      TextFormField(
                        key: const Key('login.password'),
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !busy,
                        obscureText: _obscure,
                        // Keep passwords out of keyboard learning/clipboard.
                        enableSuggestions: false,
                        autocorrect: false,
                        enableIMEPersonalizedLearning: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            InputValidators.maxPasswordLength,
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          prefixIcon: const Icon(Icons.password_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? l10n.showPassword
                                : l10n.hidePassword,
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          final e = InputValidators.password(v);
                          return e == null ? null : l10n.validationMessage(e);
                        },
                        onFieldSubmitted: (_) => unawaited(_submit()),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: Insets.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            errorText,
                            key: const Key('login.error'),
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: Insets.lg),
                      FilledButton(
                        key: const Key('login.submit'),
                        onPressed: busy ? null : () => unawaited(_submit()),
                        child: state.isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.signIn),
                      ),
                      if (ref.watch(envProvider).useMockApi) ...[
                        const SizedBox(height: Insets.md),
                        Text(
                          l10n.demoHint,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
