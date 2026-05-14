import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';

class ReceiptRenderProfile {
  final int paperWidthMm;
  final int widthPx;
  final double margin;
  final double leftMargin;
  final double rightMargin;
  final double gap;
  final double font;
  final double smallFont;
  final double titleFont;
  final double totalFont;
  final int rasterBandHeight;
  final int rasterThreshold;

  const ReceiptRenderProfile._({
    required this.paperWidthMm,
    required this.widthPx,
    required this.margin,
    required this.leftMargin,
    required this.rightMargin,
    required this.gap,
    required this.font,
    required this.smallFont,
    required this.titleFont,
    required this.totalFont,
    required this.rasterBandHeight,
    required this.rasterThreshold,
  });

  factory ReceiptRenderProfile.thermal({
    required int paperWidthMm,
    int? printableWidthDots,
    int? leftMarginDots,
    int? rightMarginDots,
    double fontScale = 1.0,
    int? rasterThreshold,
  }) {
    final is58 = paperWidthMm <= 58;
    final effectiveScale = fontScale <= 0 ? 1.0 : fontScale;

    final width = printableWidthDots ?? (is58 ? 360 : 512);
    final left = (leftMarginDots ?? (is58 ? 20 : 24)).toDouble();
    final right = (rightMarginDots ?? (is58 ? 28 : 32)).toDouble();

    return ReceiptRenderProfile._(
      paperWidthMm: is58 ? 58 : 80,
      widthPx: width,
      margin: is58 ? 20 : 24,
      leftMargin: left,
      rightMargin: right,
      gap: is58 ? 10 : 12,
      font: (is58 ? 18 : 21) * effectiveScale,
      smallFont: (is58 ? 16 : 18) * effectiveScale,
      titleFont: (is58 ? 23 : 28) * effectiveScale,
      totalFont: (is58 ? 25 : 30) * effectiveScale,
      rasterBandHeight: 256,
      rasterThreshold: rasterThreshold ?? 220,
    );
  }

  factory ReceiptRenderProfile.fromPrinterProfile(PrinterProfile profile) {
    return ReceiptRenderProfile.thermal(
      paperWidthMm: profile.paperWidthMm,
      printableWidthDots: profile.printableWidthDots,
      leftMarginDots: profile.leftMarginDots,
      rightMarginDots: profile.rightMarginDots,
      fontScale: profile.fontScale,
      rasterThreshold: profile.rasterThreshold,
    );
  }
}
