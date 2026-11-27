# Hardening Existing Flutter Projects (Architecture & SDK Compatibility)

The reference starter (`templates/starter_app/`) uses Flutter ≥ 3.47, `package:material_ui/material_ui.dart`, Riverpod 3 and `go_router` — **for brand-new apps only**.

When hardening an **existing** Flutter app, **never rewrite its state management, router, or Material import style**. Adapt the core production patterns to the stack the project already uses.

---

## 1. Material Import & Flutter Version Compatibility

| Project's Flutter SDK | What to import | When copying helpers from `templates/starter_app/lib/core/` |
|---|---|---|
| **Flutter < 3.47** (or any existing app still on classic Material) | Keep `package:flutter/material.dart` | Replace `import 'package:material_ui/material_ui.dart';` with `import 'package:flutter/material.dart';` in copied files — all widget APIs (`Scaffold`, `SafeArea`, `ThemeData`, `TextScaler`) are identical |
| **Flutter ≥ 3.47** (new app or explicit migration) | `package:material_ui/material_ui.dart` | Use as-is (`dart fix --apply` migrates existing files only if the user asks) |

Never add `material_ui` or raise `environment.sdk` / `environment.flutter` in `pubspec.yaml` without asking the user.

---

## 2. Adapting Error Handling & Four UI States to Any State Layer

The pure-Dart pieces in `templates/starter_app/lib/core/` (`errors/app_failure.dart`, `errors/failure_mapper.dart`, `logging/`, `network/`, `security/`, `responsive/`) have **zero Riverpod dependency** — copy them directly into `lib/core/` (or `packages/core/lib/` in a Melos / pub workspace monorepo) and wire them into the project's existing state layer.

### A. `flutter_bloc` / `Cubit`

1. **Global observer in `bootstrap()`:**
   ```dart
   final class AppBlocObserver extends BlocObserver {
     AppBlocObserver(this._logger);
     final AppLogger _logger;

     @override
     void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
       _logger.error('Bloc failed: ${bloc.runtimeType}', error, stackTrace);
       super.onError(bloc, error, stackTrace);
     }
   }
   // In bootstrap(): Bloc.observer = AppBlocObserver(logger);
   ```
2. **Typed failure state (keeps previous items on refresh/pagination error):**
   ```dart
   sealed class OrdersState { const OrdersState(); }
   final class OrdersLoading extends OrdersState { const OrdersLoading(); }
   final class OrdersLoaded extends OrdersState {
     const OrdersLoaded(this.items, {this.refreshError});
     final List<Order> items;
     final AppFailure? refreshError; // non-null keeps loaded list visible
   }
   final class OrdersFailure extends OrdersState {
     const OrdersFailure(this.failure);
     final AppFailure failure;
   }
   ```
3. **Four-state UI + localized message:**
   ```dart
   BlocBuilder<OrdersCubit, OrdersState>(
     builder: (context, state) => switch (state) {
       OrdersLoading() => const Center(child: CircularProgressIndicator()),
       OrdersFailure(:final failure) => ErrorStateView(
         message: l10n.failureMessage(failure),
         onRetry: failure.isRetryable ? context.read<OrdersCubit>().load : null,
       ),
       OrdersLoaded(:final items) when items.isEmpty => const EmptyStateView(),
       OrdersLoaded(:final items) => OrdersList(items: items),
     },
   )
   ```
4. **Actions started from menus / dialogs (`NAVIGATION-AND-LIFECYCLE.md` §3):**
   Capture the cubit/bloc **before** `await showDialog(...)`:
   ```dart
   final authCubit = context.read<AuthCubit>(); // before the menu/dialog closes
   final confirmed = await showDialog<bool>(...);
   if (confirmed == true) await authCubit.deleteAccount();
   ```

### B. `provider` / `ChangeNotifier` / `ValueNotifier`

- Expose `bool isLoading`, `AppFailure? failure`, and `List<T> items` on the `ChangeNotifier` (do **not** clear `items` when a pull-to-refresh fails).
- Wrap repository calls in `guardFailures(() => ...)` and store the caught `AppFailure` instead of `e.toString()`.
- In `test/responsive_test.dart`, wrap the app with `MultiProvider` supplying fake repositories instead of `ProviderScope`.

### C. Existing Routers (`auto_route`, `Navigator` 1.0/2.0, `GetX`)

- **`auto_route`:** Validate path/query parameters inside route guards or screen constructors using `InputValidators`; test nested tab back-navigation with `AutoTabsScaffold` + `tester.binding.handlePopRoute()`.
- **Imperative `Navigator`:** Keep a root `GlobalKey<NavigatorState>` for session-expiry redirects (`onSessionExpired`), and ensure nested tab `Navigator`s wrap the root in a `PopScope` that pops the inner `Navigator` before closing the app.

---

## 3. Monorepo & Multi-Package Workspaces (`packages/*`)

- The audit scripts (`project_report.dart`, `check_forbidden.dart`) automatically scan Dart `workspace:` packages and local `packages/*` / `modules/*` folders alongside root `lib/` and `test/`.
- Shared custom widgets (e.g., `AppText`, `AppLoadingSkeleton`, `AppFailureView` in `packages/design_system/`) are discovered automatically by the structural scanner so feature screens using them are not falsely flagged.
