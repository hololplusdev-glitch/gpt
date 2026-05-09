import 'package:printing/printing.dart';

class SystemPrinterInfo {
  final String url;
  final String name;
  final bool isDefault;
  final bool isAvailable;

  const SystemPrinterInfo({
    required this.url,
    required this.name,
    required this.isDefault,
    required this.isAvailable,
  });
}

class SystemPrinterDiscoveryService {
  const SystemPrinterDiscoveryService();

  Future<List<SystemPrinterInfo>> listPrinters() async {
    final info = await Printing.info();
    if (!info.canListPrinters) return const [];

    final printers = await Printing.listPrinters();
    final result = printers
        .map(
          (printer) => SystemPrinterInfo(
            url: printer.url,
            name: printer.name,
            isDefault: printer.isDefault,
            isAvailable: printer.isAvailable,
          ),
        )
        .toList();
    result.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return result;
  }
}
