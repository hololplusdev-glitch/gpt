import 'dart:io' show Platform;

import 'package:pos_flutter/shared/models/enums.dart';

AppPlatform currentAppPlatform() {
  if (Platform.isAndroid) return AppPlatform.android;
  if (Platform.isWindows) return AppPlatform.windows;
  if (Platform.isMacOS) return AppPlatform.macos;
  if (Platform.isIOS) return AppPlatform.ios;
  if (Platform.isLinux) return AppPlatform.linux;
  return AppPlatform.other;
}
