import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/channel/TextChannel.dart';

class InitManager{
  InitManager._();

  static String? deviceId;
  static String? deviceName;

  static late String packageName;
  static late String appName;
  static late String version;
  static late String buildNumber;

  static void initApp()async{
    await _getDeviceInfo();
    await _getPackageInfo();
    OnlineDeviceManager.startBeat();
    OnlineDeviceManager.listenerBeat();
    TextChannel.init();
  }

  static Future<void> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor;
      deviceName = iosInfo.name;
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      deviceId = macInfo.systemGUID;
      deviceName = macInfo.computerName;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      deviceId = windowsInfo.deviceId;
      deviceName = windowsInfo.computerName;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      deviceId = linuxInfo.machineId;
      deviceName = linuxInfo.name;
    }
  }

  static Future<void> _getPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    packageName = packageInfo.packageName;
    appName = packageInfo.appName;
    version = packageInfo.version;
    buildNumber = packageInfo.buildNumber;
  }

}
