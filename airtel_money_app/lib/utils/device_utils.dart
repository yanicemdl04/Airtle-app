import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;

/// Indique si l'app tourne sur un émulateur/simulateur (pas un appareil physique).
Future<bool> isRunningOnEmulator() async {
  if (kIsWeb) return false;

  final plugin = DeviceInfoPlugin();

  if (defaultTargetPlatform == TargetPlatform.android) {
    if (!Platform.isAndroid) return false;
    final info = await plugin.androidInfo;
    return !info.isPhysicalDevice;
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    if (!Platform.isIOS) return false;
    final info = await plugin.iosInfo;
    return !info.isPhysicalDevice;
  }

  return false;
}
