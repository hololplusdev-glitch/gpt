import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/scanner/barcode_scanner_service.dart';
import 'package:holol_POS/core/scanner/scanner_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';

bool _barcodeScannerSheetOpen = false;
Future<void> _barcodeScannerReleaseFuture = Future<void>.value();

Future<void> showBarcodeScannerSheet(BuildContext context) async {
  if (_barcodeScannerSheetOpen) return;

  // CameraX on some Android/MIUI devices needs a moment to fully release.
  // Do not open a new scanner session until the previous one is released.
  try {
    await _barcodeScannerReleaseFuture.timeout(const Duration(seconds: 2));
  } catch (_) {
    // Do not block forever on device-specific CameraX release issues.
  }

  if (!context.mounted || _barcodeScannerSheetOpen) return;

  _barcodeScannerSheetOpen = true;

  final releaseCompleter = Completer<void>();

  void completeRelease() {
    if (!releaseCompleter.isCompleted) {
      releaseCompleter.complete();
    }
  }

  _barcodeScannerReleaseFuture = releaseCompleter.future;

  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _BarcodeScannerSheet(onCameraReleased: completeRelease),
    );
  } finally {
    _barcodeScannerSheetOpen = false;

    try {
      await releaseCompleter.future.timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      completeRelease();
    }
  }
}

class _BarcodeScannerSheet extends ConsumerStatefulWidget {
  final VoidCallback onCameraReleased;

  const _BarcodeScannerSheet({required this.onCameraReleased});

