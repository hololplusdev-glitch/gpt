import 'dart:io';

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/persistence/daos/printer_profile_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
export 'package:holol_POS/core/persistence/database.dart' show PrinterProfile;
import 'package:holol_POS/core/services/pos_devices/printer_adapter_factory.dart';
import 'package:holol_POS/core/services/pos_devices/system_printer_discovery_service.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

extension PrinterProfileSettings on PrinterProfile {
  Map<String, dynamic> get settings =>
      settingsJson != null ? jsonDecode(settingsJson!) : {};

  String? get ipAddress => settings['ipAddress'] as String?;
  int? get port => settings['port'] as int?;
  String? get systemPrinterName => settings['systemPrinterName'] as String?;
  String? get systemPrinterUrl => settings['systemPrinterUrl'] as String?;
  String? get bluetoothAddress => settings['bluetoothAddress'] as String?;
  int? get usbVendorId => settings['usbVendorId'] as int?;
  int? get usbProductId => settings['usbProductId'] as int?;
  String? get androidVendor => settings['androidVendor'] as String?;
}

class PrinterProfileService {
  final PrinterProfileDao _dao;
  final PrinterAdapterFactory _adapterFactory;
  final SystemPrinterDiscoveryService _systemPrinterDiscovery;
  final Clock _clock;

  static const _uuid = Uuid();

  const PrinterProfileService({
    required PrinterProfileDao dao,
    required PrinterAdapterFactory adapterFactory,
    SystemPrinterDiscoveryService systemPrinterDiscovery =
        const SystemPrinterDiscoveryService(),
    Clock clock = const SystemClock(),
  }) : _dao = dao,
       _adapterFactory = adapterFactory,
       _systemPrinterDiscovery = systemPrinterDiscovery,
       _clock = clock;

  Stream<List<PrinterProfile>> watchAll() => _dao.watchAll();

  Future<List<PrinterProfile>> getAll() => _dao.getAll();

  Future<PrinterProfile?> getActiveCashierPrinter() {
    return _dao.getActiveByRole(PrinterRole.cashier);
  }

  Future<PrinterProfile?> getActiveKitchenPrinter() {
    return _dao.getActiveByRole(PrinterRole.kitchen);
  }

  Future<List<SystemPrinterInfo>> listSystemPrinters() {
    return _systemPrinterDiscovery.listPrinters();
  }

  Future<void> saveNetworkPrinter({
    String? id,
    required String name,
    required PrinterRole role,
    required String ipAddress,
    required int port,
    required int paperWidthMm,
    required ArabicPrintMode arabicMode,
    required bool enabled,
    required bool autoPrint,
    required int copies,
    required bool isDefault,
    bool testPassed = false,
    DateTime? testedAt,
  }) async {
    _validateNetworkPrinter(
      name: name,
      ipAddress: ipAddress,
      port: port,
      paperWidthMm: paperWidthMm,
      arabicMode: arabicMode,
      copies: copies,
    );

    final now = _clock.now();
    final existing = id == null ? null : await _dao.getById(id);
    final unchangedFromReadyProfile =
        existing?.lastTestStatus == 'ready' &&
        existing?.role == role.code &&
        existing?.connectionType == PrinterConnectionType.networkIp.code &&
        existing?.driverType == PrinterDriverType.escpos.code &&
        existing?.ipAddress == ipAddress.trim() &&
        existing?.port == port &&
        existing?.paperWidthMm == paperWidthMm &&
        existing?.arabicMode == arabicMode.code;
    if (enabled && !testPassed && !unchangedFromReadyProfile) {
      throw StateError(
        'Run a successful test print before saving an enabled printer.',
      );
    }
    await _dao.upsertForRole(
      role: role,
      makeDefault: isDefault,
      profile: _networkPrinterCompanion(
        id: id ?? 'PRN_${_uuid.v4()}',
        name: name,
        role: role,
        enabled: enabled,
        ipAddress: ipAddress,
        port: port,
        paperWidthMm: paperWidthMm,
        arabicMode: arabicMode,
        autoPrint: autoPrint,
        copies: copies,
        isDefault: isDefault,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastTestStatus: testPassed
            ? 'ready'
            : enabled
            ? existing?.lastTestStatus
            : null,
        lastTestAt: testPassed
            ? testedAt ?? now
            : enabled
            ? existing?.lastTestAt
            : null,
        lastError: testPassed
            ? null
            : enabled
            ? existing?.lastError
            : null,
      ),
    );
  }

