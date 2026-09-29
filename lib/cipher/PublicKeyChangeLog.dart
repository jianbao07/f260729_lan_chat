import 'package:flutter/foundation.dart';


/// 背景：长期公钥用来确认对方身份。公钥中途换掉，可能是设备重装，也可能是有人冒充对方插入通信，
/// 也就是中间人攻击。把变化记下来，等用户下次进入聊天页时用对话框列出来，让双方当面或经其他渠道核对，
/// 避免在不知情时继续和假身份通信。
///
/// 职责：记录公钥的变化，并供聊天前消费（警告用户公钥变化过）。
///
/// 使用：心跳到达时调用 [PublicKeyChangeLog.observe]交给本文件处理。
/// 用户进入聊天页时调用 [PublicKeyChangeLog.consume]交出公钥变化记录，随后清空公钥变化记录。
class PublicKeyChangeLog {
  PublicKeyChangeLog._();

  static final Map<String, _DeviceLog> _logs = {};

  static void observe(String deviceId, String? publicKey, int? timestampUtc) {
    if (deviceId.isEmpty) return;
    final key = publicKey?.trim();
    if (key == null || key.isEmpty) return;
    final log = _logs.putIfAbsent(deviceId, () => _DeviceLog());
    if (log.lastKey == key) return;
    log.lastKey = key;
    log.pending.add(PublicKeyChange(
      timestampUtc: timestampUtc ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      publicKey: key,
    ));
  }

  static List<PublicKeyChange> consume(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return const [];
    final log = _logs[deviceId];
    if (log == null || log.pending.isEmpty) return const [];
    final changed = log.consumedChange || log.pending.length > 1;
    if (!changed) return const [];
    final batch = List<PublicKeyChange>.of(log.pending);
    log.pending.clear();
    log.consumedChange = true;
    return batch;
  }

  @visibleForTesting
  static void resetForTest() {
    _logs.clear();
  }
}

class PublicKeyChange {
  const PublicKeyChange({required this.timestampUtc, required this.publicKey});

  final int timestampUtc;
  final String publicKey;

  @override
  bool operator ==(Object other) => other is PublicKeyChange && other.timestampUtc == timestampUtc && other.publicKey == publicKey;

  @override
  int get hashCode => Object.hash(timestampUtc, publicKey);
}

class _DeviceLog {
  final List<PublicKeyChange> pending = [];
  String? lastKey;
  bool consumedChange = false;
}
