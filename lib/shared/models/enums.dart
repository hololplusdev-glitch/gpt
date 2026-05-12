// shared/models/enums.dart
// WHY: Single source of truth for all status/type codes used across all layers.
// All values are stable string codes. Never store enum.index in DB.
// DB columns store `.code`.

// =============================================================================
// SALE
// =============================================================================

/// Sale lifecycle status. Stored in sales.status as `.code`.
enum SaleStatus {
  draft('draft'),
  completed('completed'),
  voided('voided'),
  refunded('refunded');

  final String code;
  const SaleStatus(this.code);

  static SaleStatus? fromCode(String? code) =>
      SaleStatus.values.where((e) => e.code == code).firstOrNull;
}

/// Sale type. Stored in sales.type as `.code`.
enum SaleType {
  sale('sale'),
  returnSale('return_sale'),
  voidSale('void_sale');

  final String code;
  const SaleType(this.code);

  static SaleType? fromCode(String? code) =>
      SaleType.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// SHIFT
// =============================================================================

/// Shift lifecycle status. Stored in shifts.status as `.code`.
enum ShiftStatus {
  open('open'),
  closing('closing'),
  closed('closed'),
  expired('expired');

  final String code;
  const ShiftStatus(this.code);

  static ShiftStatus? fromCode(String? code) =>
      ShiftStatus.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// OUTBOX / SYNC
// =============================================================================

/// What happened that needs uploading. Stored in outbox_events.event_type.
enum OutboxEventType {
  saleCreated('sale_created'),
  saleVoided('sale_voided'),
  shiftOpened('shift_opened'),
  shiftClosed('shift_closed'),
  shiftExtended('shift_extended'),
  returnCreated('return_created');

  final String code;
  const OutboxEventType(this.code);

  static OutboxEventType? fromCode(String? code) =>
      OutboxEventType.values.where((e) => e.code == code).firstOrNull;
}

/// Which entity the outbox event refers to.
enum OutboxEntityType {
  sale('sale'),
  shift('shift'),
  heldOrder('held_order'),
  returnSale('return_sale');

  final String code;
  const OutboxEntityType(this.code);

  static OutboxEntityType? fromCode(String? code) =>
      OutboxEntityType.values.where((e) => e.code == code).firstOrNull;
}

/// Outbox event status. Stored in outbox_events.status.
enum OutboxStatus {
  pending('pending'),
  uploading('uploading'),
  uploaded('uploaded'),
  failed('failed'),
  blocked('blocked');

  final String code;
  const OutboxStatus(this.code);

  static OutboxStatus? fromCode(String? code) =>
      OutboxStatus.values.where((e) => e.code == code).firstOrNull;
}

/// Download sync status for master data runs.
enum SyncStatusCode {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  blocked('blocked');

  final String code;
  const SyncStatusCode(this.code);

  static SyncStatusCode? fromCode(String? code) =>
      SyncStatusCode.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// PAYMENT
// =============================================================================

/// Payment entry status within a sale.
enum PaymentStatus {
  pending('pending'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String code;
  const PaymentStatus(this.code);

  static PaymentStatus? fromCode(String? code) =>
      PaymentStatus.values.where((e) => e.code == code).firstOrNull;
}

/// Payment method type — describes the method used by the cashier.
enum PaymentMethodType {
  cash('cash'),
  manualCard('manual_card'),
  cheque('cheque'),
  bankTransfer('bank_transfer'),
  wallet('wallet'),
  customerCredit('customer_credit');

  final String code;
  const PaymentMethodType(this.code);

  static PaymentMethodType? fromCode(String? code) =>
      PaymentMethodType.values.where((e) => e.code == code).firstOrNull;
}

/// Standard payment method code prefixes/constants for Backend mapping.
abstract final class PaymentMethodCodes {
  static const cash = 'CASH';
  static const manualCard = 'MANUAL_CARD';
  static const customerCredit = 'CUSTOMER_CREDIT';

