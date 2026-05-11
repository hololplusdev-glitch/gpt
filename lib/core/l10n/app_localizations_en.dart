// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kasir Pro';

  @override
  String get posShort => 'Kasir';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get loginError => 'Invalid credentials';

  @override
  String get cashierSelectionOffline => 'Cashier Selection (Offline)';

  @override
  String get cashierSelectPrompt => 'Select your Backend user ID to begin';

  @override
  String get userIdOrLoginName => 'User ID or Login Name';

  @override
  String get selectCashier => 'Select Cashier';

  @override
  String get offlineUsersMustBeSynced =>
      'Offline mode - users must be synced from Backend.';

  @override
  String get passwordLoginPending =>
      'Password login will be available when Login API is ready.';

  @override
  String get cashierWorkspace => 'Cashier';

  @override
  String get salesHistory => 'Sales History';

  @override
  String get invoiceSearch => 'Invoice search';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get custom => 'Custom';

  @override
  String get filters => 'Filters';

  @override
  String get allCashiers => 'All cashiers';

  @override
  String get allPayments => 'All payments';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get netSales => 'Net Sales';

  @override
  String get transactions => 'Transactions';

  @override
  String get voidsAndReturns => 'Voids & Returns';

  @override
  String get noSalesInRange => 'No sales in this range';

  @override
  String get settings => 'Settings';

  @override
  String get setup => 'Setup';

  @override
  String get search => 'Search';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get scanBarcode => 'Scan Barcode';

  @override
  String scanAddedProduct(String productName) {
    return '$productName added';
  }

  @override
  String scanAddedProductQuantity(String productName, int quantity) {
    return '$productName (x$quantity)';
  }

  @override
  String noPriceForProduct(String productName) {
    return '$productName: no price';
  }

  @override
  String get barcodeScanFailed => 'Barcode scan failed.';

  @override
  String get scannerStartFailed => 'Unable to start scanner.';

  @override
  String get cameraStartFailed => 'Unable to start camera.';

  @override
  String get scanAddedItem => 'Item added';

  @override
  String scanAddedItemQuantity(int quantity) {
    return 'Item added ($quantity)';
  }

  @override
  String get barcodeNotFoundCatalog => 'Barcode was not found in the catalog.';

  @override
  String get scanNoPriceCurrentStore =>
      'This item is not sellable in the current device store.';

  @override
  String get toggleFlash => 'Toggle flash';

  @override
  String get closeScanner => 'Close scanner';

  @override
  String get pointCameraBarcode => 'Point the camera at the barcode';

  @override
  String scannedItemsCount(int count) {
    return '$count items scanned';
  }

  @override
  String get cameraPermissionDenied =>
      'Camera permission was not granted. Enable camera permission from device settings.';

  @override
  String get cart => 'Cart';

  @override
  String cartWithCount(int count) {
    return 'Cart ($count)';
  }

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get cartEmptyNothingToHold => 'Cart is empty - nothing to hold';

  @override
  String get tapProductsToAdd => 'Tap products to add them';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get removeFromCart => 'Remove';

  @override
  String get quantity => 'Qty';

  @override
  String get price => 'Price';

  @override
  String get discount => 'Discount';

  @override
  String discountAmountLabel(String amount) {
    return '-$amount discount';
  }

  @override
  String get priceOverridden => 'Price overridden';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get vat => 'VAT';

  @override
  String get tax => 'Tax';

  @override
  String get total => 'Total';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get pay => 'Pay';

  @override
  String get cash => 'Cash';

  @override
  String get card => 'Card';

  @override
  String get mixed => 'Mixed';

  @override
  String get change => 'Change';

  @override
  String invoiceNumberLabel(String invoiceNo) {
    return 'Invoice: $invoiceNo';
  }

  @override
  String get tendered => 'Tendered';

  @override
  String get amountTenderedSar => 'Amount Tendered (SAR)';

  @override
  String get exact => 'Exact';

  @override
  String get receipt => 'Receipt';

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String get reprintReceipt => 'Reprint Receipt';

  @override
  String get holdOrder => 'Hold Order';

  @override
  String get hold => 'Hold';

  @override
  String get orderHeldSuccessfully => 'Order held successfully';

  @override
  String get recallOrder => 'Recall Order';

  @override
  String get heldOrders => 'Held Orders';

  @override
  String get voidSale => 'Void';

  @override
  String get returnSale => 'Return';

  @override
  String get customer => 'Customer';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get noCustomer => 'Walk-in Customer';

  @override
  String get notes => 'Notes';

  @override
  String get priceOverride => 'Price Override';

  @override
  String get discountOverride => 'Discount Override';

  @override
  String get supervisorApproval => 'Supervisor Approval';

  @override
  String get enterSupervisorPin => 'Enter supervisor PIN';

  @override
  String get approved => 'Approved';

  @override
  String get denied => 'Denied';

  @override
  String get connection => 'Connection';

  @override
  String get devices => 'Devices';

  @override
  String get printer => 'Printer';

  @override
  String get payment => 'Payment';

  @override
  String get paymentTerminal => 'Payment Terminal';

  @override
  String get barcodeScanner => 'Barcode Scanner';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get syncMonitor => 'Data Update & Upload';

  @override
  String get pendingUpload => 'Pending upload';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get downloading => 'Updating operating data...';

  @override
  String get downloadMasterData => 'Update Operating Data';

  @override
  String get pendingInvoiceUploadUnavailable =>
      'Pending invoice upload is currently unavailable';

  @override
  String masterDataDownloadSummary(int rows, int failedGroups) {
    return 'Operating data updated: $rows rows, Failed groups: $failedGroups';
  }

  @override
  String get syncNotConfigured =>
      'API client is not configured. Run setup first.';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get backendApi => 'Backend ORDS';

  @override
  String get notConnectedOfflineMode => 'Not connected - offline mode';

  @override
  String get pending => 'Pending';

  @override
  String get synced => 'Synced';

  @override
  String get failed => 'Failed';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get bootingPos => 'Starting Kasir Pro';

  @override
  String get branch => 'Branch';

  @override
  String get station => 'Station';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get healthCheck => 'Health Check';

  @override
  String get firstRunTitle => 'Welcome to Kasir Pro';

  @override
  String get firstRunSubtitle => 'Let\'s configure your point-of-sale station';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Finish';

  @override
  String get skip => 'Skip';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get loading => 'Loading...';

  @override
  String get noResults => 'No results found';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get allCategories => 'All';

  @override
  String get quoteError => 'Quote error';

  @override
  String get viewCart => 'View Cart';

  @override
  String get searchProductsOrScanBarcode =>
      'Search products or scan barcode...';

  @override
  String get unableToAddItemToCart => 'Unable to add item to cart.';

  @override
  String get unableToPrepareCheckoutTotal =>
      'Unable to prepare checkout total.';

  @override
  String get noOpenShiftCannotProcessPayment =>
      'No open shift. Cannot process payment.';

  @override
  String get noActivePaymentMethodConfigured =>
      'No active payment method is configured.';

  @override
  String get enterValidTenderedAmount => 'Enter a valid tendered amount.';

  @override
  String get insufficientAmountTendered => 'Insufficient amount tendered.';

  @override
  String get notAuthenticatedLoginAgain => 'Not authenticated. Please log in.';

  @override
  String get paymentReferenceRequired => 'Payment reference is required.';

  @override
  String get paymentCouldNotBeCompleted => 'Payment could not be completed.';

  @override
  String get saleSavedPrintQueued =>
      'Sale saved, print failed and was queued for retry.';

  @override
  String get completePayment => 'Complete Payment';

  @override
  String get recordCardPayment => 'Record Card Payment (Manual)';

  @override
  String get recordBankPayment => 'Record Bank Payment';

  @override
  String get recordPayment => 'Record Payment';

  @override
  String get paymentSuccessful => 'Payment Successful';

  @override
  String get doneNewSale => 'Done - New Sale';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get currency => 'SAR';

  @override
  String get todaySales => 'Today\'s Sales';

  @override
  String get averageValue => 'Avg. Value';

  @override
  String get noSalesToday => 'No sales today';

  @override
  String saleCashierLine(String time, String cashier) {
    return '$time - $cashier';
  }

  @override
  String get invoiceTypeSales => 'Sales Invoice';

  @override
  String get printStatusNotPrinted => 'Not printed';

  @override
  String get printStatusPrinted => 'Printed';

  @override
  String get printStatusFailed => 'Print failed';

  @override
  String get printStatusPending => 'Waiting for print';

  @override
  String get arabicPrintNotice =>
      'Arabic ESC/POS text support depends on the printer code page.';

  @override
  String get saleId => 'Sale ID';

  @override
  String get receiptNumber => 'Receipt #';

  @override
  String get date => 'Date';

  @override
  String get status => 'Status';

  @override
  String get completed => 'Completed';

  @override
  String get draft => 'Draft';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get rejected => 'Rejected';

  @override
  String get voided => 'Voided';

  @override
  String get returned => 'Returned';

  @override
  String get held => 'Held';

  @override
  String get active => 'Active';

  @override
  String get openShift => 'Open Shift';

  @override
  String get closeShift => 'Close Shift';

  @override
  String get backToPos => 'Back to POS';

  @override
  String get openNewShift => 'Open New Shift';

  @override
  String cashierNameLabel(String name) {
    return 'Cashier: $name';
  }

  @override
  String get unknownCashier => 'Unknown';

  @override
  String get openingCashSar => 'Opening Cash (SAR)';

  @override
  String get zeroAmountHint => '0.00';

  @override
  String get openingShift => 'Opening...';

  @override
  String openedAtLabel(String dateTime) {
    return 'Opened: $dateTime';
  }

  @override
  String get openingCash => 'Opening Cash';

  @override
  String get sales => 'Sales';

  @override
  String get grossSales => 'Gross Sales';

  @override
  String get actualCashInDrawerSar => 'Actual Cash in Drawer (SAR)';

  @override
  String get closingNotesOptional => 'Closing notes (optional)';

  @override
  String get closingShift => 'Closing...';

  @override
  String get clearCart => 'Clear Cart';

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String amountFormat(String amount) {
    return '$amount SAR';
  }

  @override
  String get posDevices => 'POS Devices';

  @override
  String get posConfigIncomplete =>
      'Point-of-sale configuration is incomplete. Review settings or POS devices before selling.';

  @override
  String get printers => 'Printers';

  @override
  String get searchNetwork => 'Search network';

  @override
  String get addPrinter => 'Add printer';

  @override
  String get editPrinter => 'Edit printer';

  @override
  String get deletePrinter => 'Delete printer';

  @override
  String deletePrinterConfirmation(String name) {
    return 'Delete $name? This printer will be removed from this station.';
  }

  @override
  String get noPrintersConfigured => 'No printers configured';

  @override
  String get addCashierOrKitchenPrinter =>
      'Add a cashier or kitchen Network/IP printer.';

  @override
  String get unableToLoadPrinters => 'Unable to load printers.';

  @override
  String get unableToLoadPaymentProfile => 'Unable to load payment settings.';

  @override
  String get test => 'Test';

  @override
  String get testPrint => 'Test print';

  @override
  String get testPrintSucceeded => 'Test print succeeded.';

  @override
  String get testPrintFailed => 'Test print failed.';

  @override
  String get printerUpdateFailed => 'Unable to update printer.';

  @override
  String get printerDeleteFailed => 'Unable to delete printer.';

  @override
  String get printerSaveFailed => 'Unable to save printer.';

  @override
  String get networkPrinter => 'Network/IP ESC-POS';

  @override
  String get systemPrinter => 'System Printer';

  @override
  String get bluetoothPrinter => 'Bluetooth ESC-POS';

  @override
  String get usbPrinter => 'USB ESC-POS';

  @override
  String get androidBuiltIn => 'Android Built-in';

  @override
  String get enableCardPayment => 'Enable card/network payment';

  @override
  String get checkoutChoosesPaymentPerSale =>
      'Checkout still decides Cash or Card per sale.';

  @override
  String get requireReference => 'Require reference for manual card';

  @override
  String get referenceRequired => 'Reference required';

  @override
  String get integratedMode => 'Integrated mode';

  @override
  String get savePaymentProfile => 'Save Payment Profile';

  @override
  String get readiness => 'Readiness';

  @override
  String get saleReadiness => 'Sale readiness';

  @override
  String get cashierPrinter => 'Cashier Printer';

  @override
  String get kitchenPrinter => 'Kitchen Printer';

  @override
  String get manualCard => 'Manual card';

  @override
  String get disabled => 'Disabled';

  @override
  String get missing => 'Missing';

  @override
  String get untested => 'Untested';

  @override
  String get ready => 'Ready';

  @override
  String get unsupported => 'Unsupported';

  @override
  String get retryableJobs => 'Retryable print jobs';

  @override
  String retryFailedJobs(int count) {
    return 'Retry $count failed print jobs';
  }

  @override
  String get allowed => 'Allowed';

  @override
  String get allowedPrintWarning => 'Allowed (Print Warning)';

  @override
  String get allowedKitchenWarning => 'Allowed (Kitchen Warning)';

  @override
  String get noCard => 'No Card';

  @override
  String get retryQueuedJobsProcessed => 'Retryable print jobs processed.';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get cardPaymentNotConfigured => 'Card payment is not configured.';

  @override
  String get integratedNotAvailable => 'Integrated payment is unavailable.';

  @override
  String get searchNetworkPrinters => 'Search Network Printers';

  @override
  String get subnetPrefixExample => 'Subnet prefix (e.g. 192.168.1)';

  @override
  String scanningPort(int port) {
    return 'Scanning port $port...';
  }

  @override
  String get networkPrinterSearchHint =>
      'Enter subnet and tap Search to scan for ESC/POS printers on port 9100.';

  @override
  String portNumber(int port) {
    return 'Port $port';
  }

  @override
  String get close => 'Close';

  @override
  String get networkSearchFailed => 'Network printer search failed.';

  @override
  String get cashierRole => 'Cashier';

  @override
  String get kitchenRole => 'Kitchen';

  @override
  String get printerName => 'Printer name';

  @override
  String get ipAddress => 'IP address';

  @override
  String get paperWidth => 'Paper width:';

  @override
  String paperWidthMm(int width) {
    return '${width}mm';
  }

  @override
  String get copies => 'Copies:';

  @override
  String get autoPrintAfterSale => 'Auto-print after sale';

  @override
  String get enablePrinter => 'Enable printer';

  @override
  String get mustBeTestedSuccessfullyFirst =>
      'Must be tested successfully first';

  @override
  String lastTestedAt(String dateTime) {
    return 'Last tested: $dateTime';
  }

  @override
  String get testing => 'Testing...';

  @override
  String get paymentReference => 'Payment reference';

  @override
  String get recordApprovedRef =>
      'Manual card/bank record. Enter the customer receipt reference if available.';

  @override
  String get posSetup => 'Kasir Pro Setup';

  @override
  String get languageLabel => 'Language';

  @override
  String get serverIdentity => 'Server and Backend identity';

  @override
  String get initialReadiness => 'Initial readiness';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get fullUrlMode => 'Full URL mode';

  @override
  String get fullUrlSubtitle => 'Paste the Backend API base URL directly';

  @override
  String get apiBaseUrl => 'API Base URL';

  @override
  String get apiBaseUrlExample =>
      'https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1';

  @override
  String get baseUrlHint => 'Base URL without /data';

  @override
  String get hostOrIp => 'Host / IP';

  @override
  String get optional => 'optional';

  @override
  String get apiBasePath => 'API Base Path';

  @override
  String get apiBasePathExample => '/ords/erp/pos-api/v1';

  @override
  String get https => 'HTTPS';

  @override
  String get customerCode => 'Customer Code';

  @override
  String get userId => 'Backend User ID';

  @override
  String get branchNumber => 'Branch Number (braNbr)';

  @override
  String get branchNumberHint => 'Also used as Branch ID';

  @override
  String get machineNumber => 'Machine Number (mchnNbr)';

  @override
  String get machineNumberHint => 'Also used as Station ID';

  @override
  String get setupSuccess =>
      'Server and Backend identity configured successfully';

  @override
  String get setupPrintersLater =>
      'Printers and payment are configured later in POS Devices';

  @override
  String get cancelSync => 'Cancel Sync';

  @override
  String get preparing => 'Preparing...';

  @override
  String get enterApiBaseUrl => 'Enter the API base URL.';

  @override
  String get serverCheckFailedFixConnection =>
      'Server check failed. Fix the connection before proceeding.';

  @override
  String get setupUnexpectedError =>
      'Setup could not continue. Review the entered connection details and try again.';

  @override
  String get syncingData => 'Syncing data...';

  @override
  String syncingDataPercent(int percent) {
    return 'Syncing data... $percent%';
  }

  @override
  String get serverConnection => 'Server Connection';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get terminalIdentity => 'Backend Identity';

  @override
  String backendIdentitySummary(
    String custCode,
    String branch,
    String machine,
  ) {
    return 'CustCode: $custCode  |  Branch: $branch  |  Machine: $machine';
  }

  @override
  String get posDevicesSubtitle => 'Printers, manual card payment, readiness';

  @override
  String get general => 'General';

  @override
  String get about => 'About';

  @override
  String versionLabel(String version) {
    return 'Kasir Pro v$version';
  }

  @override
  String get applicationLegalese2026 =>
      '© 2026 Extra Solutions. All rights reserved.';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get resetSetup => 'Reset Setup';

  @override
  String get resetSetupSubtitle => 'Re-run first-time connection setup';

  @override
  String get resetSetupQuestion => 'Reset Setup?';

  @override
  String get resetSetupWarning =>
      'This clears first-run connection setup and requires a new server connection and full data sync. Your sales, shifts, and sale history are preserved.';

  @override
  String get reset => 'Reset';

  @override
  String pdfInvoiceTitle(String invoiceNo) {
    return 'Invoice $invoiceNo';
  }

  @override
  String get simplifiedTaxInvoice => 'Simplified Tax Invoice';

  @override
  String get taxNumber => 'Tax Number';

  @override
  String get commercialRegistration => 'Commercial Registration';

  @override
  String get terminal => 'Terminal';

  @override
  String get item => 'Item';

  @override
  String get unitPrice => 'Unit Price';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get reference => 'Reference';

  @override
  String get amount => 'Amount';

  @override
  String get beforeTaxTotal => 'Subtotal before tax';

  @override
  String get paid => 'Paid';

  @override
  String receiptInvoiceTitle(String invoiceNo) {
    return 'Invoice $invoiceNo';
  }

  @override
  String get cashier => 'Cashier';

  @override
  String get noEnabledPrinter => 'No enabled printer.';

  @override
  String get invoiceSavedButPrintFailed =>
      'Invoice was saved, but printing failed.';

  @override
  String get invoiceSentToPrinter => 'Invoice was sent to the printer.';

  @override
  String get viewInvoice => 'View Invoice';

  @override
  String get savePdf => 'Save PDF';

  @override
  String pdfSavedAt(String path) {
    return 'PDF file saved: $path';
  }

  @override
  String get ownerConsole => 'Owner Console';

  @override
  String get exit => 'Exit';

  @override
  String get ownerTools => 'Owner Tools';

  @override
  String get ownerConsoleReadOnlyNotice =>
      'This screen is read-only. No data can be edited or deleted.';

  @override
  String get localTables => 'Local Tables';

  @override
  String get localTablesSubtitle =>
      'View tables, columns, and rows exactly as stored in the local database';

  @override
  String get diagnosticFilters => 'Diagnostic Filters';

  @override
  String get diagnosticFiltersSubtitle =>
      'Coming later: sales without invoices, stuck outbox, failed prints...';

  @override
  String failedToLoadTables(String error) {
    return 'Failed to load tables: $error';
  }

  @override
  String get noTables => 'No tables';

  @override
  String get selectTableRawData => 'Select a table to view its raw data';

  @override
  String failedToLoadTableRows(String error) {
    return 'Failed to load table rows: $error';
  }

  @override
  String get rowCopiedAsJson => 'Row copied as JSON';

  @override
  String get copyRowJson => 'Copy Row JSON';

  @override
  String get noRows => 'No rows';

  @override
  String rowsRange(String tableName, int from, int to, int total) {
    return '$tableName — Rows $from-$to of $total';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get noPricedProductsForDeviceStore =>
      'No priced products for this device/store.';

  @override
  String storeAndPriceLevelDetails(String storeId, String priceLevelId) {
    return 'Store: $storeId\nPrice level: $priceLevelId';
  }

  @override
  String get noPriceForCurrentStorePriceLevel =>
      'No price exists for this item in the current store and price level.';

  @override
  String get noPrice => 'No price';

  @override
  String get errorLoading => 'Error loading';

  @override
  String get scannedItemNotSellableInCurrentStore =>
      'This item is not sellable in the current device store.';

  @override
  String get searchInvoiceOrProduct => 'Search invoice or product';

  @override
  String get products => 'Products';

  @override
  String get noSalesFound => 'No matching sales';

  @override
  String get recentSales => 'Recent Sales';

  @override
  String get saleRows => 'Sale rows';

  @override
  String get invoice => 'Invoice';
}
