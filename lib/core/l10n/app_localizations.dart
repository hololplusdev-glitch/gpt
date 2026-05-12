import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kasir Pro'**
  String get appTitle;

  /// No description provided for @posShort.
  ///
  /// In en, this message translates to:
  /// **'Kasir'**
  String get posShort;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get loginError;

  /// No description provided for @cashierSelectionOffline.
  ///
  /// In en, this message translates to:
  /// **'Cashier Selection (Offline)'**
  String get cashierSelectionOffline;

  /// No description provided for @cashierSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select your Backend user ID to begin'**
  String get cashierSelectPrompt;

  /// No description provided for @userIdOrLoginName.
  ///
  /// In en, this message translates to:
  /// **'User ID or Login Name'**
  String get userIdOrLoginName;

  /// No description provided for @selectCashier.
  ///
  /// In en, this message translates to:
  /// **'Select Cashier'**
  String get selectCashier;

  /// No description provided for @offlineUsersMustBeSynced.
  ///
  /// In en, this message translates to:
  /// **'Offline mode - users must be synced from Backend.'**
  String get offlineUsersMustBeSynced;

  /// No description provided for @passwordLoginPending.
  ///
  /// In en, this message translates to:
  /// **'Password login will be available when Login API is ready.'**
  String get passwordLoginPending;

  /// No description provided for @cashierWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierWorkspace;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistory;

  /// No description provided for @invoiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Invoice search'**
  String get invoiceSearch;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @allCashiers.
  ///
  /// In en, this message translates to:
  /// **'All cashiers'**
  String get allCashiers;

  /// No description provided for @allPayments.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get allPayments;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @netSales.
  ///
  /// In en, this message translates to:
  /// **'Net Sales'**
  String get netSales;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @voidsAndReturns.
  ///
  /// In en, this message translates to:
  /// **'Voids & Returns'**
  String get voidsAndReturns;

  /// No description provided for @noSalesInRange.
  ///
  /// In en, this message translates to:
  /// **'No sales in this range'**
  String get noSalesInRange;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode'**
  String get scanBarcode;

  /// No description provided for @scanAddedProduct.
  ///
  /// In en, this message translates to:
  /// **'{productName} added'**
  String scanAddedProduct(String productName);

  /// No description provided for @scanAddedProductQuantity.
  ///
  /// In en, this message translates to:
  /// **'{productName} (x{quantity})'**
  String scanAddedProductQuantity(String productName, int quantity);

  /// No description provided for @noPriceForProduct.
  ///
  /// In en, this message translates to:
  /// **'{productName}: no price'**
  String noPriceForProduct(String productName);

  /// No description provided for @barcodeScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Barcode scan failed.'**
  String get barcodeScanFailed;

  /// No description provided for @scannerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start scanner.'**
  String get scannerStartFailed;

  /// No description provided for @cameraStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start camera.'**
  String get cameraStartFailed;

  /// No description provided for @scanAddedItem.
  ///
  /// In en, this message translates to:
  /// **'Item added'**
  String get scanAddedItem;

  /// No description provided for @scanAddedItemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Item added ({quantity})'**
  String scanAddedItemQuantity(int quantity);

  /// No description provided for @barcodeNotFoundCatalog.
  ///
  /// In en, this message translates to:
  /// **'Barcode was not found in the catalog.'**
  String get barcodeNotFoundCatalog;

  /// No description provided for @scanNoPriceCurrentStore.
  ///
  /// In en, this message translates to:
  /// **'This item is not sellable in the current device store.'**
  String get scanNoPriceCurrentStore;

  /// No description provided for @toggleFlash.
  ///
  /// In en, this message translates to:
  /// **'Toggle flash'**
  String get toggleFlash;

  /// No description provided for @closeScanner.
  ///
  /// In en, this message translates to:
  /// **'Close scanner'**
  String get closeScanner;

  /// No description provided for @pointCameraBarcode.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode'**
  String get pointCameraBarcode;

  /// No description provided for @scannedItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items scanned'**
  String scannedItemsCount(int count);

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission was not granted. Enable camera permission from device settings.'**
  String get cameraPermissionDenied;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartWithCount.
  ///
  /// In en, this message translates to:
  /// **'Cart ({count})'**
  String cartWithCount(int count);

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartEmptyNothingToHold.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty - nothing to hold'**
  String get cartEmptyNothingToHold;

  /// No description provided for @tapProductsToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap products to add them'**
  String get tapProductsToAdd;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @removeFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFromCart;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @discountAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'-{amount} discount'**
  String discountAmountLabel(String amount);

  /// No description provided for @priceOverridden.
  ///
  /// In en, this message translates to:
  /// **'Price overridden'**
  String get priceOverridden;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vat;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixed;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @invoiceNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice: {invoiceNo}'**
  String invoiceNumberLabel(String invoiceNo);

  /// No description provided for @tendered.
  ///
  /// In en, this message translates to:
  /// **'Tendered'**
  String get tendered;

  /// No description provided for @amountTenderedSar.
  ///
  /// In en, this message translates to:
  /// **'Amount Tendered (SAR)'**
  String get amountTenderedSar;

  /// No description provided for @exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get exact;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @reprintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reprint Receipt'**
  String get reprintReceipt;

  /// No description provided for @holdOrder.
  ///
  /// In en, this message translates to:
  /// **'Hold Order'**
  String get holdOrder;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @orderHeldSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order held successfully'**
  String get orderHeldSuccessfully;

  /// No description provided for @recallOrder.
  ///
  /// In en, this message translates to:
  /// **'Recall Order'**
  String get recallOrder;

  /// No description provided for @heldOrders.
  ///
  /// In en, this message translates to:
  /// **'Held Orders'**
  String get heldOrders;

  /// No description provided for @voidSale.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get voidSale;

  /// No description provided for @returnSale.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnSale;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @noCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in Customer'**
  String get noCustomer;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @priceOverride.
  ///
  /// In en, this message translates to:
  /// **'Price Override'**
  String get priceOverride;

  /// No description provided for @discountOverride.
  ///
  /// In en, this message translates to:
  /// **'Discount Override'**
  String get discountOverride;

  /// No description provided for @supervisorApproval.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Approval'**
  String get supervisorApproval;

  /// No description provided for @enterSupervisorPin.
  ///
  /// In en, this message translates to:
  /// **'Enter supervisor PIN'**
  String get enterSupervisorPin;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @denied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get denied;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @printer.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printer;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentTerminal.
  ///
  /// In en, this message translates to:
  /// **'Payment Terminal'**
  String get paymentTerminal;

  /// No description provided for @barcodeScanner.
  ///
  /// In en, this message translates to:
  /// **'Barcode Scanner'**
  String get barcodeScanner;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// No description provided for @syncMonitor.
  ///
  /// In en, this message translates to:
  /// **'Sync Monitor'**
  String get syncMonitor;

  /// No description provided for @pendingUpload.
  ///
  /// In en, this message translates to:
  /// **'Pending upload'**
  String get pendingUpload;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadMasterData.
  ///
  /// In en, this message translates to:
  /// **'Download Master Data'**
  String get downloadMasterData;

  /// No description provided for @pendingInvoiceUploadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Pending Invoice Upload - API not documented'**
  String get pendingInvoiceUploadUnavailable;

  /// No description provided for @masterDataDownloadSummary.
  ///
  /// In en, this message translates to:
  /// **'Master data downloaded: {rows} rows, Failed groups: {failedGroups}'**
  String masterDataDownloadSummary(int rows, int failedGroups);

  /// No description provided for @syncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'API client is not configured. Run setup first.'**
  String get syncNotConfigured;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// No description provided for @backendApi.
  ///
  /// In en, this message translates to:
  /// **'Backend ORDS'**
  String get backendApi;

  /// No description provided for @notConnectedOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Not connected - offline mode'**
  String get notConnectedOfflineMode;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @bootingPos.
  ///
  /// In en, this message translates to:
  /// **'Starting Kasir Pro'**
  String get bootingPos;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @station.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get station;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @healthCheck.
  ///
  /// In en, this message translates to:
  /// **'Health Check'**
  String get healthCheck;

  /// No description provided for @firstRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kasir Pro'**
  String get firstRunTitle;

  /// No description provided for @firstRunSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s configure your point-of-sale station'**
  String get firstRunSubtitle;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @quoteError.
  ///
  /// In en, this message translates to:
  /// **'Quote error'**
  String get quoteError;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @searchProductsOrScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Search products or scan barcode...'**
  String get searchProductsOrScanBarcode;

  /// No description provided for @unableToAddItemToCart.
  ///
  /// In en, this message translates to:
  /// **'Unable to add item to cart.'**
  String get unableToAddItemToCart;

  /// No description provided for @unableToPrepareCheckoutTotal.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare checkout total.'**
  String get unableToPrepareCheckoutTotal;

  /// No description provided for @noOpenShiftCannotProcessPayment.
  ///
  /// In en, this message translates to:
  /// **'No open shift. Cannot process payment.'**
  String get noOpenShiftCannotProcessPayment;

  /// No description provided for @noActivePaymentMethodConfigured.
  ///
  /// In en, this message translates to:
  /// **'No active payment method is configured.'**
  String get noActivePaymentMethodConfigured;

  /// No description provided for @enterValidTenderedAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid tendered amount.'**
  String get enterValidTenderedAmount;

  /// No description provided for @insufficientAmountTendered.
  ///
  /// In en, this message translates to:
  /// **'Insufficient amount tendered.'**
  String get insufficientAmountTendered;

  /// No description provided for @notAuthenticatedLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated. Please log in.'**
  String get notAuthenticatedLoginAgain;

  /// No description provided for @paymentReferenceRequired.
  ///
  /// In en, this message translates to:
  /// **'Payment reference is required.'**
  String get paymentReferenceRequired;

  /// No description provided for @paymentCouldNotBeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be completed.'**
  String get paymentCouldNotBeCompleted;

  /// No description provided for @saleSavedPrintQueued.
  ///
  /// In en, this message translates to:
  /// **'Sale saved, print failed and was queued for retry.'**
  String get saleSavedPrintQueued;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// Button label clarifying this is a manual card payment record
  ///
  /// In en, this message translates to:
  /// **'Record Card Payment (Manual)'**
  String get recordCardPayment;

  /// No description provided for @recordBankPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Bank Payment'**
  String get recordBankPayment;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPayment;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccessful;

  /// No description provided for @doneNewSale.
  ///
  /// In en, this message translates to:
  /// **'Done - New Sale'**
  String get doneNewSale;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currency;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sales'**
  String get todaySales;

  /// No description provided for @averageValue.
  ///
  /// In en, this message translates to:
  /// **'Avg. Value'**
  String get averageValue;

  /// No description provided for @noSalesToday.
  ///
  /// In en, this message translates to:
  /// **'No sales today'**
  String get noSalesToday;

  /// No description provided for @saleCashierLine.
  ///
  /// In en, this message translates to:
  /// **'{time} - {cashier}'**
  String saleCashierLine(String time, String cashier);

  /// No description provided for @invoiceTypeSales.
  ///
  /// In en, this message translates to:
  /// **'Sales Invoice'**
  String get invoiceTypeSales;

  /// No description provided for @printStatusNotPrinted.
  ///
  /// In en, this message translates to:
  /// **'Not printed'**
  String get printStatusNotPrinted;

  /// No description provided for @printStatusPrinted.
  ///
  /// In en, this message translates to:
  /// **'Printed'**
  String get printStatusPrinted;

  /// No description provided for @printStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed'**
  String get printStatusFailed;

  /// No description provided for @printStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for print'**
  String get printStatusPending;

  /// No description provided for @arabicPrintNotice.
  ///
  /// In en, this message translates to:
  /// **'Arabic ESC/POS text support depends on the printer code page.'**
  String get arabicPrintNotice;

  /// No description provided for @saleId.
  ///
  /// In en, this message translates to:
  /// **'Sale ID'**
  String get saleId;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt #'**
  String get receiptNumber;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @voided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get voided;

  /// No description provided for @returned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get returned;

  /// No description provided for @held.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get held;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @openShift.
  ///
  /// In en, this message translates to:
  /// **'Open Shift'**
  String get openShift;

  /// No description provided for @closeShift.
  ///
  /// In en, this message translates to:
  /// **'Close Shift'**
  String get closeShift;

  /// No description provided for @backToPos.
  ///
  /// In en, this message translates to:
  /// **'Back to POS'**
  String get backToPos;

  /// No description provided for @openNewShift.
  ///
  /// In en, this message translates to:
  /// **'Open New Shift'**
  String get openNewShift;

  /// No description provided for @cashierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier: {name}'**
  String cashierNameLabel(String name);

  /// No description provided for @unknownCashier.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownCashier;

  /// No description provided for @openingCashSar.
  ///
  /// In en, this message translates to:
  /// **'Opening Cash (SAR)'**
  String get openingCashSar;

  /// No description provided for @zeroAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get zeroAmountHint;

  /// No description provided for @openingShift.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get openingShift;

  /// No description provided for @openedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Opened: {dateTime}'**
  String openedAtLabel(String dateTime);

  /// No description provided for @openingCash.
  ///
  /// In en, this message translates to:
  /// **'Opening Cash'**
  String get openingCash;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @grossSales.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get grossSales;

  /// No description provided for @actualCashInDrawerSar.
  ///
  /// In en, this message translates to:
  /// **'Actual Cash in Drawer (SAR)'**
  String get actualCashInDrawerSar;

  /// No description provided for @closingNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Closing notes (optional)'**
  String get closingNotesOptional;

  /// No description provided for @closingShift.
  ///
  /// In en, this message translates to:
  /// **'Closing...'**
  String get closingShift;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get clearCart;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(int count);

  /// No description provided for @amountFormat.
  ///
  /// In en, this message translates to:
  /// **'{amount} SAR'**
  String amountFormat(String amount);

  /// No description provided for @posDevices.
  ///
  /// In en, this message translates to:
  /// **'POS Devices'**
  String get posDevices;

  /// No description provided for @posConfigIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Point-of-sale configuration is incomplete. Review settings or POS devices before selling.'**
  String get posConfigIncomplete;

  /// No description provided for @printers.
  ///
  /// In en, this message translates to:
  /// **'Printers'**
  String get printers;

  /// No description provided for @searchNetwork.
  ///
  /// In en, this message translates to:
  /// **'Search network'**
  String get searchNetwork;

  /// No description provided for @addPrinter.
  ///
  /// In en, this message translates to:
  /// **'Add printer'**
  String get addPrinter;

  /// No description provided for @editPrinter.
  ///
  /// In en, this message translates to:
  /// **'Edit printer'**
  String get editPrinter;

  /// No description provided for @deletePrinter.
  ///
  /// In en, this message translates to:
  /// **'Delete printer'**
  String get deletePrinter;

  /// No description provided for @deletePrinterConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This printer will be removed from this station.'**
  String deletePrinterConfirmation(String name);

  /// No description provided for @noPrintersConfigured.
  ///
  /// In en, this message translates to:
  /// **'No printers configured'**
  String get noPrintersConfigured;

  /// No description provided for @addCashierOrKitchenPrinter.
  ///
  /// In en, this message translates to:
  /// **'Add a cashier or kitchen Network/IP printer.'**
  String get addCashierOrKitchenPrinter;

  /// No description provided for @unableToLoadPrinters.
  ///
  /// In en, this message translates to:
  /// **'Unable to load printers.'**
  String get unableToLoadPrinters;

  /// No description provided for @unableToLoadPaymentProfile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load payment settings.'**
  String get unableToLoadPaymentProfile;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @testPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get testPrint;

  /// No description provided for @testPrintSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Test print succeeded.'**
  String get testPrintSucceeded;

  /// No description provided for @testPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Test print failed.'**
  String get testPrintFailed;

  /// No description provided for @printerUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update printer.'**
  String get printerUpdateFailed;

  /// No description provided for @printerDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete printer.'**
  String get printerDeleteFailed;

  /// No description provided for @printerSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save printer.'**
  String get printerSaveFailed;

  /// No description provided for @networkPrinter.
  ///
  /// In en, this message translates to:
  /// **'Network/IP ESC-POS'**
  String get networkPrinter;

  /// No description provided for @systemPrinter.
  ///
  /// In en, this message translates to:
  /// **'System Printer'**
  String get systemPrinter;

  /// No description provided for @bluetoothPrinter.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth ESC-POS'**
  String get bluetoothPrinter;

  /// No description provided for @enableCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Enable card/network payment'**
  String get enableCardPayment;

  /// No description provided for @checkoutChoosesPaymentPerSale.
  ///
  /// In en, this message translates to:
  /// **'Checkout still decides Cash or Card per sale.'**
  String get checkoutChoosesPaymentPerSale;

  /// No description provided for @requireReference.
  ///
  /// In en, this message translates to:
  /// **'Require reference for manual card'**
  String get requireReference;

  /// No description provided for @referenceRequired.
  ///
  /// In en, this message translates to:
  /// **'Reference required'**
  String get referenceRequired;

  /// No description provided for @savePaymentProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Payment Profile'**
  String get savePaymentProfile;

  /// No description provided for @readiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get readiness;

  /// No description provided for @saleReadiness.
  ///
  /// In en, this message translates to:
  /// **'Sale readiness'**
  String get saleReadiness;

  /// No description provided for @cashierPrinter.
  ///
  /// In en, this message translates to:
  /// **'Cashier Printer'**
  String get cashierPrinter;

  /// No description provided for @kitchenPrinter.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Printer'**
  String get kitchenPrinter;

  /// No description provided for @manualCard.
  ///
  /// In en, this message translates to:
  /// **'Manual card'**
  String get manualCard;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @untested.
  ///
  /// In en, this message translates to:
  /// **'Untested'**
  String get untested;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get unsupported;

  /// No description provided for @retryableJobs.
  ///
  /// In en, this message translates to:
  /// **'Retryable print jobs'**
  String get retryableJobs;

  /// No description provided for @retryFailedJobs.
  ///
  /// In en, this message translates to:
  /// **'Retry {count} failed print jobs'**
  String retryFailedJobs(int count);

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @allowedPrintWarning.
  ///
  /// In en, this message translates to:
  /// **'Allowed (Print Warning)'**
  String get allowedPrintWarning;

  /// No description provided for @allowedKitchenWarning.
  ///
  /// In en, this message translates to:
  /// **'Allowed (Kitchen Warning)'**
  String get allowedKitchenWarning;

  /// No description provided for @noCard.
  ///
  /// In en, this message translates to:
  /// **'No Card'**
  String get noCard;

  /// No description provided for @retryQueuedJobsProcessed.
  ///
  /// In en, this message translates to:
  /// **'Retryable print jobs processed.'**
  String get retryQueuedJobsProcessed;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @cardPaymentNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Card payment is not configured.'**
  String get cardPaymentNotConfigured;

  /// No description provided for @searchNetworkPrinters.
  ///
  /// In en, this message translates to:
  /// **'Search Network Printers'**
  String get searchNetworkPrinters;

  /// No description provided for @subnetPrefixExample.
  ///
  /// In en, this message translates to:
  /// **'Subnet prefix (e.g. 192.168.1)'**
  String get subnetPrefixExample;

  /// No description provided for @scanningPort.
  ///
  /// In en, this message translates to:
  /// **'Scanning port {port}...'**
  String scanningPort(int port);

  /// No description provided for @networkPrinterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter subnet and tap Search to scan for ESC/POS printers on port 9100.'**
  String get networkPrinterSearchHint;

  /// No description provided for @portNumber.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String portNumber(int port);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @networkSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Network printer search failed.'**
  String get networkSearchFailed;

  /// No description provided for @cashierRole.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierRole;

  /// No description provided for @kitchenRole.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchenRole;

  /// No description provided for @printerName.
  ///
  /// In en, this message translates to:
  /// **'Printer name'**
  String get printerName;

  /// No description provided for @ipAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddress;

  /// No description provided for @paperWidth.
  ///
  /// In en, this message translates to:
  /// **'Paper width:'**
  String get paperWidth;

  /// No description provided for @paperWidthMm.
  ///
  /// In en, this message translates to:
  /// **'{width}mm'**
  String paperWidthMm(int width);

  /// No description provided for @copies.
  ///
  /// In en, this message translates to:
  /// **'Copies:'**
  String get copies;

  /// No description provided for @autoPrintAfterSale.
  ///
  /// In en, this message translates to:
  /// **'Auto-print after sale'**
  String get autoPrintAfterSale;

  /// No description provided for @enablePrinter.
  ///
  /// In en, this message translates to:
  /// **'Enable printer'**
  String get enablePrinter;

  /// No description provided for @mustBeTestedSuccessfullyFirst.
  ///
  /// In en, this message translates to:
  /// **'Must be tested successfully first'**
  String get mustBeTestedSuccessfullyFirst;

  /// No description provided for @lastTestedAt.
  ///
  /// In en, this message translates to:
  /// **'Last tested: {dateTime}'**
  String lastTestedAt(String dateTime);

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @paymentReference.
  ///
  /// In en, this message translates to:
  /// **'Payment reference'**
  String get paymentReference;

  /// No description provided for @recordApprovedRef.
  ///
  /// In en, this message translates to:
  /// **'Manual card/bank record. Enter the customer receipt reference if available.'**
  String get recordApprovedRef;

  /// No description provided for @posSetup.
  ///
  /// In en, this message translates to:
  /// **'Kasir Pro Setup'**
  String get posSetup;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @serverIdentity.
  ///
  /// In en, this message translates to:
  /// **'Server and Backend identity'**
  String get serverIdentity;

  /// No description provided for @initialReadiness.
  ///
  /// In en, this message translates to:
  /// **'Initial readiness'**
  String get initialReadiness;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @fullUrlMode.
  ///
  /// In en, this message translates to:
  /// **'Full URL mode'**
  String get fullUrlMode;

  /// No description provided for @fullUrlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste the Backend API base URL directly'**
  String get fullUrlSubtitle;

  /// No description provided for @apiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get apiBaseUrl;

  /// No description provided for @apiBaseUrlExample.
  ///
  /// In en, this message translates to:
  /// **'https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1'**
  String get apiBaseUrlExample;

  /// No description provided for @baseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Base URL without /data'**
  String get baseUrlHint;

  /// No description provided for @hostOrIp.
  ///
  /// In en, this message translates to:
  /// **'Host / IP'**
  String get hostOrIp;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @apiBasePath.
  ///
  /// In en, this message translates to:
  /// **'API Base Path'**
  String get apiBasePath;

  /// No description provided for @apiBasePathExample.
  ///
  /// In en, this message translates to:
  /// **'/ords/erp/pos-api/v1'**
  String get apiBasePathExample;

  /// No description provided for @https.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get https;

  /// No description provided for @customerCode.
  ///
  /// In en, this message translates to:
  /// **'Customer Code'**
  String get customerCode;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'Backend User ID'**
  String get userId;

  /// No description provided for @branchNumber.
  ///
  /// In en, this message translates to:
  /// **'Branch Number (braNbr)'**
  String get branchNumber;

  /// No description provided for @branchNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Also used as Branch ID'**
  String get branchNumberHint;

  /// No description provided for @machineNumber.
  ///
  /// In en, this message translates to:
  /// **'Machine Number (mchnNbr)'**
  String get machineNumber;

  /// No description provided for @machineNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Also used as Station ID'**
  String get machineNumberHint;

  /// No description provided for @setupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Server and Backend identity configured successfully'**
  String get setupSuccess;

  /// No description provided for @setupPrintersLater.
  ///
  /// In en, this message translates to:
  /// **'Printers and payment are configured later in POS Devices'**
  String get setupPrintersLater;

  /// No description provided for @cancelSync.
  ///
  /// In en, this message translates to:
  /// **'Cancel Sync'**
  String get cancelSync;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @enterApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the API base URL.'**
  String get enterApiBaseUrl;

  /// No description provided for @serverCheckFailedFixConnection.
  ///
  /// In en, this message translates to:
  /// **'Server check failed. Fix the connection before proceeding.'**
  String get serverCheckFailedFixConnection;

  /// No description provided for @setupUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Setup could not continue. Review the entered connection details and try again.'**
  String get setupUnexpectedError;

  /// No description provided for @syncingData.
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get syncingData;

  /// No description provided for @syncingDataPercent.
  ///
  /// In en, this message translates to:
  /// **'Syncing data... {percent}%'**
  String syncingDataPercent(int percent);

  /// No description provided for @serverConnection.
  ///
  /// In en, this message translates to:
  /// **'Server Connection'**
  String get serverConnection;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @terminalIdentity.
  ///
  /// In en, this message translates to:
  /// **'Backend Identity'**
  String get terminalIdentity;

  /// No description provided for @backendIdentitySummary.
  ///
  /// In en, this message translates to:
  /// **'CustCode: {custCode}  |  Branch: {branch}  |  Machine: {machine}'**
  String backendIdentitySummary(String custCode, String branch, String machine);

  /// No description provided for @posDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Printers, manual card payment, readiness'**
  String get posDevicesSubtitle;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Kasir Pro v{version}'**
  String versionLabel(String version);

  /// No description provided for @applicationLegalese2026.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Extra Solutions. All rights reserved.'**
  String get applicationLegalese2026;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @resetSetup.
  ///
  /// In en, this message translates to:
  /// **'Reset Setup'**
  String get resetSetup;

  /// No description provided for @resetSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-run first-time connection setup'**
  String get resetSetupSubtitle;

  /// No description provided for @resetSetupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset Setup?'**
  String get resetSetupQuestion;

  /// No description provided for @resetSetupWarning.
  ///
  /// In en, this message translates to:
  /// **'This clears first-run connection setup and requires a new server connection and full data sync. Your sales, shifts, and sale history are preserved.'**
  String get resetSetupWarning;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @pdfInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice {invoiceNo}'**
  String pdfInvoiceTitle(String invoiceNo);

  /// No description provided for @simplifiedTaxInvoice.
  ///
  /// In en, this message translates to:
  /// **'Simplified Tax Invoice'**
  String get simplifiedTaxInvoice;

  /// No description provided for @taxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax Number'**
  String get taxNumber;

  /// No description provided for @commercialRegistration.
  ///
  /// In en, this message translates to:
  /// **'Commercial Registration'**
  String get commercialRegistration;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get unitPrice;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @beforeTaxTotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal before tax'**
  String get beforeTaxTotal;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @receiptInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice {invoiceNo}'**
  String receiptInvoiceTitle(String invoiceNo);

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @noEnabledPrinter.
  ///
  /// In en, this message translates to:
  /// **'No enabled printer.'**
  String get noEnabledPrinter;

  /// No description provided for @invoiceSavedButPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Invoice was saved, but printing failed.'**
  String get invoiceSavedButPrintFailed;

  /// No description provided for @invoiceSentToPrinter.
  ///
  /// In en, this message translates to:
  /// **'Invoice was sent to the printer.'**
  String get invoiceSentToPrinter;

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View Invoice'**
  String get viewInvoice;

  /// No description provided for @savePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get savePdf;

  /// No description provided for @pdfSavedAt.
  ///
  /// In en, this message translates to:
  /// **'PDF file saved: {path}'**
  String pdfSavedAt(String path);

  /// No description provided for @ownerConsole.
  ///
  /// In en, this message translates to:
  /// **'Owner Console'**
  String get ownerConsole;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @ownerTools.
  ///
  /// In en, this message translates to:
  /// **'Owner Tools'**
  String get ownerTools;

  /// No description provided for @ownerConsoleReadOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'This screen is read-only. No data can be edited or deleted.'**
  String get ownerConsoleReadOnlyNotice;

  /// No description provided for @localTables.
  ///
  /// In en, this message translates to:
  /// **'Local Tables'**
  String get localTables;

  /// No description provided for @localTablesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View tables, columns, and rows exactly as stored in the local database'**
  String get localTablesSubtitle;

  /// No description provided for @diagnosticFilters.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Filters'**
  String get diagnosticFilters;

  /// No description provided for @diagnosticFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coming later: sales without invoices, stuck outbox, failed prints...'**
  String get diagnosticFiltersSubtitle;

  /// No description provided for @failedToLoadTables.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tables: {error}'**
  String failedToLoadTables(String error);

  /// No description provided for @noTables.
  ///
  /// In en, this message translates to:
  /// **'No tables'**
  String get noTables;

  /// No description provided for @selectTableRawData.
  ///
  /// In en, this message translates to:
  /// **'Select a table to view its raw data'**
  String get selectTableRawData;

  /// No description provided for @failedToLoadTableRows.
  ///
  /// In en, this message translates to:
  /// **'Failed to load table rows: {error}'**
  String failedToLoadTableRows(String error);

  /// No description provided for @rowCopiedAsJson.
  ///
  /// In en, this message translates to:
  /// **'Row copied as JSON'**
  String get rowCopiedAsJson;

  /// No description provided for @copyRowJson.
  ///
  /// In en, this message translates to:
  /// **'Copy Row JSON'**
  String get copyRowJson;

  /// No description provided for @noRows.
  ///
  /// In en, this message translates to:
  /// **'No rows'**
  String get noRows;

  /// No description provided for @rowsRange.
  ///
  /// In en, this message translates to:
  /// **'{tableName} — Rows {from}-{to} of {total}'**
  String rowsRange(String tableName, int from, int to, int total);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @noPricedProductsForDeviceStore.
  ///
  /// In en, this message translates to:
  /// **'No priced products for this device/store.'**
  String get noPricedProductsForDeviceStore;

  /// No description provided for @storeAndPriceLevelDetails.
  ///
  /// In en, this message translates to:
  /// **'Store: {storeId}\nPrice level: {priceLevelId}'**
  String storeAndPriceLevelDetails(String storeId, String priceLevelId);

  /// No description provided for @noPriceForCurrentStorePriceLevel.
  ///
  /// In en, this message translates to:
  /// **'No price exists for this item in the current store and price level.'**
  String get noPriceForCurrentStorePriceLevel;

  /// No description provided for @noPrice.
  ///
  /// In en, this message translates to:
  /// **'No price'**
  String get noPrice;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading'**
  String get errorLoading;

  /// No description provided for @scannedItemNotSellableInCurrentStore.
  ///
  /// In en, this message translates to:
  /// **'This item is not sellable in the current device store.'**
  String get scannedItemNotSellableInCurrentStore;

  /// No description provided for @searchInvoiceOrProduct.
  ///
  /// In en, this message translates to:
  /// **'Search invoice or product'**
  String get searchInvoiceOrProduct;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @noSalesFound.
  ///
  /// In en, this message translates to:
  /// **'No matching sales'**
  String get noSalesFound;

  /// No description provided for @recentSales.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get recentSales;

  /// No description provided for @saleRows.
  ///
  /// In en, this message translates to:
  /// **'Sale rows'**
  String get saleRows;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
