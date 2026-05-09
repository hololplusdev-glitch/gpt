// core/scanner/barcode_scanner_service.dart
// WHY: Centralizes barcode lookup and pricing. Decouples scanning hardware
// (camera/USB) from cashier-specific cart mutation. This service is
// the single source of truth for "what happens when a barcode is scanned".
//
// Design decisions:
//   1. Per-code debounce: cameras read 30+ fps — same barcode in consecutive
//      frames must be deduplicated. But DIFFERENT barcodes pass immediately.
//   2. Platform-agnostic: works with camera scanner (mobile) AND keyboard-wedge
//      USB scanners (Windows desktop). Both feed the same processBarcode().
//   3. Stateless lookup: does not cache items — delegates to CatalogDao which
//      queries the local SQLite cache (offline-first).

import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/sellable_item_snapshot.dart';

/// Outcome of processing a scanned barcode.
sealed class ScanResult {
  const ScanResult();
}

/// Barcode matched a product and resolved a sellable item snapshot.
class ScanSuccess extends ScanResult {
  final SellableItemSnapshot item;

  const ScanSuccess({required this.item});
}

/// Barcode was not found in local catalog.
class ScanNotFound extends ScanResult {
  final String scannedCode;
  const ScanNotFound(this.scannedCode);
}

/// Product found but no sellable price configured.
class ScanNoPrice extends ScanResult {
  final String productName;
  const ScanNoPrice(this.productName);
}

/// Duplicate scan within debounce window — silently ignored.
class ScanDuplicate extends ScanResult {
  const ScanDuplicate();
}

/// Scan failed due to an unexpected error.
class ScanError extends ScanResult {
  final String message;
  const ScanError(this.message);
}

enum BarcodeScanSource { camera, keyboard }

/// Processes barcodes from any source (camera, USB) into sellable item snapshots.
///
/// This is intentionally NOT a Riverpod notifier — it's a pure service
/// injected via a Provider, keeping it testable and platform-agnostic.
class BarcodeScannerService {
  final CatalogDao _catalogDao;
  final String _priceLevelId;
  final String _storeId;
  final Clock _clock;

  // WHY: Per-code debounce state. We track the LAST scanned code and
  // its timestamp. Same code within _debounceDuration is ignored.
  // Different code resets the timer immediately.
  String? _lastCode;
  DateTime? _lastScanTime;

  /// Duration to suppress duplicate reads of the SAME barcode.
  /// 800ms balances between:
  ///   - Fast enough: cashier scanning different items rapidly
  ///   - Slow enough: prevents camera multi-frame duplicates (~33ms/frame)
  static const _sameCodeDebounce = Duration(milliseconds: 800);

  BarcodeScannerService({
    required CatalogDao catalogDao,
    required String priceLevelId,
    required String storeId,
    Clock clock = const SystemClock(),
  }) : _catalogDao = catalogDao,
       _priceLevelId = priceLevelId,
       _storeId = storeId,
       _clock = clock;

  /// Process a detected barcode code string.
  ///
  /// Pipeline: debounce → lookup → resolve price → return snapshot
  ///
  /// Returns a [ScanResult] for UI feedback (beep, vibration, toast).
  Future<ScanResult> processBarcode(
    String rawCode, {
    BarcodeScanSource source = BarcodeScanSource.camera,
  }) async {
    final candidates = CatalogDao.barcodeLookupCandidates(rawCode);
    final code = candidates.isEmpty ? '' : candidates.first;
    if (code.isEmpty) return const ScanDuplicate();

    // ── Step 1: Smart debounce ──
    final now = _clock.now();
    if (source == BarcodeScanSource.camera &&
        code == _lastCode &&
        _lastScanTime != null) {
      if (now.difference(_lastScanTime!) < _sameCodeDebounce) {
        // WHY: Same barcode within debounce window — camera read it twice.
        return const ScanDuplicate();
      }
    }
    if (source == BarcodeScanSource.camera) {
      _lastCode = code;
      _lastScanTime = now;
    }

    try {
      // ── Step 2: Lookup in local DB ──
      final lookup = await _catalogDao.lookupBarcode(
        rawCode,
        _storeId,
        _priceLevelId,
      );
      if (lookup == null) {
        return ScanNotFound(code);
      }

      final item = lookup.item;
      final unit = lookup.unit;
      // WHY: Resolve unit ID early: prefer source unit, then item default.
      // If neither exists, we can't price the item.
      final unitId = lookup.sourceUnitId ?? item.defaultUnitId;
      if (unitId == null) {
        return ScanNoPrice(item.name);
      }

      // ── Step 3: Resolve price ──
      final price = await _catalogDao.resolveItemPrice(
        itemId: item.id,
        priceLevelId: _priceLevelId,
        storeId: _storeId,
        unitId: unitId,
      );

      if (price == null) {
        return ScanNoPrice(item.name);
      }

      // ── Step 4: Return resolved sale item snapshot ──

      return ScanSuccess(
        item: _catalogDao.toSellableItemSnapshot(
          item: item,
          price: price,
          fallbackUnitId: unitId,
          fallbackUnitName: unit?.name,
          barcode: lookup.barcode.barcode,
        ),
      );
    } on DuplicateCatalogBarcodeException {
      return const ScanError('الباركود مكرر في الكتالوج');
    } catch (e) {
      return const ScanError('تعذر معالجة الباركود.');
    }
  }

  /// Reset debounce state. Call when scanner session restarts.
  void resetDebounce() {
    _lastCode = null;
    _lastScanTime = null;
  }
}
