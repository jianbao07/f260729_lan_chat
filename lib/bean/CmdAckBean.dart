import 'package:yf_code/enum/MessageType.dart';

/// type : "ack"
/// message_id : "3"

class CmdAckBean {
  CmdAckBean({this.messageId});

  CmdAckBean.fromJson(dynamic json) {
    messageId = json['message_id']?.toString();
  }
  final String type = MessageType.rawAck.code;
  String? messageId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    map['message_id'] = messageId;
    return map;
  }

}
