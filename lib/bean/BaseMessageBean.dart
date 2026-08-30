import 'package:yf_code/enum/MessageStateType.dart';

/// from_message_id : "3"
/// to_message_id : "3"
/// session_id : "xxx"
/// from_device_id : "xxx"
/// to_device_id : "yyy"
/// send_timestamp_utc : 1785173158277
/// success_timestamp_utc : 1785173158277
/// fail_timestamp_utc : 1785173158277
/// state : "sending"
/// is_sender : true

class BaseMessageBean {
  BaseMessageBean({
    this.fromMessageId,
    this.toMessageId,
    this.sessionId,
    this.fromDeviceId,
    this.toDeviceId,
    this.sendTimestampUtc,
    this.successTimestampUtc,
    this.failTimestampUtc,
    this.state,
    this.isSender,
  });

  BaseMessageBean.fromJson(dynamic json) {
    fromMessageId = json['from_message_id']?.toString();
    toMessageId = json['to_message_id']?.toString();
    sessionId = json['session_id'];
    fromDeviceId = json['from_device_id'];
    toDeviceId = json['to_device_id'];
    sendTimestampUtc = json['send_timestamp_utc'];
    successTimestampUtc = json['success_timestamp_utc'];
    failTimestampUtc = json['fail_timestamp_utc'];
    state = json['state'];
    isSender = json['is_sender'];
  }
  String? fromMessageId;
  String? toMessageId;
  String? sessionId;
  String? fromDeviceId;
  String? toDeviceId;
  num? sendTimestampUtc;
  num? successTimestampUtc;
  num? failTimestampUtc;
  String? state;
  bool? isSender;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['from_message_id'] = fromMessageId;
    map['to_message_id'] = toMessageId;
    map['session_id'] = sessionId;
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
  bool initBase(String? myDeviceId, String? deviceId,String fromMessageId){
    final base = this.base ?? BaseMessageBean();
    base.fromMessageId=fromMessageId;
    base.fromDeviceId ??= myDeviceId;
    base.toDeviceId ??= deviceId;
    if (myDeviceId != null && deviceId != null) {
      base.sessionId ??= myDeviceId.compareTo(deviceId) <= 0
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
  Map<String, dynamic> toJson();
}
