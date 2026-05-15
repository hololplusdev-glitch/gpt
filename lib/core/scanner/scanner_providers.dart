// core/scanner/scanner_providers.dart
// WHY: Riverpod wiring for the barcode scanner subsystem.
// Follows the same pattern as other service providers in core_providers.dart.
// Kept in a separate file to isolate the scanner dependency graph.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/scanner/barcode_scanner_service.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';

/// Whether the current platform supports camera-based barcode scanning.
///
/// WHY: Camera scanner is only viable on Android/iOS (native ML Kit / Vision).
/// Desktop (Windows/Linux/macOS) uses USB barcode scanners that act as
/// keyboard-wedge devices — they type directly into the search field.
/// Web could theoretically use the camera, but the UX is suboptimal for POS.
final hasCameraScannerProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
});

/// Service that processes barcodes from any source (camera or keyboard-wedge).
///
/// WHY: Single provider ensures DRY — both the camera overlay and the
/// keyboard-wedge handler feed into the SAME service with the SAME
/// debounce and lookup pipeline.
final barcodeScannerServiceProvider = Provider<BarcodeScannerService>((ref) {
  final session = ref.watch(activePosSessionProvider).valueOrNull;
  final context = PosRuntimeContextRules.requireActiveContext(
    session,
    message: 'Select a cashier and POS machine before scanning.',
    code: 'NO_ACTIVE_POS_SESSION',
  );

  return BarcodeScannerService(
    catalogDao: ref.watch(catalogDaoProvider),
    priceLevelId: context.priceLevelId,
    storeId: context.storeId,
    clock: ref.watch(clockProvider),
  );
});
