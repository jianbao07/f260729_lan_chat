import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/enum/MessageType.dart';

/// conversation_id : "xxx"
/// from_device_id : "xxx"
/// to_device_id : "yyy"
/// send_timestamp_utc : 1785173158277
/// success_timestamp_utc : 1785173158277
/// fail_timestamp_utc : 1785173158277
/// state : "sending"
/// is_sender : true

class BaseMessageBean {
  BaseMessageBean({
    this.conversationId,
    this.fromDeviceId,
    this.toDeviceId,
    this.sendTimestampUtc,
    this.successTimestampUtc,
    this.failTimestampUtc,
    this.state,
    this.isSender,
  });

  BaseMessageBean.fromJson(dynamic json) {
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

  bool initBase(String? myDeviceId, String? deviceId){
    final base = this.base ?? BaseMessageBean();
    base.fromDeviceId ??= myDeviceId;
    base.toDeviceId ??= deviceId;
    if (myDeviceId != null && deviceId != null) {
      base.conversationId ??= myDeviceId.compareTo(deviceId) <= 0
          ? '$myDeviceId:$deviceId'
          : '$deviceId:$myDeviceId';
    }
    base.sendTimestampUtc ??=
        DateTime.now().toUtc().millisecondsSinceEpoch;
    base.state ??= MessageStateType.sending.code;
    base.isSender ??= true;
    this.base = base;
    return true;
  }
  BaseMessageBean? base;
  /// 所属分页文件名，例如 `1.json`
  String? pageName;
  Map<String, dynamic> toJson();

  static Message? fromJson(dynamic json) {
    if (json is! Map) return null;
    final typeCode = json['type']?.toString();
    if (typeCode == null) return null;
    switch (MessageType.fromCode(typeCode)) {
      case MessageType.text:
        return TextMessageBean.fromJson(json);
      case MessageType.file:
        switch (FileTransferState.fromCode(json['state']?.toString())) {
          case FileTransferState.send:
            return SendFileBean.fromJson(json);
          case FileTransferState.rejected:
          case FileTransferState.transferring:
            return ReplySendFileBean.fromJson(json);
          case FileTransferState.success:
          case FileTransferState.failed:
            return AckFileBean.fromJson(json);
          case null:
            return null;
        }
      case MessageType.rawAck:
      case null:
        return null;
    }
  }
}
