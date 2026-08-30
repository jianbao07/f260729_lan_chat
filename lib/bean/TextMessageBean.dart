import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';

/// type : "text"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// text : "你好你好"

class TextMessageBean extends Message {
  TextMessageBean({
      this.text,});

  TextMessageBean.fromJson(dynamic json) {
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    text = json['text'];
  }
  final String type = MessageType.text.code;
  String? text;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['text'] = text;
    return map;
  }

}
