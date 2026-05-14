class ReceiptRenderProfile {
  final int paperWidthMm;
  final int widthPx;
  final double margin;
  final double gap;
  final double font;
  final double smallFont;
  final double titleFont;
  final double totalFont;
  final int rasterBandHeight;

  const ReceiptRenderProfile._({
    required this.paperWidthMm,
    required this.widthPx,
    required this.margin,
    required this.gap,
    required this.font,
    required this.smallFont,
    required this.titleFont,
    required this.totalFont,
    required this.rasterBandHeight,
  });

  factory ReceiptRenderProfile.thermal({required int paperWidthMm}) {
    final is58 = paperWidthMm <= 58;
    return ReceiptRenderProfile._(
      paperWidthMm: is58 ? 58 : 80,
      widthPx: is58 ? 384 : 576,
      margin: is58 ? 12 : 18,
      gap: is58 ? 8 : 10,
      font: is58 ? 15 : 18,
      smallFont: is58 ? 12.5 : 15,
      titleFont: is58 ? 19 : 24,
      totalFont: is58 ? 18 : 23,
      rasterBandHeight: 256,
    );
  }
}
