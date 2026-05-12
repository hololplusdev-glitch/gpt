// core/constants/pos_config_keys.dart
// WHY: Centralized config keys prevent string duplication and typo bugs.
// PosConfig stores local application settings only. Runtime POS context comes
// from ActivePosSession.

/// All POS configuration keys stored in `terminal_local_settings`.
/// Values are stored as strings and parsed at read-time.
abstract final class PosConfigKeys {
  // -- Shift --
  // Shift is mandatory in this product. These values control shift timing only.
  static const shiftDefaultDurationMinutes = 'shift_default_duration_minutes';
  static const shiftExtendMinutes = 'shift_extend_minutes';

  // -- Held invoices --
  static const useHeldInvoices = 'use_held_invoices';
  static const maxHeldInvoices = 'max_held_invoices';
  static const blockShiftCloseWithHeldInvoices =
      'block_shift_close_with_held_invoices';

  // -- Tax formatting --
  static const priceIncludesTax = 'price_includes_tax';

  // -- Payment rules --
  static const requireCardReference = 'require_card_reference';

  // -- Print --
  static const autoPrintAfterSale = 'auto_print_after_sale';

  /// Legacy keys removed from runtime behavior.
  /// They may still exist in old local databases, so PosConfigRepository purges
  /// them during seeding.
  static const deprecatedKeys = <String>{
    'use_shift',
    'allow_duplicate_items_in_cart',
    'local_invoice_number_pattern',
    'offline_login_expiry_days',
    'allow_offline_returns',
    'sync_mode',
  };
}

/// Default config values for initial seed.
abstract final class PosConfigDefaults {
  static const Map<String, String> all = {
    PosConfigKeys.shiftDefaultDurationMinutes: '480',
    PosConfigKeys.shiftExtendMinutes: '30',
    PosConfigKeys.useHeldInvoices: 'true',
    PosConfigKeys.maxHeldInvoices: '20',
    PosConfigKeys.blockShiftCloseWithHeldInvoices: 'true',
    PosConfigKeys.priceIncludesTax: 'false',
    PosConfigKeys.requireCardReference: 'false',
    PosConfigKeys.autoPrintAfterSale: 'true',
  };
}
