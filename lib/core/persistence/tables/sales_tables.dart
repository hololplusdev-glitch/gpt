// core/persistence/tables/sales_tables.dart
// WHY: Sale tables for the offline-first checkout flow.
// Status/type stored as stable string codes, not enum.index.
// Quantity uses a pair of integer columns for fractional support.

import 'package:drift/drift.dart';

/// Sale header — replaces Sales table.
/// status: 'draft','completed','voided','refunded','pending_sync','synced'
/// type: 'sale','return','void'
/// sync_status: 'pending','synced','failed','blocked'
@TableIndex(name: 'idx_sales_shift_id', columns: {#shiftId})
@TableIndex(name: 'idx_sales_completed_at', columns: {#completedAt})
@TableIndex(name: 'idx_sales_sync_status', columns: {#syncStatus})
@TableIndex(name: 'idx_sales_status', columns: {#status})
@TableIndex(
  name: 'idx_sales_terminal_local_no',
  columns: {#terminalId, #localSaleNo},
)
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get localSaleNo => text()();
  TextColumn get serverInvoiceNo => text().nullable()();
  TextColumn get idempotencyKey => text()();
  TextColumn get type => text()(); // stable string code
  TextColumn get status => text()(); // stable string code
  TextColumn get syncStatus => text()(); // stable string code
  TextColumn get tenantCode => text().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get terminalId => text()();
  TextColumn get machineNo => text().nullable()();
  TextColumn get shiftId => text()();
  TextColumn get cashierId => text()();
  TextColumn get sourceUserId => text().nullable()();
  TextColumn get cashierNameSnapshot => text().nullable()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerNameSnapshot => text().nullable()();
  TextColumn get customerTaxNumberSnapshot => text().nullable()();
  TextColumn get originalSaleId => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  BoolColumn get useTax => boolean().nullable()();
  BoolColumn get priceIncludesTax => boolean().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discountTotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxTotal => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real()();
  RealColumn get paidTotal => real().withDefault(const Constant(0.0))();
  RealColumn get remainingTotal => real().withDefault(const Constant(0.0))();
  RealColumn get changeTotal => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (idempotency_key)',
    'UNIQUE (terminal_id, local_sale_no)',
  ];
}

/// Sale line items.
/// price_source: 'item_price','tier_price','manual_override'
@TableIndex(name: 'idx_sale_lines_sale_id', columns: {#saleId})
@TableIndex(name: 'idx_sale_lines_item_id', columns: {#itemId})
class SaleLines extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get itemId => text()();
  TextColumn get unitId => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get itemNameSnapshot => text()();
  TextColumn get unitNameSnapshot => text().nullable()();
  IntColumn get qtyScaled => integer()();
  IntColumn get qtyScale => integer().withDefault(const Constant(0))();
  RealColumn get unitPrice => real()();
  RealColumn get grossAmount => real().withDefault(const Constant(0.0))();
  TextColumn get lineDiscountType =>
      text().nullable()(); // 'percentage','fixed'
  RealColumn get lineDiscountValue => real().nullable()();
  RealColumn get lineDiscountAmount =>
      real().withDefault(const Constant(0.0))();
  RealColumn get invoiceDiscountShare =>
      real().withDefault(const Constant(0.0))();
  RealColumn get taxableAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real()();
  BoolColumn get allowDiscountSnapshot => boolean().nullable()();
  TextColumn get priceSource => text().nullable()();
  RealColumn get unitSize => real().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  TextColumn get overrideReason => text().nullable()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sale payments.
/// status: 'pending','approved','declined','cancelled'
@TableIndex(name: 'idx_sale_payments_sale_id', columns: {#saleId})
@TableIndex(name: 'idx_sale_payments_method_id', columns: {#paymentMethodId})
class SalePayments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get paymentMethodId => text()();
  TextColumn get methodCodeSnapshot => text()();
  TextColumn get methodNameSnapshot => text().nullable()();
  TextColumn get methodTypeSnapshot => text().nullable()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();
  RealColumn get amount => real()();
  RealColumn get cashTendered => real().nullable()();
  RealColumn get changeGiven => real().nullable()();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get bankId => text().nullable()();
  TextColumn get cardTypeId => text().nullable()();
  TextColumn get paymentDeviceRef => text().nullable()();
  TextColumn get authCode => text().nullable()();
  TextColumn get rrn => text().nullable()();
  TextColumn get cardScheme => text().nullable()();
  TextColumn get cardLast4 => text().nullable()();
  TextColumn get status => text()(); // stable string code
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sale adjustments.
/// Supports invoice/line/customer/manual/promo/coupon discounts.
/// scope: 'invoice','line'
/// type: 'percentage','fixed'
/// source: 'manual','customer','promo','coupon','system'
@TableIndex(name: 'idx_sale_adjustments_sale_id', columns: {#saleId})
class SaleAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get lineId => text().nullable()();
  TextColumn get scope => text()(); // 'invoice','line'
  TextColumn get type => text()(); // 'percentage','fixed'
  TextColumn get source => text()(); // 'manual','customer', etc.
  RealColumn get value => real()();
  RealColumn get amount => real()();
  TextColumn get reason => text().nullable()();
  TextColumn get approvedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sale tax summary.
@TableIndex(name: 'idx_sale_tax_summary_sale_id', columns: {#saleId})
class SaleTaxSummary extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  RealColumn get taxRate => real()();
  RealColumn get taxableAmount => real()();
  RealColumn get taxAmount => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoice document snapshots — moved out of sales header.
@TableIndex(name: 'idx_invoice_documents_sale_id', columns: {#saleId})
class InvoiceDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get snapshotJson => text().nullable()();
  TextColumn get hash => text().nullable()();
  TextColumn get validationStatus => text().nullable()();
  TextColumn get validationError => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Held/suspended orders.
/// status: 'held','resumed','cancelled','expired'
class HeldOrders extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get machineNo => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  BoolColumn get useTax => boolean().nullable()();
  TextColumn get shiftId => text()();
  TextColumn get cashierId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerNameSnapshot => text().nullable()();
  TextColumn get referenceName => text().nullable()();
  TextColumn get snapshotJson => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxTotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountTotal => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  TextColumn get status => text()(); // stable string code
  TextColumn get notes => text().nullable()();
  DateTimeColumn get heldAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get resumedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Held order line items.
class HeldOrderLines extends Table {
  TextColumn get id => text()();
  TextColumn get heldOrderId => text()();
  TextColumn get itemId => text()();
  TextColumn get unitId => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get itemNameSnapshot => text()();
  TextColumn get unitNameSnapshot => text().nullable()();
  IntColumn get qtyScaled => integer()();
  IntColumn get qtyScale => integer().withDefault(const Constant(0))();
  RealColumn get unitPrice => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
