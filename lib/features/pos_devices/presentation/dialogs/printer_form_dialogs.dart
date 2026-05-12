import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/responsive_row.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/presentation/presenters/printer_status_presenter.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

void showNetworkDiscoveryDialog(BuildContext context, WidgetRef ref) async {
  String defaultSubnet = '192.168.1.1';
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
          final parts = addr.address.split('.');
          defaultSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          break;
        } else if (!addr.isLoopback && addr.address.startsWith('10.')) {
          final parts = addr.address.split('.');
          defaultSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          break;
        } else if (!addr.isLoopback && addr.address.startsWith('172.')) {
          // Simple check for 172.16.x.x to 172.31.x.x
          final parts = addr.address.split('.');
          defaultSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          break;
        }
      }
    }
  } catch (_) {
    // Ignore and fallback to default
  }

  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final subnetCtrl = TextEditingController(text: defaultSubnet);
  var isScanning = false;
  var discoveredIps = <String>[];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppDialog(
        title: l10n.searchNetworkPrinters,
        icon: Icons.wifi_find,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: subnetCtrl,
              labelText: l10n.subnetPrefixExample,
              prefixIcon: const Icon(Icons.router_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isScanning)
              Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  children: [
                    const AppLoading(),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.scanningPort(9100)),
                  ],
                ),
              )
            else if (discoveredIps.isEmpty)
              AppInfoBanner(message: l10n.networkPrinterSearchHint)
            else
              ...discoveredIps.map(
                (ip) => ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(ip),
                  subtitle: Text(l10n.portNumber(9100)),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.pop(ctx);
                    showPrinterDialog(context, ref, prefilledIp: ip);
                  },
                ),
              ),
          ],
        ),
        cancelLabel: l10n.close,
        confirmLabel: l10n.search,
        isConfirmLoading: isScanning,
        onConfirm: () async {
          setState(() {
            isScanning = true;
            discoveredIps = [];
          });
          try {
            final results = await ref
                .read(printerProfileServiceProvider)
                .discoverNetworkPrinters(subnetPrefix: subnetCtrl.text.trim());
            if (!ctx.mounted) return;
            setState(() {
              discoveredIps = results;
              isScanning = false;
            });
          } catch (e) {
            if (!ctx.mounted) return;
            setState(() => isScanning = false);
            AppSnackbar.showError(ctx, l10n.networkSearchFailed);
          }
        },
      ),
    ),
  );
}