  Future<PrinterAdapterResult> testNetworkPrinter({
    required String name,
    required PrinterRole role,
    required String ipAddress,
    required int port,
    required int paperWidthMm,
    required ArabicPrintMode arabicMode,
    required bool enabled,
    required bool autoPrint,
    required int copies,
  }) async {
    _validateNetworkPrinter(
      name: name,
      ipAddress: ipAddress,
      port: port,
      paperWidthMm: paperWidthMm,
      arabicMode: arabicMode,
      copies: copies,
    );
    final now = _clock.now();
    final profile = PrinterProfile(
      id: 'TEMP_TEST',
      name: name.trim(),
      role: role.code,
      enabled: enabled,
      connectionType: PrinterConnectionType.networkIp.code,
      driverType: PrinterDriverType.escpos.code,
      settingsJson: jsonEncode({'ipAddress': ipAddress.trim(), 'port': port}),
      paperWidthMm: paperWidthMm,
      arabicMode: arabicMode.code,
      autoPrint: autoPrint,
      copies: copies,
      isDefault: true,
      lastTestStatus: null,
      lastTestAt: null,
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );
    return _adapterFactory.forProfile(profile).test(profile);
  }

  Future<void> saveSystemPrinter({
    String? id,
    required String name,
    required PrinterRole role,
    required String systemPrinterName,
    required String systemPrinterUrl,
    required int paperWidthMm,
    required bool enabled,
    required bool autoPrint,
    required int copies,
    required bool isDefault,
    bool testPassed = false,
    DateTime? testedAt,
  }) async {
    _validateSystemPrinter(
      name: name,
      systemPrinterName: systemPrinterName,
      systemPrinterUrl: systemPrinterUrl,
      paperWidthMm: paperWidthMm,
      copies: copies,
    );

    final now = _clock.now();
    final existing = id == null ? null : await _dao.getById(id);
    final unchangedFromReadyProfile =
        existing?.lastTestStatus == 'ready' &&
        existing?.role == role.code &&
        existing?.connectionType == PrinterConnectionType.systemPrinter.code &&
        existing?.driverType == PrinterDriverType.systemPrinter.code &&
        existing?.systemPrinterUrl == systemPrinterUrl.trim() &&
        existing?.systemPrinterName == systemPrinterName.trim() &&
        existing?.paperWidthMm == paperWidthMm;
    if (enabled && !testPassed && !unchangedFromReadyProfile) {
      throw StateError(
        'Run a successful test print before saving an enabled printer.',
      );
    }

    await _dao.upsertForRole(
      role: role,
      makeDefault: isDefault,
      profile: _systemPrinterCompanion(
        id: id ?? 'PRN_${_uuid.v4()}',
        name: name,
        role: role,
        enabled: enabled,
        systemPrinterName: systemPrinterName,
        systemPrinterUrl: systemPrinterUrl,
        paperWidthMm: paperWidthMm,
        autoPrint: autoPrint,
        copies: copies,
        isDefault: isDefault,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastTestStatus: testPassed
            ? 'ready'
            : enabled
            ? existing?.lastTestStatus
            : null,
        lastTestAt: testPassed
            ? testedAt ?? now
            : enabled
            ? existing?.lastTestAt
            : null,
        lastError: testPassed
            ? null
            : enabled
            ? existing?.lastError
            : null,
      ),
    );
  }

  Future<PrinterAdapterResult> testSystemPrinter({
    required String name,
    required PrinterRole role,
    required String systemPrinterName,
    required String systemPrinterUrl,
    required int paperWidthMm,
    required bool enabled,
    required bool autoPrint,
    required int copies,
  }) async {
    _validateSystemPrinter(
      name: name,
      systemPrinterName: systemPrinterName,
      systemPrinterUrl: systemPrinterUrl,
      paperWidthMm: paperWidthMm,
      copies: copies,
    );
    final now = _clock.now();
    final profile = PrinterProfile(
      id: 'TEMP_TEST',
      name: name.trim(),
      role: role.code,
      enabled: enabled,
      connectionType: PrinterConnectionType.systemPrinter.code,
      driverType: PrinterDriverType.systemPrinter.code,
      settingsJson: jsonEncode({
        'systemPrinterName': systemPrinterName.trim(),
        'systemPrinterUrl': systemPrinterUrl.trim(),
      }),
      paperWidthMm: paperWidthMm,
      arabicMode: ArabicPrintMode.raster.code,
      autoPrint: autoPrint,
      copies: copies,
      isDefault: true,
      lastTestStatus: null,
      lastTestAt: null,
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );
    return _adapterFactory.forProfile(profile).test(profile);
  }

  Future<PrinterAdapterResult> testPrinter(PrinterProfile profile) async {
    final adapter = _adapterFactory.forProfile(profile);
    final result = await adapter.test(profile);
    await _dao.saveTestResult(
      id: profile.id,
      success: result.success,
      error: result.errorMessage,
    );
    return result;
  }

  /// Enable/disable a printer with strict validation.
  /// A printer can only be enabled if:
  ///  - lastTestStatus == 'ready'
  ///  - adapter supports current platform
  ///  - required connection fields are valid
  Future<void> setEnabled(String id, bool enabled) async {
    if (enabled) {
      final profile = await _dao.getById(id);
      if (profile == null) {
        throw StateError('Printer profile not found.');
      }
      if (profile.lastTestStatus != 'ready') {
        throw StateError(
          'Run a successful test print before enabling this printer.',
        );
      }
      final adapter = _adapterFactory.forProfile(profile);
      if (!adapter.isSupportedOnCurrentPlatform(profile)) {
        throw StateError(
          'This printer type is not supported on the current platform.',
        );
      }
    }
    return _dao.setEnabled(id, enabled);
  }