  // WHY: Composite codes encode the underlying bank/card type ID.
  static const cashAccountPrefix = 'CASH_';
  static const bankAccountPrefix = 'BANK_';
  static const cardTypePrefix = 'CARD_';
}

extension PaymentMethodTypeRules on PaymentMethodType {
  bool get isCash => this == PaymentMethodType.cash;
  bool get isManualCard => this == PaymentMethodType.manualCard;
  bool get isCard => isManualCard;
  bool get allowsChange => isCash;
}

// =============================================================================
// PRINTING
// =============================================================================

enum PrintJobStatus {
  pending('pending'),
  printing('printing'),
  printed('printed'),
  failed('failed'),
  cancelled('cancelled');

  final String code;
  const PrintJobStatus(this.code);

  static PrintJobStatus? fromCode(String? code) =>
      PrintJobStatus.values.where((e) => e.code == code).firstOrNull;
}

enum PrintDocumentType {
  invoiceReceipt('invoice_receipt'),
  invoiceReceiptCopy('invoice_receipt_copy');

  final String code;
  const PrintDocumentType(this.code);

  static PrintDocumentType? fromCode(String? code) =>
      PrintDocumentType.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// AUDIT
// =============================================================================

/// Audit action types. Stored in audit_log.action as `.code`.
enum AuditAction {
  login('login'),
  logout('logout'),
  shiftOpened('shift_opened'),
  shiftClosed('shift_closed'),
  shiftExtended('shift_extended'),
  saleCompleted('sale_completed'),
  saleVoided('sale_voided'),
  returnCreated('return_created'),
  discountApplied('discount_applied'),
  priceOverride('price_override'),
  supervisorOverride('supervisor_override'),
  receiptPrinted('receipt_printed'),
  receiptReprinted('receipt_reprinted'),
  orderHeld('order_held'),
  orderRecalled('order_recalled'),
  orderCancelled('order_cancelled'),
  settingsChanged('settings_changed'),
  syncFailed('sync_failed'),
  syncSucceeded('sync_succeeded');

  final String code;
  const AuditAction(this.code);

  static AuditAction? fromCode(String? code) =>
      AuditAction.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// PERMISSION
// =============================================================================

/// Permission codes for role-based access control.
/// Until Auth API exists, baseline permissions derive from
/// user_terminal_access flags.
enum PermissionCode {
  saleCreate('sale_create'),
  saleDiscount('sale_discount'),
  saleVoid('sale_void'),
  saleRefund('sale_refund'),
  shiftOpen('shift_open'),
  shiftClose('shift_close'),
  shiftExtend('shift_extend'),
  reprintReceipt('reprint_receipt'),
  deviceSettingsAccess('device_settings_access'),
  printerConfig('printer_config'),
  paymentDeviceConfig('payment_device_config'),
  settingsAccess('settings_access'),
  viewShiftReport('view_shift_report'),
  supervisorOverride('supervisor_override'),
  holdOrder('hold_order'),
  recallOrder('recall_order'),
  cancelHeldOrder('cancel_held_order'),
  priceOverride('price_override');

  final String code;
  const PermissionCode(this.code);

  static PermissionCode? fromCode(String? code) =>
      PermissionCode.values.where((e) => e.code == code).firstOrNull;
}

/// Protected actions requiring supervisor approval.
enum ProtectedAction {
  voidSale('void_sale'),
  returnSale('return_sale'),
  priceOverride('price_override'),
  discountOverride('discount_override'),
  settingsChange('settings_change'),
  reprintReceipt('reprint_receipt'),
  clearCart('clear_cart'),
  cancelHeldOrder('cancel_held_order');

  final String code;
  const ProtectedAction(this.code);

  static ProtectedAction? fromCode(String? code) =>
      ProtectedAction.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// DEVICE / PRINTER
// =============================================================================

enum DeviceStatus {
  connected('connected'),
  disconnected('disconnected'),
  connecting('connecting'),
  error('error');

  final String code;
  const DeviceStatus(this.code);

  static DeviceStatus? fromCode(String? code) =>
      DeviceStatus.values.where((e) => e.code == code).firstOrNull;
}

enum HealthStatus {
  ok('ok'),
  degraded('degraded'),
  down('down'),
  unknown('unknown');

