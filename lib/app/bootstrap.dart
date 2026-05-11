// app/bootstrap.dart
// WHY: Entry point that attaches Riverpod to the Flutter app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/app/app.dart';

/// Bootstraps the application and runs it inside a ProviderScope.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: PosApp()));
}
