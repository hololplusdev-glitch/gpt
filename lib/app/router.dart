// app/router.dart
// WHY: GoRouter with setup guard → auth guard → shift guard.
// Enforces: first-run setup → login → open shift → cashier.
import 'package:pos_flutter/features/owner_console/owner_console_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/features/auth/presentation/login_screen.dart';
import 'package:pos_flutter/features/cashier/presentation/cashier_screen.dart';
import 'package:pos_flutter/features/history/presentation/history_screen.dart';
import 'package:pos_flutter/features/invoices/presentation/invoice_preview_screen.dart';
import 'package:pos_flutter/features/pos_devices/presentation/pos_devices_screen.dart';
import 'package:pos_flutter/features/settings/presentation/settings_screen.dart';
import 'package:pos_flutter/features/setup/application/setup_notifier.dart';
import 'package:pos_flutter/features/setup/presentation/setup_screen.dart';
import 'package:pos_flutter/features/shift/application/shift_notifier.dart';
import 'package:pos_flutter/features/shift/presentation/shift_screen.dart';
import 'package:pos_flutter/features/sync/presentation/sync_monitor_screen.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String boot = '/boot';
  static const String setup = '/setup';
  static const String login = '/login';
  static const String shift = '/shift';
  static const String cashier = '/';
  static const String history = '/history';
  static const String invoice = '/invoice/:saleId';
  static const String settings = '/settings';
  static const String posDevices = '/pos-devices';
  static const String syncMonitor = '/sync';
  static const String ownerConsole = '/owner-console';

  static String invoicePath(String saleId) => '/invoice/$saleId';
}

/// Notifies GoRouter that redirect state changed without rebuilding GoRouter.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// GoRouter provider — keeps one router instance and refreshes redirects only.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier();

  ref
    ..onDispose(refreshNotifier.dispose)
    ..listen(setupProvider, (_, __) => refreshNotifier.refresh())
    ..listen(shiftProvider, (_, __) => refreshNotifier.refresh())
    ..listen(posConfigRevisionProvider, (_, __) => refreshNotifier.refresh())
    ..listen(activePosSessionProvider, (_, __) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: AppRoutes.boot,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final setupAsync = ref.read(setupProvider);
      final isSetupComplete = setupAsync.valueOrNull?.isSetupComplete ?? false;
      final shiftState = ref.read(shiftProvider);
      final useShift = ref.read(posConfigProvider).useShift;

      final isAuthenticated =
          ref.read(activePosSessionProvider).valueOrNull != null;
      final isBootRoute = state.matchedLocation == AppRoutes.boot;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isSetupRoute = state.matchedLocation == AppRoutes.setup;
      final isOwnerConsoleRoute =
          state.matchedLocation == AppRoutes.ownerConsole;

      if (setupAsync.hasError) {
        return isSetupRoute ? null : AppRoutes.setup;
      }

      if (!setupAsync.hasValue) {
        return isBootRoute ? null : AppRoutes.boot;
      }

      if (isBootRoute) {
        final target = !isSetupComplete
            ? AppRoutes.setup
            : !isAuthenticated
            ? AppRoutes.login
            : useShift && !shiftState.hasOpenShift
            ? AppRoutes.shift
            : AppRoutes.cashier;
        return target;
      }

      if (isOwnerConsoleRoute) {
        return null;
      }

      if (!isSetupComplete && !isSetupRoute) {
        return AppRoutes.setup;
      }

      if (isSetupComplete &&
          !isAuthenticated &&
          !isLoginRoute &&
          !isSetupRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isLoginRoute) {
        final target = !useShift || shiftState.hasOpenShift
            ? AppRoutes.cashier
            : AppRoutes.shift;
        return target;
      }

      if (isSetupComplete && isSetupRoute) {
        return AppRoutes.login;
      }

      final shiftExemptRoutes = {
        AppRoutes.boot,
        AppRoutes.shift,
        AppRoutes.login,
        AppRoutes.setup,
        AppRoutes.settings,
        AppRoutes.posDevices,
        AppRoutes.syncMonitor,
        AppRoutes.invoice,
      };
      if (isAuthenticated &&
          useShift &&
          !shiftState.hasOpenShift &&
          !shiftExemptRoutes.contains(state.matchedLocation)) {
        return AppRoutes.shift;
      }

      // WHY: Guard 6 — Readiness gate. Prevent selling when the local
      // catalog is incomplete. This catches the case where setup completed
      // with warnings or a re-sync is needed after Backend identity change.
      if (isAuthenticated && state.matchedLocation == AppRoutes.cashier) {
        final readiness = ref.read(catalogReadinessProvider).valueOrNull;
        if (readiness != null && !readiness.isReady) {
          return AppRoutes.syncMonitor;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.boot,
        builder: (context, state) => const _BootScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerConsole,
        builder: (context, state) => const OwnerConsoleScreen(),
      ),
      GoRoute(
        path: AppRoutes.shift,
        builder: (context, state) => const ShiftScreen(),
      ),
      GoRoute(
        path: AppRoutes.cashier,
        builder: (context, state) => const CashierScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoice,
        builder: (context, state) =>
            InvoicePreviewScreen(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.posDevices,
        builder: (context, state) => const PosDevicesScreen(),
      ),
      GoRoute(
        path: AppRoutes.syncMonitor,
        builder: (context, state) => const SyncMonitorScreen(),
      ),
    ],
  );
});

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: AppSpacing.paddingXl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppColors.primary,
                  size: AppSpacing.jumbo,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.bootingPos,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  minHeight: AppSpacing.xs,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
