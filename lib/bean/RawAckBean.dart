import 'package:yf_code/enum/MessageType.dart';

/// type : "ack"
/// from_message_id : "3"

class RawAckBean {
  RawAckBean({
      this.fromMessageId});

  RawAckBean.fromJson(dynamic json) {
    fromMessageId = json['from_message_id']?.toString();
  }
  final String type = MessageType.rawAck.code;
  String? fromMessageId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    map['from_message_id'] = fromMessageId;
    return map;
  }

}
