import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfFontSet {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font? saudiRiyal;

  const InvoicePdfFontSet({
    required this.regular,
    required this.bold,
    this.saudiRiyal,
  });

  List<pw.Font> get fallback => [
    regular,
    if (bold != regular) bold,
    if (saudiRiyal != null) saudiRiyal!,
  ];

  pw.TextStyle style({double? fontSize, bool isBold = false, PdfColor? color}) {
    return pw.TextStyle(
      font: isBold ? bold : regular,
      fontFallback: fallback,
      fontSize: fontSize,
      color: color,
    );
  }
}

class InvoicePdfFonts {
  const InvoicePdfFonts._();

  static InvoicePdfFontSet? _cached;

  static const String regularAssetPath =
      'assets/fonts/NotoNaskhArabic-Regular.ttf';

  static const String boldAssetPath = 'assets/fonts/NotoNaskhArabic-Bold.ttf';

  static const String saudiRiyalAssetPath = 'assets/fonts/saudi-riyal.ttf';

  static Future<InvoicePdfFontSet> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final regular = await _loadRequiredFont(regularAssetPath);
    final bold = await _loadRequiredFont(boldAssetPath);
    final saudiRiyal = await _loadRequiredFont(saudiRiyalAssetPath);

    return _cached = InvoicePdfFontSet(
      regular: regular,
      bold: bold,
      saudiRiyal: saudiRiyal,
    );
  }

  static Future<pw.Font> _loadRequiredFont(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      return pw.Font.ttf(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'invoice_pdf_fonts',
          context: ErrorDescription('Failed to load required Arabic PDF font'),
          informationCollector: () sync* {
            yield ErrorDescription('Missing or unregistered asset: $assetPath');
            yield ErrorDescription(
              'Register the font asset in pubspec.yaml before generating PDFs.',
            );
          },
        ),
      );

      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Required Arabic PDF font could not be loaded.'),
        ErrorDescription('Asset path: $assetPath'),
        ErrorHint(
          'Add the font file to assets/fonts and register it in pubspec.yaml.',
        ),
      ]);
    }
  }
}
