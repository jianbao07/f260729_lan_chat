import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageStore.dart';

/// type : "text"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// text : "你好你好"

class TextMessageBean extends Message {
  TextMessageBean({this.text}) : messageId = MessageStore.newMessageId(MessageType.text);

  TextMessageBean.fromJson(dynamic json) : messageId = json['message_id']?.toString() ?? '' {
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    text = json['text'];
  }
  @override
  MessageType get type => MessageType.text;
  @override
  final String messageId;
  String? text;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type.code;
    map['message_id'] = messageId;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['text'] = text;
    return map;
  }

}
