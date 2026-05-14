import 'package:flutter/services.dart';
import 'package:holol_POS/core/scanner/barcode_scanner_service.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';

enum PosScanFlowOutcome {
  added,
  manualSearch,
  notFound,
  noPrice,
  error,
  duplicate,
}

class PosScanFlowResult {
  final PosScanFlowOutcome outcome;
  final AddToCartResult? cartResult;
  final String? scannedCode;
  final String? productName;
  final String? errorMessage;

  const PosScanFlowResult._({
    required this.outcome,
    this.cartResult,
    this.scannedCode,
    this.productName,
    this.errorMessage,
  });

  const PosScanFlowResult.added(AddToCartResult result)
    : this._(outcome: PosScanFlowOutcome.added, cartResult: result);

  const PosScanFlowResult.manualSearch(String scannedCode)
    : this._(
        outcome: PosScanFlowOutcome.manualSearch,
        scannedCode: scannedCode,
      );

  const PosScanFlowResult.notFound(String scannedCode)
    : this._(outcome: PosScanFlowOutcome.notFound, scannedCode: scannedCode);

  const PosScanFlowResult.noPrice(String productName)
    : this._(outcome: PosScanFlowOutcome.noPrice, productName: productName);

  const PosScanFlowResult.error(String message)
    : this._(outcome: PosScanFlowOutcome.error, errorMessage: message);

  const PosScanFlowResult.duplicate()
    : this._(outcome: PosScanFlowOutcome.duplicate);
}

abstract final class PosScanFeedbackPlayer {
  static void play({required bool success}) {
    try {
      SystemSound.play(success ? SystemSoundType.click : SystemSoundType.alert);
      if (success) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Feedback is non-critical.
    }
  }
}

abstract final class PosScanFlow {
  static Future<PosScanFlowResult> processKeyboard({
    required String rawCode,
    required BarcodeScannerService scannerService,
    required CartController cartController,
    required bool manualSearchFallback,
  }) {
    return _process(
      rawCode: rawCode,
      scannerService: scannerService,
      cartController: cartController,
      source: BarcodeScanSource.keyboard,
      manualSearchFallback: manualSearchFallback,
    );
  }

  static Future<PosScanFlowResult> processCamera({
    required String rawCode,
    required BarcodeScannerService scannerService,
    required CartController cartController,
  }) {
    return _process(
      rawCode: rawCode,
      scannerService: scannerService,
      cartController: cartController,
      source: BarcodeScanSource.camera,
      manualSearchFallback: false,
    );
  }

  static Future<PosScanFlowResult> _process({
    required String rawCode,
    required BarcodeScannerService scannerService,
    required CartController cartController,
    required BarcodeScanSource source,
    required bool manualSearchFallback,
  }) async {
    final input = rawCode.trim();
    if (input.isEmpty) return const PosScanFlowResult.duplicate();

    final scanResult = await scannerService.processBarcode(
      input,
      source: source,
    );

    switch (scanResult) {
      case ScanSuccess():
        final addResult = await cartController.addSellableItem(scanResult.item);
        return PosScanFlowResult.added(addResult);

      case ScanNotFound():
        return manualSearchFallback
            ? PosScanFlowResult.manualSearch(input)
            : PosScanFlowResult.notFound(scanResult.scannedCode);

      case ScanNoPrice():
        return PosScanFlowResult.noPrice(scanResult.productName);

      case ScanError():
        return PosScanFlowResult.error(scanResult.message);

      case ScanDuplicate():
        return const PosScanFlowResult.duplicate();
    }
  }
}
