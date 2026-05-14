
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _DocInfo1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef _OpenPrinterWNative = Int32 Function(
  Pointer<Utf16> printerName,
  Pointer<Pointer<Void>> printerHandle,
  Pointer<Void> defaults,
);
typedef _OpenPrinterW = int Function(
  Pointer<Utf16> printerName,
  Pointer<Pointer<Void>> printerHandle,
  Pointer<Void> defaults,
);

typedef _StartDocPrinterWNative = Uint32 Function(
  Pointer<Void> printerHandle,
  Uint32 level,
  Pointer<Void> docInfo,
);
typedef _StartDocPrinterW = int Function(
  Pointer<Void> printerHandle,
  int level,
  Pointer<Void> docInfo,
);

typedef _BoolPrinterFnNative = Int32 Function(Pointer<Void> printerHandle);
typedef _BoolPrinterFn = int Function(Pointer<Void> printerHandle);

typedef _WritePrinterNative = Int32 Function(
  Pointer<Void> printerHandle,
  Pointer<Void> data,
  Uint32 dataLength,
  Pointer<Uint32> written,
);
typedef _WritePrinter = int Function(
  Pointer<Void> printerHandle,
  Pointer<Void> data,
  int dataLength,
  Pointer<Uint32> written,
);

class RawSystemPrinterWriter {
  const RawSystemPrinterWriter();

  Future<void> writeRawBytes(
    String printerName,
    List<int> bytes, {
    String documentName = 'POS Receipt',
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'RAW system printer writing is implemented for Windows only.',
      );
    }
    if (printerName.trim().isEmpty) {
      throw ArgumentError('System printer name is required.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Print payload is empty.');
    }

    return _writeWindowsRaw(
      printerName.trim(),
      Uint8List.fromList(bytes),
      documentName: documentName.trim().isEmpty ? 'POS Receipt' : documentName,
    );
  }

  void _writeWindowsRaw(
    String printerName,
    Uint8List bytes, {
    required String documentName,
  }) {
    final spooler = DynamicLibrary.open('winspool.drv');

    final openPrinter = spooler
        .lookupFunction<_OpenPrinterWNative, _OpenPrinterW>('OpenPrinterW');
    final startDocPrinter = spooler.lookupFunction<
        _StartDocPrinterWNative,
        _StartDocPrinterW>('StartDocPrinterW');
    final startPagePrinter = spooler.lookupFunction<
        _BoolPrinterFnNative,
        _BoolPrinterFn>('StartPagePrinter');
    final writePrinter = spooler
        .lookupFunction<_WritePrinterNative, _WritePrinter>('WritePrinter');
    final endPagePrinter = spooler.lookupFunction<
        _BoolPrinterFnNative,
        _BoolPrinterFn>('EndPagePrinter');
    final endDocPrinter = spooler.lookupFunction<
        _BoolPrinterFnNative,
        _BoolPrinterFn>('EndDocPrinter');
    final closePrinter = spooler.lookupFunction<
        _BoolPrinterFnNative,
        _BoolPrinterFn>('ClosePrinter');

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<Pointer<Void>>();
    final docInfoPtr = calloc<_DocInfo1W>();
    final docNamePtr = documentName.toNativeUtf16();
    final dataTypePtr = 'RAW'.toNativeUtf16();
    final dataPtr = calloc<Uint8>(bytes.length);
    final writtenPtr = calloc<Uint32>();

    var opened = false;
    var docStarted = false;
    var pageStarted = false;

    try {
      final openedOk = openPrinter(printerNamePtr, printerHandlePtr, nullptr);
      if (openedOk == 0) {
        throw StateError('Unable to open system printer: $printerName');
      }
      opened = true;

      final printerHandle = printerHandlePtr.value;
      docInfoPtr.ref.pDocName = docNamePtr;
      docInfoPtr.ref.pOutputFile = nullptr;
      docInfoPtr.ref.pDatatype = dataTypePtr;

      final jobId = startDocPrinter(printerHandle, 1, docInfoPtr.cast<Void>());
      if (jobId == 0) {
        throw StateError('Unable to start RAW print document.');
      }
      docStarted = true;

      if (startPagePrinter(printerHandle) == 0) {
        throw StateError('Unable to start RAW print page.');
      }
      pageStarted = true;

      dataPtr.asTypedList(bytes.length).setAll(0, bytes);
      final writeOk = writePrinter(
        printerHandle,
        dataPtr.cast<Void>(),
        bytes.length,
        writtenPtr,
      );
      if (writeOk == 0 || writtenPtr.value != bytes.length) {
        throw StateError(
          'RAW WritePrinter failed. Written ${writtenPtr.value}/${bytes.length} bytes.',
        );
      }
    } finally {
      final handle = printerHandlePtr.value;
      if (opened && pageStarted) endPagePrinter(handle);
      if (opened && docStarted) endDocPrinter(handle);
      if (opened) closePrinter(handle);

      calloc.free(printerNamePtr);
      calloc.free(printerHandlePtr);
      calloc.free(docInfoPtr);
      calloc.free(docNamePtr);
      calloc.free(dataTypePtr);
      calloc.free(dataPtr);
      calloc.free(writtenPtr);
    }
  }
}
