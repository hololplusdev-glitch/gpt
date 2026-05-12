// core/services/pos_devices/printer_adapter_factory.dart
// WHY: Maps PrinterProfile → concrete PrinterAdapter based on connectionType
// and driverType. Also provides platform-aware connection options list for UI.

import 'package:holol_POS/core/adapters/network_escpos_printer_adapter.dart';
import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/adapters/system_printer_adapter.dart';
import 'package:holol_POS/core/adapters/unsupported_printer_adapter.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';

class PrinterConnectionOption {
  final PrinterConnectionType type;
  final bool available;
  final String label;
  final String? reason;

  const PrinterConnectionOption({
    required this.type,
    required this.available,
    required this.label,
    this.reason,
  });
}

class PrinterAdapterFactory {
  final AppPlatform platform;

  const PrinterAdapterFactory({required this.platform});

  static const _bluetoothReason =
      'Bluetooth ESC/POS printing requires a Bluetooth Classic adapter with Android permissions. Not implemented in this build.';

  /// Returns the correct adapter for the given profile's connection/driver.
  PrinterAdapter forProfile(PrinterProfile profile) {
    final ct = profile.connectionType;
    final dt = profile.driverType;

    // Network/IP ESC-POS — implemented on all platforms.
    if (ct == PrinterConnectionType.networkIp.code &&
        dt == PrinterDriverType.escpos.code) {
      return const NetworkEscPosPrinterAdapter();
    }

    if (ct == PrinterConnectionType.systemPrinter.code &&
        dt == PrinterDriverType.systemPrinter.code) {
      return const SystemPrinterAdapter();
    }

    // Bluetooth ESC-POS — unsupported until a real Bluetooth adapter exists.
    if (ct == PrinterConnectionType.bluetooth.code &&
        dt == PrinterDriverType.escpos.code) {
      return const UnsupportedPrinterAdapter(_bluetoothReason);
    }

    return UnsupportedPrinterAdapter(
      '$ct / $dt is not implemented on ${platform.name}.',
    );
  }

  /// Platform-aware connection options for the Add Printer UI.
  /// Only shows options relevant to the current platform.
  /// [available] indicates whether the adapter is actually implemented.
  List<PrinterConnectionOption> connectionOptions() {
    final options = <PrinterConnectionOption>[
      // Network/IP — available on all platforms.
      const PrinterConnectionOption(
        type: PrinterConnectionType.networkIp,
        available: true,
        label: 'Network/IP ESC-POS',
      ),
    ];

    if (platform == AppPlatform.windows ||
        platform == AppPlatform.macos ||
        platform == AppPlatform.linux) {
      options.addAll(const [
        PrinterConnectionOption(
          type: PrinterConnectionType.systemPrinter,
          available: true,
          label: 'System Printer',
        ),
        PrinterConnectionOption(
          type: PrinterConnectionType.bluetooth,
          available: false,
          label: 'Bluetooth ESC-POS',
          reason: _bluetoothReason,
        ),
      ]);
    } else if (platform == AppPlatform.android) {
      options.addAll(const [
        PrinterConnectionOption(
          type: PrinterConnectionType.bluetooth,
          available: false,
          label: 'Bluetooth ESC-POS',
          reason: _bluetoothReason,
        ),
      ]);
    }

    return options;
  }
}
