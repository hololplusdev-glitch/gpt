import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/layout.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/services/pos_devices/payment_profile_service.dart';
import 'package:pos_flutter/core/services/pos_devices/print_job_service.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/presentation/presenters/printer_status_presenter.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:pos_flutter/core/services/pos_devices/printer_profile_service.dart';

import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_empty_state.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_section_card.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_status_chip.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_switch.dart';
import 'package:pos_flutter/shared/presentation/utils/app_snackbar.dart';
import 'package:pos_flutter/shared/presentation/dialogs/app_dialog.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';

import 'dialogs/printer_form_dialogs.dart';

class PosDevicesScreen extends ConsumerWidget {
  const PosDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final printers = ref.watch(printerProfilesProvider);
    final paymentProfile = ref.watch(manualPaymentProfileProvider);
    final jobs = ref.watch(retryablePrintJobsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.posDevices)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.standard),
          child: ListView(
            padding: AppSpacing.paddingLg,
            children: [
              printers.when(
                data: (items) => _PrintersSection(printers: items),
                loading: () => const AppLoading(),
                error: (_, _) =>
                    AppInfoBanner.error(message: l10n.unableToLoadPrinters),
              ),
              const SizedBox(height: AppSpacing.lg),
              paymentProfile.when(
                data: (profile) => _PaymentSection(profile: profile),
                loading: () => const AppLoading(),
                error: (_, _) => AppInfoBanner.error(
                  message: l10n.unableToLoadPaymentProfile,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              printers.when(
                data: (items) => paymentProfile.when(
                  data: (profile) => _ReadinessSection(
                    printers: items,
                    paymentProfile: profile,
                    retryableJobs: jobs.valueOrNull ?? const [],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintersSection extends ConsumerWidget {
  final List<PrinterProfile> printers;

  const _PrintersSection({required this.printers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppSectionCard(
      title: l10n.printers,
      icon: Icons.print_outlined,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.searchNetwork,
            icon: const Icon(Icons.wifi_find),
            onPressed: () => showNetworkDiscoveryDialog(context, ref),
          ),
          IconButton(
            tooltip: l10n.addPrinter,
            icon: const Icon(Icons.add),
            onPressed: () => showPrinterDialog(context, ref),
          ),
        ],
      ),
      child: Column(
        children: [
          if (printers.isEmpty)
            AppEmptyState(
              icon: Icons.print_disabled_outlined,
              title: l10n.noPrintersConfigured,
              subtitle: l10n.addCashierOrKitchenPrinter,
            )
          else
            for (final printer in printers) _PrinterTile(printer: printer),
          const SizedBox(height: AppSpacing.md),
          _UnavailableOptions(),
        ],
      ),
    );
  }
}

class _PrinterTile extends ConsumerWidget {
  final PrinterProfile printer;

  const _PrinterTile({required this.printer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = PrinterStatusPresenter.roleFromName(printer.role);
    return ListTile(
      leading: Icon(PrinterStatusPresenter.roleIcon(role)),
      title: Text(printer.name),
      subtitle: Text(_printerSubtitle(printer, role, l10n)),
      trailing: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _readinessChip(_printerReadiness(printer), l10n),
          IconButton(
            tooltip: l10n.test,
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () async {
              final result = await ref
                  .read(printerProfileServiceProvider)
                  .testPrinter(printer);
              if (context.mounted) {
                if (result.success) {
                  AppSnackbar.showSuccess(context, l10n.testPrintSucceeded);
                } else {
                  AppSnackbar.showError(
                    context,
                    result.errorMessage ?? l10n.testPrintFailed,
                  );
                }
              }
            },
          ),
          Switch(
            value: printer.enabled,
            onChanged: (value) async {
              try {
                await ref
                    .read(printerProfileServiceProvider)
                    .setEnabled(printer.id, value);
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.showError(context, l10n.printerUpdateFailed);
                }
              }
            },
          ),
          IconButton(
            tooltip: l10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showPrinterDialog(context, ref, current: printer),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final shouldDelete = await AppDialog.show<bool>(
                context: context,
                dialog: AppDialog.warning(
                  title: l10n.deletePrinter,
                  content: Text(l10n.deletePrinterConfirmation(printer.name)),
                  confirmLabel: l10n.delete,
                  cancelLabel: l10n.cancel,
                ),
              );
              if (shouldDelete != true) return;
              try {
                await ref
                    .read(printerProfileServiceProvider)
                    .delete(printer.id);
              } catch (_) {
                if (context.mounted) {
                  AppSnackbar.showError(context, l10n.printerDeleteFailed);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends ConsumerStatefulWidget {
  final PaymentDeviceProfile? profile;

  const _PaymentSection({required this.profile});

  @override
  ConsumerState<_PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends ConsumerState<_PaymentSection> {
  late bool _enabled;
  late bool _requireReference;

  @override
  void initState() {
    super.initState();
    _enabled = widget.profile?.enabled ?? false;
    _requireReference = widget.profile?.requireReference ?? true;
  }

  @override
  void didUpdateWidget(covariant _PaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id ||
        oldWidget.profile?.enabled != widget.profile?.enabled ||
        oldWidget.profile?.requireReference !=
            widget.profile?.requireReference) {
      _enabled = widget.profile?.enabled ?? false;
      _requireReference = widget.profile?.requireReference ?? true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSectionCard(
      title: l10n.paymentTerminal,
      icon: Icons.credit_card,
      child: Column(
        children: [
          AppSwitchListTile(
            value: _enabled,
            title: l10n.enableCardPayment,
            subtitle: l10n.checkoutChoosesPaymentPerSale,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          AppSwitchListTile(
            value: _requireReference,
            title: l10n.requireReference,
            onChanged: (value) => setState(() => _requireReference = value),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.integratedMode),
            subtitle: Text(l10n.integratedNotAvailable),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.primary(
              icon: Icons.save_outlined,
              label: l10n.savePaymentProfile,
              onPressed: () => ref
                  .read(paymentProfileServiceProvider)
                  .saveManualConfiguration(
                    enabled: _enabled,
                    requireReference: _requireReference,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessSection extends ConsumerWidget {
  final List<PrinterProfile> printers;
  final PaymentDeviceProfile? paymentProfile;
  final List<PrintJob> retryableJobs;

  const _ReadinessSection({
    required this.printers,
    required this.paymentProfile,
    required this.retryableJobs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cashierReady = _roleReadiness(printers, PrinterRole.cashier);
    final kitchenReady = _roleReadiness(printers, PrinterRole.kitchen);
    final paymentEnabled = paymentProfile?.enabled == true;

    String saleReadiness = l10n.allowed;
    if (cashierReady == _DeviceReadiness.missing ||
        cashierReady == _DeviceReadiness.failed ||
        cashierReady == _DeviceReadiness.untested) {
      saleReadiness = l10n.allowedPrintWarning;
    } else if (kitchenReady == _DeviceReadiness.failed ||
        kitchenReady == _DeviceReadiness.untested) {
      saleReadiness = l10n.allowedKitchenWarning;
    }

    if (!paymentEnabled) {
      saleReadiness = '$saleReadiness - ${l10n.noCard}';
    }

    return AppSectionCard(
      title: l10n.readiness,
      icon: Icons.health_and_safety_outlined,
      child: Column(
        children: [
          _ReadinessTile(
            label: l10n.cashierPrinter,
            value: _getReadinessLabel(cashierReady, l10n),
          ),
          _ReadinessTile(
            label: l10n.kitchenPrinter,
            value: _getReadinessLabel(kitchenReady, l10n),
          ),
          _ReadinessTile(
            label: l10n.paymentTerminal,
            value: paymentEnabled ? l10n.manualCard : l10n.disabled,
          ),
          _ReadinessTile(
            label: l10n.referenceRequired,
            value: paymentProfile?.requireReference == true
                ? l10n.yes
                : l10n.no,
          ),
          _ReadinessTile(
            label: l10n.retryableJobs,
            value: '${retryableJobs.length}',
          ),
          if (retryableJobs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppButton.primary(
                icon: Icons.replay,
                label: l10n.retryFailedJobs(retryableJobs.length),
                onPressed: () async {
                  await ref
                      .read(printJobProcessorProvider)
                      .processRetryableJobs();
                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      l10n.retryQueuedJobsProcessed,
                    );
                  }
                },
              ),
            ),
          _ReadinessTile(label: l10n.saleReadiness, value: saleReadiness),
        ],
      ),
    );
  }
}

/// WHY: Unimplemented connection types (USB/Bluetooth/System/Built-in) are
/// hidden from the UI entirely. Showing them with "not available" labels
/// confuses users into thinking these features should work. The factory
/// retains knowledge of them for future enablement — we simply filter here.
class _UnavailableOptions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WHY: Intentionally hidden. Uncomment only for developer debugging.
    // Unimplemented connection types should NOT appear in production UX.
    return const SizedBox.shrink();
  }
}

class _ReadinessTile extends StatelessWidget {
  final String label;
  final String value;

  const _ReadinessTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum _DeviceReadiness {
  missing,
  disabled,
  untested,
  ready,
  failed,
  unsupported,
}

String _getReadinessLabel(_DeviceReadiness readiness, AppLocalizations l10n) {
  return switch (readiness) {
    _DeviceReadiness.missing => l10n.missing,
    _DeviceReadiness.disabled => l10n.disabled,
    _DeviceReadiness.untested => l10n.untested,
    _DeviceReadiness.ready => l10n.ready,
    _DeviceReadiness.failed => l10n.failed,
    _DeviceReadiness.unsupported => l10n.unsupported,
  };
}

AppStatusChip _readinessChip(
  _DeviceReadiness readiness,
  AppLocalizations l10n,
) {
  final color = switch (readiness) {
    _DeviceReadiness.ready => AppColors.success,
    _DeviceReadiness.failed => AppColors.error,
    _DeviceReadiness.untested => AppColors.warning,
    _DeviceReadiness.disabled => AppColors.textHint,
    _DeviceReadiness.missing => AppColors.textHint,
    _DeviceReadiness.unsupported => AppColors.error,
  };
  return AppStatusChip(
    label: _getReadinessLabel(readiness, l10n),
    color: color,
  );
}

String _printerSubtitle(
  PrinterProfile printer,
  PrinterRole? role,
  AppLocalizations l10n,
) {
  final roleLabel = PrinterStatusPresenter.roleLabel(role, l10n);
  final connectionType = PrinterConnectionType.fromCode(printer.connectionType);
  if (connectionType == PrinterConnectionType.systemPrinter) {
    return '$roleLabel - ${l10n.systemPrinter} ${printer.systemPrinterName ?? ''}';
  }
  return '$roleLabel - ${l10n.networkPrinter} ${printer.ipAddress ?? ''}:${printer.port ?? 9100}';
}

_DeviceReadiness _printerReadiness(PrinterProfile printer) {
  if (!printer.enabled) return _DeviceReadiness.disabled;
  return switch (printer.lastTestStatus) {
    'ready' => _DeviceReadiness.ready,
    'failed' => _DeviceReadiness.failed,
    _ => _DeviceReadiness.untested,
  };
}

_DeviceReadiness _roleReadiness(
  List<PrinterProfile> printers,
  PrinterRole role,
) {
  final rolePrinters = printers.where((p) => p.role == role.code).toList();
  if (rolePrinters.isEmpty) return _DeviceReadiness.missing;
  final active = rolePrinters.firstWhereOrNull((p) => p.enabled && p.isDefault);
  if (active == null) return _DeviceReadiness.disabled;
  return _printerReadiness(active);
}