  @override
  ConsumerState<_BarcodeScannerSheet> createState() =>
      _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<_BarcodeScannerSheet>
    with WidgetsBindingObserver {
  late final MobileScannerController _cameraController;
  late final BarcodeScannerService _scannerService;
  late final CartController _cartNotifier;

  final _processingCodes = <String>{};

  _ScanFeedback? _feedback;
  Timer? _feedbackTimer;

  int _sessionScanCount = 0;
  int _lifecycleToken = 0;

  String? _lastResolvedCode;
  DateTime? _lastResolvedAt;

  bool _isStartingCamera = false;
  bool _cameraStarted = false;
  bool _cameraVisible = true;
  bool _isClosing = false;
  bool _controllerDisposed = false;
  bool _allowPop = false;
  bool _permissionDenied = false;

  static const _sameVisibleCodeCooldown = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();

    _scannerService = ref.read(barcodeScannerServiceProvider);
    _cartNotifier = ref.read(cartProvider.notifier);

    WidgetsBinding.instance.addObserver(this);

    _cameraController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf14,
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAlive(_lifecycleToken)) {
        unawaited(_startCamera());
      }
    });
  }

  bool _isAlive(int token) {
    return mounted &&
        token == _lifecycleToken &&
        !_isClosing &&
        !_controllerDisposed;
  }

  Future<void> _startCamera() async {
    final token = _lifecycleToken;

    if (!_isAlive(token)) return;
    if (_cameraStarted || _isStartingCamera) return;

    _isStartingCamera = true;

    try {
      await _cameraController.start();

      if (!_isAlive(token)) return;

      setState(() {
        _cameraStarted = true;
        _permissionDenied = false;
      });
    } catch (error) {
      if (!_isAlive(token)) return;

      final message = error.toString().toLowerCase();

      if (message.contains('already running')) {
        if (!_isAlive(token)) return;

        setState(() {
          _cameraStarted = true;
          _permissionDenied = false;
        });
        return;
      }

      final denied =
          message.contains('permission') || message.contains('denied');

      if (!_isAlive(token)) return;

      setState(() {
        _cameraStarted = false;
        _permissionDenied = denied;
      });

      final l10n = AppLocalizations.of(context)!;
      _showFeedback(
        _ScanFeedback(
          message: denied
              ? l10n.cameraPermissionDenied
              : l10n.cameraStartFailed,
          isError: true,
        ),
      );
    } finally {
      if (token == _lifecycleToken) {
        _isStartingCamera = false;
      }
    }
  }

  Future<void> _stopCamera() async {
    if (_controllerDisposed) return;

    try {
      await _cameraController.stop();
    } catch (_) {
      // CameraX/device-specific stop failures are non-fatal.
    } finally {
      _cameraStarted = false;
      _isStartingCamera = false;
    }
  }

  Future<void> _disposeCameraController() async {
    if (_controllerDisposed) return;

    try {
      await _cameraController.stop();
    } catch (_) {
      // Best-effort stop.
    }

    try {
      await _cameraController.dispose();
    } catch (_) {
      // Best-effort dispose.
    } finally {
      _controllerDisposed = true;
    }
  }

  void _requestClose() {
    if (_isClosing) return;

    _lifecycleToken++;

    setState(() {
      _isClosing = true;
      _cameraVisible = false;
      _feedback = null;
      _allowPop = true;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = null;

    _processingCodes.clear();
    _lastResolvedCode = null;
    _lastResolvedAt = null;

    _scannerService.resetDebounce();

    // Remove MobileScanner from the tree first, then pop the sheet.
    // Camera release happens in dispose and is gated before the next open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isClosing || _controllerDisposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_cameraVisible) {
          unawaited(_startCamera());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_stopCamera());
      case AppLifecycleState.detached:
        break;
    }
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (_isClosing || _controllerDisposed) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;

      final code = rawValue.trim();

      if (_shouldIgnoreVisibleDuplicate(code)) {
        continue;
      }

      if (!_processingCodes.add(code)) {
        continue;
      }

      unawaited(_processCode(code, _lifecycleToken));
      break;
    }
  }

  bool _shouldIgnoreVisibleDuplicate(String code) {
    final lastCode = _lastResolvedCode;
    final lastAt = _lastResolvedAt;

    if (lastCode != code || lastAt == null) {
      return false;
    }

    return DateTime.now().difference(lastAt) < _sameVisibleCodeCooldown;
  }

  void _markResolved(String code) {
    _lastResolvedCode = code;
    _lastResolvedAt = DateTime.now();
  }

  Future<void> _processCode(String code, int token) async {
    try {
      if (!_isAlive(token)) return;

      final result = await _scannerService.processBarcode(
        code,
        source: BarcodeScanSource.camera,
      );

      if (!_isAlive(token)) return;

      switch (result) {
        case ScanSuccess():
          final newQuantity = await _cartNotifier.addSellableItem(result.item);

          if (!_isAlive(token)) return;

          final l10n = AppLocalizations.of(context)!;

          _markResolved(code);
          _sessionScanCount++;

          _playFeedback(success: true);
          _showFeedback(
            _ScanFeedback(
              message: newQuantity > 1
                  ? l10n.scanAddedItemQuantity(newQuantity.round())
                  : l10n.scanAddedItem,
              isError: false,
            ),
          );

        case ScanNotFound():
          _markResolved(code);
          _playFeedback(success: false);
          _showFeedback(
            _ScanFeedback(
              message: AppLocalizations.of(context)!.barcodeNotFoundCatalog,
              isError: true,
            ),
          );

        case ScanNoPrice():
          _markResolved(code);
          _playFeedback(success: false);
          _showFeedback(
            _ScanFeedback(
              message: AppLocalizations.of(context)!.scanNoPriceCurrentStore,
              isError: true,
            ),
          );

        case ScanError():
          _markResolved(code);
          _playFeedback(success: false);
          _showFeedback(_ScanFeedback(message: result.message, isError: true));

        case ScanDuplicate():
          _markResolved(code);
          break;
      }
    } finally {
      _processingCodes.remove(code);
    }
  }

  void _playFeedback({required bool success}) {
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

  void _showFeedback(_ScanFeedback feedback) {
    final token = _lifecycleToken;

    if (!_isAlive(token)) return;

    _feedbackTimer?.cancel();

    setState(() => _feedback = feedback);

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_isAlive(token) && identical(_feedback, feedback)) {
        setState(() => _feedback = null);
      }
    });
  }

  void _toggleTorch() {
    if (_isClosing || _controllerDisposed || !_cameraVisible) return;

    unawaited(
      _cameraController.toggleTorch().catchError((_) {
        // Torch support varies by device.
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _lifecycleToken++;
    _isClosing = true;
    _cameraVisible = false;

    _feedbackTimer?.cancel();
    _feedbackTimer = null;

    _processingCodes.clear();
    _lastResolvedCode = null;
    _lastResolvedAt = null;

    _scannerService.resetDebounce();

    unawaited(_disposeCameraController().whenComplete(widget.onCameraReleased));

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestClose();
      },
      child: Container(
        height: screenHeight * 0.55,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const _DragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.scanBarcode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _TorchButton(
                    controller: _cameraController,
                    enabled:
                        !_isClosing && !_controllerDisposed && _cameraVisible,
                    onPressed: _toggleTorch,
                    tooltip: l10n.toggleFlash,
                  ),
                  IconButton(
                    icon: _isClosing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close),
                    onPressed: _isClosing ? null : _requestClose,
                    tooltip: l10n.closeScanner,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: AppSpacing.borderRadiusMd,
                child: _buildScannerBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _sessionScanCount == 0
                    ? l10n.pointCameraBarcode
                    : l10n.scannedItemsCount(_sessionScanCount),
                style: TextStyle(
                  color: _sessionScanCount > 0
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerBody() {
    if (_permissionDenied) {
      return const _PermissionDeniedState();
    }

    if (_isClosing || _controllerDisposed || !_cameraVisible) {
      return const _ScannerClosingState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scanWindow = _scanWindowFor(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return Stack(
          children: [
            MobileScanner(
              controller: _cameraController,
              scanWindow: scanWindow,
              onDetect: _handleBarcodeDetection,
            ),
            _ScanWindowOverlay(scanWindow: scanWindow),
            if (_feedback != null)
              Positioned(
                bottom: AppSpacing.xl,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _FeedbackToast(feedback: _feedback!),
              ),
          ],
        );
      },
    );
  }

  Rect _scanWindowFor(Size size) {
    final windowWidth = size.width * 0.7;
    final windowHeight = windowWidth * 0.45;

    return Rect.fromLTWH(
      (size.width - windowWidth) / 2,
      (size.height - windowHeight) / 2,
      windowWidth,
      windowHeight,
    );
  }
}

class _TorchButton extends StatelessWidget {
  final MobileScannerController controller;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;

  const _TorchButton({
    required this.controller,
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return IconButton(
        tooltip: tooltip,
        onPressed: null,
        icon: const Icon(Icons.flash_off, color: AppColors.textSecondary),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: ValueListenableBuilder<MobileScannerState>(
        valueListenable: controller,
        builder: (_, state, __) {
          return Icon(
            state.torchState == TorchState.on
                ? Icons.flash_on
                : Icons.flash_off,
            color: state.torchState == TorchState.on
                ? AppColors.warning
                : AppColors.textSecondary,
          );
        },
      ),
    );
  }
}

class _ScannerClosingState extends StatelessWidget {
  const _ScannerClosingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _PermissionDeniedState extends StatelessWidget {
  const _PermissionDeniedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: AppSpacing.paddingLg,
      child: Text(
        AppLocalizations.of(context)!.cameraPermissionDenied,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ScanWindowOverlay extends StatelessWidget {
  final Rect scanWindow;

  const _ScanWindowOverlay({required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned.fromRect(
                rect: scanWindow,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fromRect(
          rect: scanWindow,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.7),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanFeedback {
  final String message;
  final bool isError;

  const _ScanFeedback({required this.message, required this.isError});
}

class _FeedbackToast extends StatelessWidget {
  final _ScanFeedback feedback;

  const _FeedbackToast({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: feedback.isError
              ? AppColors.error.withValues(alpha: 0.9)
              : AppColors.success.withValues(alpha: 0.9),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Text(
          feedback.message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