  Future<void> delete(String id) => _dao.delete(id);

  Future<void> saveLastError(String id, String? error) {
    return _dao.saveLastError(id, error);
  }

  void _validateNetworkPrinter({
    required String name,
    required String ipAddress,
    required int port,
    required int paperWidthMm,
    required ArabicPrintMode arabicMode,
    required int copies,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Printer name is required.');
    }
    if (ipAddress.trim().isEmpty) {
      throw ArgumentError('Printer IP address is required.');
    }
    if (port <= 0 || port > 65535) {
      throw ArgumentError('Printer port must be between 1 and 65535.');
    }
    if (paperWidthMm != 58 && paperWidthMm != 80) {
      throw ArgumentError('Paper width must be 58mm or 80mm.');
    }
    if (copies < 1) {
      throw ArgumentError('Copies must be at least 1.');
    }
  }

  void _validateSystemPrinter({
    required String name,
    required String systemPrinterName,
    required String systemPrinterUrl,
    required int paperWidthMm,
    required int copies,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Printer name is required.');
    }
    if (systemPrinterName.trim().isEmpty || systemPrinterUrl.trim().isEmpty) {
      throw ArgumentError('System printer selection is required.');
    }
    if (paperWidthMm != 58 && paperWidthMm != 80) {
      throw ArgumentError('Paper width must be 58mm or 80mm.');
    }
    if (copies < 1) {
      throw ArgumentError('Copies must be at least 1.');
    }
  }

  PrinterProfilesCompanion _networkPrinterCompanion({
    required String id,
    required String name,
    required PrinterRole role,
    required bool enabled,
    required String ipAddress,
    required int port,
    required int paperWidthMm,
    required ArabicPrintMode arabicMode,
    required bool autoPrint,
    required int copies,
    required bool isDefault,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String? lastTestStatus,
    required DateTime? lastTestAt,
    required String? lastError,
  }) {
    return PrinterProfilesCompanion(
      id: Value(id),
      name: Value(name.trim()),
      role: Value(role.code),
      enabled: Value(enabled),
      connectionType: Value(PrinterConnectionType.networkIp.code),
      driverType: Value(PrinterDriverType.escpos.code),
      settingsJson: Value(
        jsonEncode({'ipAddress': ipAddress.trim(), 'port': port}),
      ),
      paperWidthMm: Value(paperWidthMm),
      arabicMode: Value(arabicMode.code),
      autoPrint: Value(autoPrint),
      copies: Value(copies),
      isDefault: Value(isDefault),
      lastTestStatus: Value(lastTestStatus),
      lastTestAt: Value(lastTestAt),
      lastError: Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  PrinterProfilesCompanion _systemPrinterCompanion({
    required String id,
    required String name,
    required PrinterRole role,
    required bool enabled,
    required String systemPrinterName,
    required String systemPrinterUrl,
    required int paperWidthMm,
    required bool autoPrint,
    required int copies,
    required bool isDefault,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String? lastTestStatus,
    required DateTime? lastTestAt,
    required String? lastError,
  }) {
    return PrinterProfilesCompanion(
      id: Value(id),
      name: Value(name.trim()),
      role: Value(role.code),
      enabled: Value(enabled),
      connectionType: Value(PrinterConnectionType.systemPrinter.code),
      driverType: Value(PrinterDriverType.systemPrinter.code),
      settingsJson: Value(
        jsonEncode({
          'systemPrinterName': systemPrinterName.trim(),
          'systemPrinterUrl': systemPrinterUrl.trim(),
        }),
      ),
      paperWidthMm: Value(paperWidthMm),
      arabicMode: Value(ArabicPrintMode.raster.code),
      autoPrint: Value(autoPrint),
      copies: Value(copies),
      isDefault: Value(isDefault),
      lastTestStatus: Value(lastTestStatus),
      lastTestAt: Value(lastTestAt),
      lastError: Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  /// Scans local subnet for ESC/POS printers listening on [port].
  /// [subnetPrefix] should be like '192.168.1'. Non-blocking, short timeout.
  /// Returns list of IP addresses that responded on the given port.
  Future<List<String>> discoverNetworkPrinters({
    required String subnetPrefix,
    int port = 9100,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final results = <String>[];
    // Scan in batches of 25 to avoid socket exhaustion.
    for (var batch = 1; batch <= 254; batch += 25) {
      final futures = <Future<void>>[];
      for (var i = batch; i < batch + 25 && i <= 254; i++) {
        final host = '$subnetPrefix.$i';
        futures.add(
          _probePort(host, port, timeout).then((open) {
            if (open) results.add(host);
          }),
        );
      }
      await Future.wait(futures);
    }
    return results;
  }

  Future<bool> _probePort(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