void showPrinterDialog(
  BuildContext context,
  WidgetRef ref, {
  PrinterProfile? current,
  String? prefilledIp,
}) {
  final nameCtrl = TextEditingController(text: current?.name ?? '');
  final ipCtrl = TextEditingController(
    text: current?.ipAddress ?? prefilledIp ?? '',
  );
  final portCtrl = TextEditingController(text: '${current?.port ?? 9100}');
  var connectionType =
      PrinterConnectionType.fromCode(current?.connectionType) ??
      PrinterConnectionType.networkIp;
  var selectedSystemPrinterName = current?.systemPrinterName;
  var selectedSystemPrinterUrl = current?.systemPrinterUrl;
  final systemPrintersFuture = ref
      .read(printerProfileServiceProvider)
      .listSystemPrinters();
  var role =
      PrinterStatusPresenter.roleFromName(current?.role) ?? PrinterRole.cashier;
  var paperWidth = current?.paperWidthMm ?? 80;
  var enabled = current?.enabled ?? true;
  var autoPrint = current?.autoPrint ?? true;
  var copies = current?.copies ?? 1;
  var lastTestOk = current?.lastTestStatus == 'ready';
  DateTime? testedAt = current?.lastTestAt;
  String? testMessage = current?.lastError;
  var isTesting = false;
  final l10n = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppDialog(
        title: current == null ? l10n.addPrinter : l10n.editPrinter,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<PrinterRole>(
                  segments: [
                    ButtonSegment(
                      value: PrinterRole.cashier,
                      label: Text(l10n.cashierRole),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                    ButtonSegment(
                      value: PrinterRole.kitchen,
                      label: Text(l10n.kitchenRole),
                      icon: const Icon(Icons.restaurant_outlined),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (value) => setState(() {
                    role = value.first;
                    lastTestOk = false;
                    testedAt = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<PrinterConnectionType>(
                  segments: [
                    ButtonSegment(
                      value: PrinterConnectionType.networkIp,
                      label: Text(l10n.networkPrinter),
                      icon: const Icon(Icons.router_outlined),
                    ),
                    ButtonSegment(
                      value: PrinterConnectionType.systemPrinter,
                      label: Text(l10n.systemPrinter),
                      icon: const Icon(Icons.print_outlined),
                    ),
                    const ButtonSegment(
                      value: PrinterConnectionType.bluetooth,
                      label: Text('Bluetooth'),
                      icon: Icon(Icons.bluetooth),
                      enabled: false,
                    ),
                  ],
                  selected: {connectionType},
                  onSelectionChanged: (value) => setState(() {
                    connectionType = value.first;
                    lastTestOk = false;
                    testedAt = null;
                    testMessage = null;
                    enabled = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: nameCtrl,
                  onChanged: (_) => setState(() {
                    lastTestOk = false;
                    testedAt = null;
                  }),
                  labelText: l10n.printerName,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                if (connectionType == PrinterConnectionType.networkIp)
                  ResponsiveRow(
                    breakpoint: 420,
                    spacing: AppSpacing.sm,
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          controller: ipCtrl,
                          onChanged: (_) => setState(() {
                            lastTestOk = false;
                            testedAt = null;
                          }),
                          labelText: l10n.ipAddress,
                          prefixIcon: const Icon(Icons.router_outlined),
                        ),
                      ),
                      AppTextField(
                        controller: portCtrl,
                        onChanged: (_) => setState(() {
                          lastTestOk = false;
                          testedAt = null;
                        }),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        labelText: l10n.port,
                      ),
                    ],
                  )
                else
                  FutureBuilder(
                    future: systemPrintersFuture,
                    builder: (context, snapshot) {
                      final printers = snapshot.data ?? const [];
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const AppLoading();
                      }
                      if (printers.isEmpty) {
                        return AppInfoBanner.error(
                          message: 'No system printers are available.',
                        );
                      }
                      final selectedUrl =
                          printers.any(
                            (printer) =>
                                printer.url == selectedSystemPrinterUrl,
                          )
                          ? selectedSystemPrinterUrl
                          : null;
                      return DropdownButtonFormField<String>(
                        initialValue: selectedUrl,
                        decoration: InputDecoration(
                          labelText: l10n.systemPrinter,
                          prefixIcon: const Icon(Icons.print_outlined),
                        ),
                        items: [
                          for (final printer in printers)
                            DropdownMenuItem(
                              value: printer.url,
                              child: Text(
                                printer.isDefault
                                    ? '${printer.name} (Default)'
                                    : printer.name,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          final selected = printers
                              .where((printer) => printer.url == value)
                              .firstOrNull;
                          selectedSystemPrinterUrl = selected?.url;
                          selectedSystemPrinterName = selected?.name;
                          if (nameCtrl.text.trim().isEmpty &&
                              selected != null) {
                            nameCtrl.text = selected.name;
                          }
                          lastTestOk = false;
                          testedAt = null;
                        }),
                      );
                    },
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(l10n.paperWidth),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 58,
                          label: Text(l10n.paperWidthMm(58)),
                        ),
                        ButtonSegment(
                          value: 80,
                          label: Text(l10n.paperWidthMm(80)),
                        ),
                      ],
                      selected: {paperWidth},
                      onSelectionChanged: (value) => setState(() {
                        paperWidth = value.first;
                        lastTestOk = false;
                        testedAt = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(l10n.copies),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<int>(
                        initialValue: copies,
                        decoration: const InputDecoration(isDense: true),
                        items: [1, 2, 3, 4]
                            .map(
                              (c) =>
                                  DropdownMenuItem(value: c, child: Text('$c')),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          copies = val ?? 1;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  title: Text(l10n.autoPrintAfterSale),
                  value: autoPrint,
                  onChanged: (val) => setState(() => autoPrint = val),
                ),
                SwitchListTile(
                  title: Text(l10n.enablePrinter),
                  subtitle: Text(l10n.mustBeTestedSuccessfullyFirst),
                  value: enabled,
                  onChanged: lastTestOk
                      ? (val) => setState(() => enabled = val)
                      : null,
                ),
                if (testMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: AppInfoBanner(
                      message: testMessage!,
                      type: lastTestOk
                          ? AppBannerType.info
                          : AppBannerType.error,
                    ),
                  ),
                if (testedAt != null && lastTestOk)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      l10n.lastTestedAt('${testedAt!.toLocal()}'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton.text(
            onPressed: () => Navigator.pop(ctx),
            label: l10n.cancel,
          ),
          AppButton.primary(
            icon: Icons.print_outlined,
            label: l10n.testPrint,
            customColor: AppColors.warning.withValues(alpha: 0.1),
            onPressed: isTesting
                ? null
                : () async {
                    setState(() {
                      isTesting = true;
                      testMessage = l10n.testing;
                    });
                    try {
                      final port = int.tryParse(portCtrl.text) ?? 9100;
                      final service = ref.read(printerProfileServiceProvider);

                      final result =
                          connectionType == PrinterConnectionType.networkIp
                          ? await service.testNetworkPrinter(
                              name: nameCtrl.text,
                              role: role,
                              enabled: enabled,
                              autoPrint: autoPrint,
                              ipAddress: ipCtrl.text,
                              port: port,
                              paperWidthMm: paperWidth,
                              copies: copies,
                            )
                          : await service.testSystemPrinter(
                              name: nameCtrl.text,
                              role: role,
                              enabled: enabled,
                              autoPrint: autoPrint,
                              systemPrinterName:
                                  selectedSystemPrinterName ?? '',
                              systemPrinterUrl: selectedSystemPrinterUrl ?? '',
                              paperWidthMm: paperWidth,
                              copies: copies,
                            );

                      setState(() {
                        isTesting = false;
                        lastTestOk = result.success;
                        testedAt = result.success ? DateTime.now() : null;
                        testMessage = result.errorMessage;
                        if (!result.success) {
                          enabled = false;
                        }
                      });
                    } catch (e) {
                      setState(() {
                        isTesting = false;
                        lastTestOk = false;
                        testedAt = null;
                        testMessage = l10n.testPrintFailed;
                        enabled = false;
                      });
                    }
                  },
          ),
          AppButton.primary(
            onPressed: isTesting
                ? null
                : () async {
                    try {
                      final port = int.tryParse(portCtrl.text) ?? 9100;
                      final service = ref.read(printerProfileServiceProvider);

                      if (connectionType ==
                          PrinterConnectionType.systemPrinter) {
                        await service.saveSystemPrinter(
                          id: current?.id,
                          name: nameCtrl.text,
                          role: role,
                          enabled: enabled,
                          systemPrinterName: selectedSystemPrinterName ?? '',
                          systemPrinterUrl: selectedSystemPrinterUrl ?? '',
                          paperWidthMm: paperWidth,
                          autoPrint: autoPrint,
                          copies: copies,
                          isDefault: current?.isDefault ?? true,
                          testPassed: lastTestOk,
                          testedAt: testedAt,
                        );
                      } else if (current == null) {
                        await service.saveNetworkPrinter(
                          name: nameCtrl.text,
                          role: role,
                          enabled: enabled,
                          ipAddress: ipCtrl.text,
                          port: port,
                          paperWidthMm: paperWidth,
                          autoPrint: autoPrint,
                          copies: copies,
                          isDefault: true, // Auto default first one
                          testPassed: lastTestOk,
                          testedAt: testedAt,
                        );
                      } else {
                        await service.saveNetworkPrinter(
                          id: current.id,
                          name: nameCtrl.text,
                          role: role,
                          enabled: enabled,
                          ipAddress: ipCtrl.text,
                          port: port,
                          paperWidthMm: paperWidth,
                          autoPrint: autoPrint,
                          copies: copies,
                          isDefault: current.isDefault,
                          testPassed: lastTestOk,
                          testedAt: testedAt,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => testMessage = l10n.printerSaveFailed);
                    }
                  },
            label: l10n.save,
          ),
        ],
      ),
    ),
  );
}
