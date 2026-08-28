import 'dart:io';

import 'package:yf_code/pigeon/multicast_lock_api.g.dart';
import 'package:yf_code/utils/log.dart';

/// Android Wi-Fi MulticastLock 封装。
/// 接收 UDP 广播/组播前必须持有该锁，否则小米等机会过滤广播包。
class MulticastLock {
  MulticastLock._();

  static final MulticastLockApi _api = MulticastLockApi();

  static Future<bool> acquire() async {
    if (!Platform.isAndroid) return true;
    try {
      final held = await _api.acquire();
      dLog("获得广播/组播锁 => $held");
      return held;
    } catch (e) {
      dLog("获得广播/组播锁失败: $e");
      return false;
    }
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _api.release();
      dLog("释放广播/组播锁");
    } catch (e) {
      dLog("释放广播/组播锁失败: $e");
    }
  }
}
