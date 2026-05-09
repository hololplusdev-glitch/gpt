// app/app.dart
// WHY: Root MaterialApp.router with theme, localization, and router integration.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/theme.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/features/setup/application/setup_notifier.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

final _installationLog = Logger('AppInstallation');

class PosApp extends ConsumerStatefulWidget {
  const PosApp({super.key});

  @override
  ConsumerState<PosApp> createState() => _PosAppState();
}

class _PosAppState extends ConsumerState<PosApp> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref.read(appInstallationServiceProvider).ensureInitialized(),
      ).catchError((Object error, StackTrace stackTrace) {
        _installationLog.warning(
          'Failed to initialize app installation record.',
          error,
          stackTrace,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final language = ref.watch(setupProvider).valueOrNull?.language;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: language == null ? null : Locale(language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
    );
  }
}
