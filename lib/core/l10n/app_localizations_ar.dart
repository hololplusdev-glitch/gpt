// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'كاشير برو';

  @override
  String get posShort => 'كاشير';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get loginButton => 'دخول';

  @override
  String get loginError => 'بيانات الدخول غير صحيحة';

  @override
  String get cashierSelectionOffline => 'اختيار الكاشير (بدون اتصال)';

  @override
  String get cashierSelectPrompt => 'اختر معرف مستخدم  للبدء';

  @override
  String get userIdOrLoginName => 'معرف المستخدم أو اسم الدخول';

  @override
  String get selectCashier => 'اختيار الكاشير';

  @override
  String get offlineUsersMustBeSynced =>
      'وضع عدم الاتصال - يجب مزامنة المستخدمين من النظام .';

  @override
  String get passwordLoginPending =>
      'سيكون تسجيل الدخول بكلمة المرور متاحًا عند جاهزية واجهة تسجيل الدخول.';

  @override
  String get cashierWorkspace => 'الكاشير';

  @override
  String get salesHistory => 'سجل المبيعات';

  @override
  String get invoiceSearch => 'بحث برقم الفاتورة';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get last7Days => 'آخر 7 أيام';

  @override
  String get custom => 'مخصص';

  @override
  String get filters => 'فلاتر';

  @override
  String get allCashiers => 'كل الكاشيرين';

  @override
  String get allPayments => 'كل طرق الدفع';

  @override
  String get clearFilters => 'مسح الفلاتر';

  @override
  String get netSales => 'صافي المبيعات';

  @override
  String get transactions => 'العمليات';

  @override
  String get voidsAndReturns => 'الملغي والمرتجع';

  @override
  String get noSalesInRange => 'لا توجد مبيعات ضمن هذا النطاق';

  @override
  String get settings => 'الإعدادات';

  @override
  String get setup => 'الإعداد';

  @override
  String get search => 'بحث';

  @override
  String get searchProducts => 'البحث عن المنتجات...';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String scanAddedProduct(String productName) {
    return 'تمت إضافة $productName';
  }

  @override
  String scanAddedProductQuantity(String productName, int quantity) {
    return '$productName (x$quantity)';
  }

  @override
  String noPriceForProduct(String productName) {
    return '$productName: لا يوجد سعر';
  }

  @override
  String get barcodeScanFailed => 'فشل مسح الباركود.';

  @override
  String get scannerStartFailed => 'تعذر تشغيل الماسح.';

  @override
  String get cameraStartFailed => 'تعذر تشغيل الكاميرا.';

  @override
  String get scanAddedItem => 'تمت إضافة الصنف';

  @override
  String scanAddedItemQuantity(int quantity) {
    return 'تمت إضافة الصنف ($quantity)';
  }

  @override
  String get barcodeNotFoundCatalog => 'الباركود غير موجود في الكتالوج.';

  @override
  String get scanNoPriceCurrentStore =>
      'هذا الصنف غير قابل للبيع في مخزن الجهاز الحالي.';

  @override
  String get toggleFlash => 'تشغيل الفلاش';

  @override
  String get closeScanner => 'إغلاق الماسح';

  @override
  String get pointCameraBarcode => 'وجّه الكاميرا نحو الباركود';

  @override
  String scannedItemsCount(int count) {
    return 'تم مسح $count صنف';
  }

  @override
  String get cameraPermissionDenied =>
      'لم يتم منح إذن الكاميرا. فعّل إذن الكاميرا من إعدادات الجهاز.';

  @override
  String get cart => 'السلة';

  @override
  String cartWithCount(int count) {
    return 'السلة ($count)';
  }

  @override
  String get cartEmpty => 'السلة فارغة';

  @override
  String get cartEmptyNothingToHold => 'السلة فارغة - لا يوجد طلب لتعليقه';

  @override
  String get tapProductsToAdd => 'اضغط على المنتجات لإضافتها';

  @override
  String get addToCart => 'إضافة للسلة';

  @override
  String get removeFromCart => 'حذف';

  @override
  String get quantity => 'الكمية';

  @override
  String get price => 'السعر';

  @override
  String get discount => 'الخصم';

  @override
  String discountAmountLabel(String amount) {
    return 'خصم -$amount';
  }

  @override
  String get priceOverridden => 'تم تعديل السعر';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get vat => 'ضريبة القيمة المضافة';

  @override
  String get tax => 'الضريبة';

  @override
  String get total => 'الإجمالي';

  @override
  String payAmount(String amount) {
    return 'دفع $amount';
  }

  @override
  String get pay => 'دفع';

  @override
  String get cash => 'نقدي';

  @override
  String get card => 'بطاقة';

  @override
  String get mixed => 'مختلط';

  @override
  String get change => 'الباقي';

  @override
  String invoiceNumberLabel(String invoiceNo) {
    return 'الفاتورة: $invoiceNo';
  }

  @override
  String get tendered => 'المبلغ المدفوع';

  @override
  String get amountTenderedSar => 'المبلغ المستلم (ر.س)';

  @override
  String get exact => 'المبلغ الكامل';

  @override
  String get receipt => 'الإيصال';

  @override
  String get printReceipt => 'طباعة الإيصال';

  @override
  String get reprintReceipt => 'إعادة طباعة الإيصال';

  @override
  String get holdOrder => 'تعليق الطلب';

  @override
  String get hold => 'تعليق';

  @override
  String get orderHeldSuccessfully => 'تم تعليق الطلب بنجاح';

  @override
  String get recallOrder => 'استرجاع الطلب';

  @override
  String get heldOrders => 'الطلبات المعلقة';

  @override
  String get voidSale => 'إلغاء';

  @override
  String get returnSale => 'مرتجع';

  @override
  String get customer => 'العميل';

  @override
  String get selectCustomer => 'اختيار العميل';

  @override
  String get noCustomer => 'عميل عابر';

  @override
  String get notes => 'ملاحظات';

  @override
  String get priceOverride => 'تعديل السعر';

  @override
  String get discountOverride => 'تعديل الخصم';

  @override
  String get approved => 'تمت الموافقة';

  @override
  String get denied => 'مرفوض';

  @override
  String get connection => 'الاتصال';

  @override
  String get devices => 'الأجهزة';

  @override
  String get printer => 'الطابعة';

  @override
  String get payment => 'الدفع';

  @override
  String get paymentTerminal => 'جهاز الدفع';

  @override
  String get barcodeScanner => 'ماسح الباركود';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'غير متصل';

  @override
  String get connecting => 'جاري الاتصال...';

  @override
  String get syncStatus => 'حالة المزامنة';

  @override
  String get syncMonitor => 'مراقبة المزامنة';

  @override
  String get pendingUpload => 'بانتظار الرفع';

  @override
  String get uploadFailed => 'فشل الرفع';

  @override
  String get uploaded => 'تم الرفع';

  @override
  String get downloading => 'جاري التنزيل...';

  @override
  String get downloadMasterData => 'تنزيل البيانات الأساسية';

  @override
  String get pendingInvoiceUploadUnavailable =>
      'رفع الفواتير المعلقة - الواجهة غير موثقة';

  @override
  String masterDataDownloadSummary(int rows, int failedGroups) {
    return 'تم تنزيل البيانات الأساسية: $rows صف، المجموعات الفاشلة: $failedGroups';
  }

  @override
  String get syncNotConfigured => 'عميل API غير مهيأ. شغل الإعداد أولاً.';

  @override
  String get connectionStatus => 'حالة الاتصال';

  @override
  String get backendApi => 'Backend ORDS';

  @override
  String get notConnectedOfflineMode => 'غير متصل - وضع عدم الاتصال';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get synced => 'تمت المزامنة';

  @override
  String get failed => 'فشل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get refresh => 'تحديث';

  @override
  String get host => 'العنوان';

  @override
  String get port => 'المنفذ';

  @override
  String get bootingPos => 'جاري تشغيل كاشير برو';

  @override
  String get branch => 'الفرع';

  @override
  String get station => 'المحطة';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get connectionSuccess => 'الاتصال ناجح';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get healthCheck => 'فحص الحالة';

  @override
  String get firstRunTitle => 'مرحباً بك في كاشير برو';

  @override
  String get firstRunSubtitle => 'لنقم بإعداد محطة نقاط البيع الخاصة بك';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get finish => 'إنهاء';

  @override
  String get skip => 'تخطي';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get ok => 'موافق';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجاح';

  @override
  String get warning => 'تحذير';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get noProductsFound => 'لا توجد منتجات';

  @override
  String get allCategories => 'الكل';

  @override
  String get quoteError => 'خطأ في التسعير';

  @override
  String get viewCart => 'عرض السلة';

  @override
  String get searchProductsOrScanBarcode =>
      'ابحث عن المنتجات أو امسح الباركود...';

  @override
  String get unableToAddItemToCart => 'تعذرت إضافة الصنف إلى السلة.';

  @override
  String get unableToPrepareCheckoutTotal => 'تعذر تجهيز إجمالي الدفع.';

  @override
  String get noOpenShiftCannotProcessPayment =>
      'لا توجد وردية مفتوحة. لا يمكن إتمام الدفع.';

  @override
  String get noActivePaymentMethodConfigured => 'لا توجد طريقة دفع نشطة مهيأة.';

  @override
  String get enterValidTenderedAmount => 'أدخل مبلغًا مستلمًا صحيحًا.';

  @override
  String get insufficientAmountTendered => 'المبلغ المستلم غير كافٍ.';

  @override
  String get notAuthenticatedLoginAgain =>
      'لم يتم تسجيل الدخول. الرجاء تسجيل الدخول.';

  @override
  String get paymentReferenceRequired => 'الرقم المرجعي للدفع مطلوب.';

  @override
  String get paymentCouldNotBeCompleted => 'تعذر إتمام عملية الدفع.';

  @override
  String get saleSavedPrintQueued =>
      'تم حفظ عملية البيع، وفشلت الطباعة وتمت إضافتها لإعادة المحاولة.';

  @override
  String get completePayment => 'إتمام الدفع';

  @override
  String get recordCardPayment => 'تسجيل دفع البطاقة (يدوي)';

  @override
  String get recordBankPayment => 'تسجيل الدفع البنكي';

  @override
  String get recordPayment => 'تسجيل الدفع';

  @override
  String get paymentSuccessful => 'تم الدفع بنجاح';

  @override
  String get doneNewSale => 'إنهاء - بيع جديد';

  @override
  String get offline => 'غير متصل';

  @override
  String get online => 'متصل';

  @override
  String get currency => 'ر.س';

  @override
  String get todaySales => 'مبيعات اليوم';

  @override
  String get averageValue => 'متوسط القيمة';

  @override
  String get noSalesToday => 'لا توجد مبيعات اليوم';

  @override
  String saleCashierLine(String time, String cashier) {
    return '$time - $cashier';
  }

  @override
  String get invoiceTypeSales => 'فاتورة مبيعات';

  @override
  String get printStatusNotPrinted => 'غير مطبوعة';

  @override
  String get printStatusPrinted => 'تمت الطباعة';

  @override
  String get printStatusFailed => 'فشل الطباعة';

  @override
  String get printStatusPending => 'بانتظار الطباعة';

  @override
  String get arabicPrintNotice =>
      'تتم طباعة العربية كصورة Raster لضمان وضوح النص.';

  @override
  String get saleId => 'رقم المبيعات';

  @override
  String get receiptNumber => 'رقم الإيصال';

  @override
  String get date => 'التاريخ';

  @override
  String get status => 'الحالة';

  @override
  String get completed => 'مكتمل';

  @override
  String get draft => 'مسودة';

  @override
  String get pendingSync => 'بانتظار المزامنة';

  @override
  String get rejected => 'مرفوض';

  @override
  String get voided => 'ملغي';

  @override
  String get returned => 'مرتجع';

  @override
  String get held => 'معلق';

  @override
  String get active => 'نشط';

  @override
  String get openShift => 'فتح الوردية';

  @override
  String get closeShift => 'إغلاق الوردية';

  @override
  String get backToPos => 'العودة لنقاط البيع';

  @override
  String get openNewShift => 'فتح وردية جديدة';

  @override
  String cashierNameLabel(String name) {
    return 'الكاشير: $name';
  }

  @override
  String get unknownCashier => 'غير معروف';

  @override
  String get openingCashSar => 'النقدية الافتتاحية (ر.س)';

  @override
  String get zeroAmountHint => '0.00';

  @override
  String get openingShift => 'جاري الفتح...';

  @override
  String openedAtLabel(String dateTime) {
    return 'تم الفتح: $dateTime';
  }

  @override
  String get openingCash => 'النقدية الافتتاحية';

  @override
  String get sales => 'المعاملات';

  @override
  String get grossSales => 'إجمالي المبيعات';

  @override
  String get actualCashInDrawerSar => 'النقدية الفعلية في الدرج (ر.س)';

  @override
  String get closingNotesOptional => 'ملاحظات الإغلاق (اختياري)';

  @override
  String get closingShift => 'جاري الإغلاق...';

  @override
  String get clearCart => 'مسح السلة';

  @override
  String itemCount(int count) {
    return '$count عنصر';
  }

  @override
  String amountFormat(String amount) {
    return '$amount ر.س';
  }

  @override
  String get posDevices => 'أجهزة نقاط البيع';

  @override
  String get posConfigIncomplete =>
      'إعدادات نقطة البيع غير مكتملة. راجع الإعدادات أو أجهزة نقاط البيع قبل البيع.';

  @override
  String get printers => 'الطابعات';

  @override
  String get searchNetwork => 'البحث في الشبكة';

  @override
  String get addPrinter => 'إضافة طابعة';

  @override
  String get editPrinter => 'تعديل الطابعة';

  @override
  String get deletePrinter => 'حذف الطابعة';

  @override
  String deletePrinterConfirmation(String name) {
    return 'حذف $name؟ ستتم إزالة هذه الطابعة من هذه المحطة.';
  }

  @override
  String get noPrintersConfigured => 'لا توجد طابعات مهيأة';

  @override
  String get addCashierOrKitchenPrinter =>
      'أضف طابعة شبكة/IP للكاشير أو المطبخ.';

  @override
  String get unableToLoadPrinters => 'تعذر تحميل الطابعات.';

  @override
  String get unableToLoadPaymentProfile => 'تعذر تحميل إعدادات الدفع.';

  @override
  String get test => 'اختبار';

  @override
  String get testPrint => 'اختبار الطباعة';

  @override
  String get testPrintSucceeded => 'نجح اختبار الطباعة.';

  @override
  String get testPrintFailed => 'فشل اختبار الطباعة.';

  @override
  String get printerUpdateFailed => 'تعذر تحديث الطابعة.';

  @override
  String get printerDeleteFailed => 'تعذر حذف الطابعة.';

  @override
  String get printerSaveFailed => 'تعذر حفظ الطابعة.';

  @override
  String get networkPrinter => 'طابعة حرارية عبر الشبكة (IP)';

  @override
  String get systemPrinter => 'طابعة حرارية معرفة في النظام';

  @override
  String get bluetoothPrinter => 'طابعة حرارية بلوتوث';

  @override
  String get enableCardPayment => 'تفعيل الدفع بالبطاقة/الشبكة';

  @override
  String get checkoutChoosesPaymentPerSale =>
      'يتم اختيار النقد أو البطاقة عند الدفع لكل عملية بيع.';

  @override
  String get requireReference => 'طلب الرقم المرجعي للبطاقة اليدوية';

  @override
  String get referenceRequired => 'الرقم المرجعي مطلوب';

  @override
  String get savePaymentProfile => 'حفظ إعدادات الدفع';

  @override
  String get readiness => 'الجاهزية';

  @override
  String get saleReadiness => 'جاهزية البيع';

  @override
  String get cashierPrinter => 'طابعة الكاشير';

  @override
  String get kitchenPrinter => 'طابعة المطبخ';

  @override
  String get manualCard => 'بطاقة يدوية';

  @override
  String get disabled => 'معطل';

  @override
  String get missing => 'غير موجود';

  @override
  String get untested => 'غير مختبر';

  @override
  String get ready => 'جاهز';

  @override
  String get unsupported => 'غير مدعوم';

  @override
  String get retryableJobs => 'عمليات الطباعة القابلة للإعادة';

  @override
  String retryFailedJobs(int count) {
    return 'إعادة محاولة $count عملية طباعة فاشلة';
  }

  @override
  String get allowed => 'مسموح';

  @override
  String get allowedPrintWarning => 'مسموح (تحذير: طابعة الكاشير)';

  @override
  String get allowedKitchenWarning => 'مسموح (تحذير: طابعة المطبخ)';

  @override
  String get noCard => 'لا توجد بطاقة';

  @override
  String get retryQueuedJobsProcessed =>
      'تمت معالجة عمليات الطباعة القابلة للإعادة.';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get cardPaymentNotConfigured => 'الدفع بالبطاقة غير مهيأ.';

  @override
  String get searchNetworkPrinters => 'البحث عن طابعات الشبكة';

  @override
  String get subnetPrefixExample => 'بادئة الشبكة الفرعية (مثال: 192.168.1)';

  @override
  String scanningPort(int port) {
    return 'جاري فحص المنفذ $port...';
  }

  @override
  String get networkPrinterSearchHint =>
      'أدخل بادئة الشبكة ثم اضغط بحث لفحص طابعات ESC/POS على المنفذ 9100.';

  @override
  String portNumber(int port) {
    return 'المنفذ $port';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get networkSearchFailed => 'فشل البحث عن طابعات الشبكة.';

  @override
  String get cashierRole => 'كاشير';

  @override
  String get kitchenRole => 'مطبخ';

  @override
  String get printerName => 'اسم الطابعة';

  @override
  String get ipAddress => 'عنوان IP';

  @override
  String get paperWidth => 'عرض الورق:';

  @override
  String paperWidthMm(int width) {
    return '$widthمم';
  }

  @override
  String get copies => 'النسخ:';

  @override
  String get autoPrintAfterSale => 'الطباعة تلقائيًا بعد البيع';

  @override
  String get enablePrinter => 'تفعيل الطابعة';

  @override
  String get mustBeTestedSuccessfullyFirst => 'يجب اختبارها بنجاح أولاً';

  @override
  String lastTestedAt(String dateTime) {
    return 'آخر اختبار: $dateTime';
  }

  @override
  String get testing => 'جاري الاختبار...';

  @override
  String get paymentReference => 'الرقم المرجعي للدفع';

  @override
  String get recordApprovedRef =>
      'تسجيل يدوي لمدفوعات الشبكة/البنك. أدخل رقم المرجع إن وجد.';

  @override
  String get posSetup => 'إعداد كاشير برو';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get serverIdentity => 'الخادم وهوية النظام';

  @override
  String get initialReadiness => 'الجاهزية المبدئية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get fullUrlMode => 'وضع الرابط الكامل';

  @override
  String get fullUrlSubtitle => 'الصق الرابط الأساسي لـ Backend API مباشرة';

  @override
  String get apiBaseUrl => 'الرابط الأساسي (API)';

  @override
  String get apiBaseUrlExample =>
      'https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1';

  @override
  String get baseUrlHint => 'الرابط الأساسي بدون /data';

  @override
  String get hostOrIp => 'الاستضافة / IP';

  @override
  String get optional => 'اختياري';

  @override
  String get apiBasePath => 'المسار الأساسي';

  @override
  String get apiBasePathExample => '/ords/erp/pos-api/v1';

  @override
  String get https => 'HTTPS';

  @override
  String get customerCode => 'كود العميل';

  @override
  String get userId => 'معرف مستخدم النظام';

  @override
  String get branchNumber => 'رقم الفرع (braNbr)';

  @override
  String get branchNumberHint => 'يستخدم كمعرف للفرع';

  @override
  String get machineNumber => 'رقم الجهاز (mchnNbr)';

  @override
  String get machineNumberHint => 'يستخدم كمعرف للمحطة';

  @override
  String get setupSuccess => 'تم إعداد الخادم وهوية النظام بنجاح';

  @override
  String get setupPrintersLater =>
      'يتم إعداد الطابعات والدفع لاحقًا في أجهزة نقاط البيع';

  @override
  String get cancelSync => 'إلغاء المزامنة';

  @override
  String get preparing => 'جاري التحضير...';

  @override
  String get enterApiBaseUrl => 'أدخل الرابط الأساسي للواجهة البرمجية.';

  @override
  String get serverCheckFailedFixConnection =>
      'فشل فحص الخادم. صحح الاتصال قبل المتابعة.';

  @override
  String get setupUnexpectedError =>
      'تعذر متابعة الإعداد. راجع بيانات الاتصال وحاول مرة أخرى.';

  @override
  String get syncingData => 'جاري مزامنة البيانات...';

  @override
  String syncingDataPercent(int percent) {
    return 'جاري مزامنة البيانات... $percent%';
  }

  @override
  String get serverConnection => 'اتصال الخادم';

  @override
  String get notConfigured => 'غير مهيأ';

  @override
  String get terminalIdentity => 'هوية النظام';

  @override
  String backendIdentitySummary(
    String custCode,
    String branch,
    String machine,
  ) {
    return 'كود العميل: $custCode  |  الفرع: $branch  |  الجهاز: $machine';
  }

  @override
  String get posDevicesSubtitle => 'الطابعات، دفع البطاقة اليدوي، الجاهزية';

  @override
  String get general => 'عام';

  @override
  String get about => 'حول التطبيق';

  @override
  String versionLabel(String version) {
    return 'كاشير برو v$version';
  }

  @override
  String get applicationLegalese2026 =>
      '© 2026 إكسترا سوليوشنز. جميع الحقوق محفوظة.';

  @override
  String get dangerZone => 'منطقة حساسة';

  @override
  String get resetSetup => 'إعادة ضبط الإعداد';

  @override
  String get resetSetupSubtitle => 'إعادة تشغيل إعداد الاتصال الأولي';

  @override
  String get resetSetupQuestion => 'إعادة ضبط الإعداد؟';

  @override
  String get resetSetupWarning =>
      'سيتم مسح إعداد الاتصال الأولي وستحتاج إلى اتصال خادم جديد ومزامنة كاملة للبيانات. ستبقى المبيعات والورديات وسجل المعاملات محفوظة.';

  @override
  String get reset => 'إعادة ضبط';

  @override
  String pdfInvoiceTitle(String invoiceNo) {
    return 'فاتورة $invoiceNo';
  }

  @override
  String get simplifiedTaxInvoice => 'فاتورة ضريبية مبسطة';

  @override
  String get taxNumber => 'الرقم الضريبي';

  @override
  String get commercialRegistration => 'السجل التجاري';

  @override
  String get terminal => 'الجهاز';

  @override
  String get item => 'الصنف';

  @override
  String get unitPrice => 'سعر الوحدة';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get reference => 'المرجع';

  @override
  String get amount => 'المبلغ';

  @override
  String get beforeTaxTotal => 'المجموع قبل الضريبة';

  @override
  String get paid => 'المدفوع';

  @override
  String receiptInvoiceTitle(String invoiceNo) {
    return 'فاتورة $invoiceNo';
  }

  @override
  String get cashier => 'الكاشير';

  @override
  String get noEnabledPrinter => 'لا توجد طابعة مفعلة.';

  @override
  String get invoiceSavedButPrintFailed => 'تم حفظ الفاتورة، لكن فشلت الطباعة.';

  @override
  String get invoiceSentToPrinter => 'تم إرسال الفاتورة للطباعة.';

  @override
  String get viewInvoice => 'عرض الفاتورة';

  @override
  String get savePdf => 'حفظ PDF';

  @override
  String pdfSavedAt(String path) {
    return 'تم حفظ ملف PDF: $path';
  }

  @override
  String get ownerConsole => 'لوحة المالك';

  @override
  String get exit => 'خروج';

  @override
  String get ownerTools => 'أدوات المالك';

  @override
  String get ownerConsoleReadOnlyNotice =>
      'هذه الشاشة للعرض فقط. لا يوجد تعديل أو حذف للبيانات.';

  @override
  String get localTables => 'الجداول المحلية';

  @override
  String get localTablesSubtitle =>
      'عرض الجداول والأعمدة والصفوف كما هي في قاعدة البيانات';

  @override
  String get diagnosticFilters => 'فلاتر التشخيص';

  @override
  String get diagnosticFiltersSubtitle =>
      'لاحقًا: مبيعات بدون فاتورة، outbox معلق، طباعة فاشلة...';

  @override
  String failedToLoadTables(String error) {
    return 'فشل تحميل الجداول: $error';
  }

  @override
  String get noTables => 'لا توجد جداول';

  @override
  String get selectTableRawData => 'اختر جدولًا لعرض بياناته الخام';

  @override
  String failedToLoadTableRows(String error) {
    return 'فشل تحميل بيانات الجدول: $error';
  }

  @override
  String get rowCopiedAsJson => 'تم نسخ الصف كـ JSON';

  @override
  String get copyRowJson => 'نسخ الصف كـ JSON';

  @override
  String get noRows => 'لا توجد صفوف';

  @override
  String rowsRange(String tableName, int from, int to, int total) {
    return '$tableName — الصفوف $from-$to من $total';
  }

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String get noPricedProductsForDeviceStore =>
      'لا توجد منتجات مسعّرة لهذا الجهاز/المخزن.';

  @override
  String storeAndPriceLevelDetails(String storeId, String priceLevelId) {
    return 'المخزن: $storeId\nمستوى السعر: $priceLevelId';
  }

  @override
  String get noPriceForCurrentStorePriceLevel =>
      'لا يوجد سعر لهذا الصنف في المخزن ومستوى السعر الحالي.';

  @override
  String get noPrice => 'لا يوجد سعر';

  @override
  String get errorLoading => 'خطأ في التحميل';

  @override
  String get scannedItemNotSellableInCurrentStore =>
      'هذا الصنف غير قابل للبيع في مخزن الجهاز الحالي.';

  @override
  String get searchInvoiceOrProduct => 'بحث برقم الفاتورة أو المنتج';

  @override
  String get products => 'المنتجات';

  @override
  String get noSalesFound => 'لا توجد مبيعات مطابقة';

  @override
  String get recentSales => 'آخر المبيعات';

  @override
  String get saleRows => 'صفوف المبيعات';

  @override
  String get invoice => 'الفاتورة';
}
