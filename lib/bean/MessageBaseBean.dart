import 'package:yf_code/bean/AckFileMessageBean.dart';
import 'package:yf_code/bean/MessageReplySendFileBean.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/utils/CryptoUtils.dart';

/// conversation_id : "xxx"
/// from_device_id : "xxx"
/// to_device_id : "yyy"
/// send_timestamp_utc : 1785173158277
/// success_timestamp_utc : 1785173158277
/// fail_timestamp_utc : 1785173158277
/// state : "sending"
/// is_sender : true

class MessageBaseBean {
  MessageBaseBean({
    this.conversationId,
    this.fromDeviceId,
    this.toDeviceId,
    this.sendTimestampUtc,
    this.successTimestampUtc,
    this.failTimestampUtc,
    this.state,
    this.isSender,
  });

  MessageBaseBean.fromJson(dynamic json) {
    conversationId = json['conversation_id'];
    fromDeviceId = json['from_device_id'];
    toDeviceId = json['to_device_id'];
    sendTimestampUtc = json['send_timestamp_utc'];
    successTimestampUtc = json['success_timestamp_utc'];
    failTimestampUtc = json['fail_timestamp_utc'];
    state = json['state'];
    isSender = json['is_sender'];
  }
  String? conversationId;
  String? fromDeviceId;
  String? toDeviceId;
  num? sendTimestampUtc;
  num? successTimestampUtc;
  num? failTimestampUtc;
  String? state;
  bool? isSender;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['conversation_id'] = conversationId;
    map['from_device_id'] = fromDeviceId;
    map['to_device_id'] = toDeviceId;
    map['send_timestamp_utc'] = sendTimestampUtc;
    map['success_timestamp_utc'] = successTimestampUtc;
    map['fail_timestamp_utc'] = failTimestampUtc;
    map['state'] = state;
    map['is_sender'] = isSender;
    return map;
  }

}

abstract class Message{
  MessageType get type;
  String get messageId;

  /// 对方设备 id：自己发出则取 `toDeviceId`，收到则取 `fromDeviceId`
  String get peerDeviceId {
    final base = this.base;
    if (base == null) return '';
    if (base.isSender == true) return base.toDeviceId ?? '';
    if (base.isSender == false) return base.fromDeviceId ?? '';
    return base.fromDeviceId ?? base.toDeviceId ?? '';
  }

  static String buildConversationId(String? deviceIdA, String? deviceIdB) {
    final a = deviceIdA ?? '';
    final b = deviceIdB ?? '';
    return CryptoUtils.md5(a.compareTo(b) <= 0 ? '$a:$b' : '$b:$a');
  }

  bool initBase(String? myDeviceId, String? deviceId){
    final base = this.base ?? MessageBaseBean();
    base.fromDeviceId ??= myDeviceId;
    base.toDeviceId ??= deviceId;
    if (myDeviceId != null && deviceId != null) {
      base.conversationId ??= buildConversationId(myDeviceId, deviceId);
    }
    base.sendTimestampUtc ??=
        DateTime.now().toUtc().millisecondsSinceEpoch;
    base.state ??= MessageStateType.sending.code;
    base.isSender ??= true;
    this.base = base;
    return true;
  }
  MessageBaseBean? base;
  /// 所属分页文件名，例如 `1.json`
  String? pageName;
  Map<String, dynamic> toJson();

  static Message? fromJson(dynamic json) {
    if (json is! Map) return null;
    final typeCode = json['type']?.toString();
    if (typeCode == null) return null;
    switch (MessageType.fromCode(typeCode)) {
      case MessageType.text:
        return MessageTextBean.fromJson(json);
      case MessageType.file:
        switch (FileTransferState.fromCode(json['state']?.toString())) {
          case FileTransferState.send:
            return MessageSendFileBean.fromJson(json);
          case FileTransferState.rejected:
          case FileTransferState.transferring:
            return MessageReplySendFileBean.fromJson(json);
          case FileTransferState.success:
          case FileTransferState.failed:
            return AckFileMessageBean.fromJson(json);
          case null:
            return null;
        }
      case MessageType.rawAck:
      case MessageType.tempPublicKey:
      case MessageType.ciphertextOk:
      case null:
        return null;
    }
  }
}