  final String code;
  const HealthStatus(this.code);

  static HealthStatus? fromCode(String? code) =>
      HealthStatus.values.where((e) => e.code == code).firstOrNull;
}

enum PrinterRole {
  cashier('cashier'),
  kitchen('kitchen');

  final String code;
  const PrinterRole(this.code);

  static PrinterRole? fromCode(String? code) =>
      PrinterRole.values.where((e) => e.code == code).firstOrNull;
}

enum PrinterConnectionType {
  networkIp('network_ip'),
  bluetooth('bluetooth'),
  systemPrinter('system_printer');

  final String code;
  const PrinterConnectionType(this.code);

  static PrinterConnectionType? fromCode(String? code) =>
      PrinterConnectionType.values.where((e) => e.code == code).firstOrNull;
}

enum PrinterDriverType {
  escpos('escpos'),
  systemPrinter('system_printer');

  final String code;
  const PrinterDriverType(this.code);

  static PrinterDriverType? fromCode(String? code) =>
      PrinterDriverType.values.where((e) => e.code == code).firstOrNull;
}

enum ArabicPrintMode {
  raster('raster');

  final String code;
  const ArabicPrintMode(this.code);

  static ArabicPrintMode? fromCode(String? code) =>
      ArabicPrintMode.values.where((e) => e.code == code).firstOrNull;
}

enum PaymentProfileMode {
  manual('manual');

  final String code;
  const PaymentProfileMode(this.code);

  static PaymentProfileMode? fromCode(String? code) =>
      PaymentProfileMode.values.where((e) => e.code == code).firstOrNull;
}

enum PaymentConnectionType {
  none('none'),
  lan('lan'),
  usb('usb'),
  sdk('sdk');

  final String code;
  const PaymentConnectionType(this.code);

  static PaymentConnectionType? fromCode(String? code) =>
      PaymentConnectionType.values.where((e) => e.code == code).firstOrNull;
}

enum PaymentProvider {
  manual('manual'),
  geidea('geidea'),
  pax('pax'),
  bank('bank'),
  other('other');

  final String code;
  const PaymentProvider(this.code);

  static PaymentProvider? fromCode(String? code) =>
      PaymentProvider.values.where((e) => e.code == code).firstOrNull;
}

// =============================================================================
// MISC DOMAIN
// =============================================================================

/// Discount type for cart line items.
enum DiscountType {
  percentage('percentage'),
  fixed('fixed');

  final String code;
  const DiscountType(this.code);

  static DiscountType? fromCode(String? code) =>
      DiscountType.values.where((e) => e.code == code).firstOrNull;
}

/// Platform capability identifier.
enum AppPlatform {
  android('android'),
  windows('windows'),
  macos('macos'),
  ios('ios'),
  linux('linux'),
  web('web'),
  other('other');

  final String code;
  const AppPlatform(this.code);

  static AppPlatform? fromCode(String? code) =>
      AppPlatform.values.where((e) => e.code == code).firstOrNull;
}

/// Cash movement direction (cash in/out during shift).
enum CashMovementType {
  cashIn('cash_in'),
  cashOut('cash_out'),
  cashRefund('cash_refund');

  final String code;
  const CashMovementType(this.code);

  static CashMovementType? fromCode(String? code) =>
      CashMovementType.values.where((e) => e.code == code).firstOrNull;
}

/// Held order status.
enum HeldOrderStatus {
  held('held'),
  resumed('resumed'),
  cancelled('cancelled'),
  expired('expired');

  final String code;
  const HeldOrderStatus(this.code);

  static HeldOrderStatus? fromCode(String? code) =>
      HeldOrderStatus.values.where((e) => e.code == code).firstOrNull;
}

/// Sync mode for the upload outbox.
enum SyncMode {
  manualOnly('manual_only'),
  onShiftClose('on_shift_close'),
  periodic('periodic'),
  afterEachSale('after_each_sale');

  final String code;
  const SyncMode(this.code);

  static SyncMode fromCode(String? code) =>
      SyncMode.values.where((e) => e.code == code).firstOrNull ??
      SyncMode.manualOnly;
}
