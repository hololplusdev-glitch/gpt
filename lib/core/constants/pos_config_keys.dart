// core/constants/pos_config_keys.dart
// WHY: Centralized config keys prevent string duplication and typo bugs.
// PosConfig stores local application settings only. Runtime POS context comes
// from ActivePosSession.

/// All POS configuration keys stored in `pos_config_cache` table.
/// Values stored as strings and parsed at read-time.
abstract final class PosConfigKeys {
  // -- Shift --
  static const useShift = 'use_shift';
  static const shiftDefaultDurationMinutes = 'shift_default_duration_minutes';
  static const shiftExtendMinutes = 'shift_extend_minutes';

  // -- Held invoices --
  static const useHeldInvoices = 'use_held_invoices';
  static const maxHeldInvoices = 'max_held_invoices';
  static const blockShiftCloseWithHeldInvoices =
      'block_shift_close_with_held_invoices';

  // -- Cart behavior --
  static const allowDuplicateItemsInCart = 'allow_duplicate_items_in_cart';

  // -- Tax formatting --
  static const priceIncludesTax = 'price_includes_tax';

  // -- Payment rules --
  static const requireCardReference = 'require_card_reference';
  static const allowCustomerCredit = 'allow_customer_credit';

  // -- Print --
  static const autoPrintAfterSale = 'auto_print_after_sale';

  // -- Invoice numbering --
  static const localInvoiceNumberPattern = 'local_invoice_number_pattern';

  // -- Auth --
  static const offlineLoginExpiryDays = 'offline_login_expiry_days';

  // -- Returns --
  static const allowOfflineReturns = 'allow_offline_returns';

  // -- Sync --
  static const syncMode = 'sync_mode';
}

/// Default config values for initial seed.
abstract final class PosConfigDefaults {
  static const Map<String, String> all = {
    PosConfigKeys.useShift: 'true',
    PosConfigKeys.shiftDefaultDurationMinutes: '480', // 8 hours
    PosConfigKeys.shiftExtendMinutes: '30',
    PosConfigKeys.useHeldInvoices: 'true',
    PosConfigKeys.maxHeldInvoices: '20',
    PosConfigKeys.blockShiftCloseWithHeldInvoices: 'true',
    PosConfigKeys.allowDuplicateItemsInCart: 'false',
    PosConfigKeys.priceIncludesTax: 'false',
    PosConfigKeys.requireCardReference: 'false',
    PosConfigKeys.allowCustomerCredit: 'false',
    PosConfigKeys.autoPrintAfterSale: 'true',
    PosConfigKeys.localInvoiceNumberPattern: '{STATION}-{YYYYMMDD}-{SEQ}',
    PosConfigKeys.offlineLoginExpiryDays: '30',
    PosConfigKeys.allowOfflineReturns: 'false',
    PosConfigKeys.syncMode: 'manualOnly',
  };
}
