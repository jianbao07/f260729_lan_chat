import 'dart:convert';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/RawAckBean.dart';
import 'package:yf_code/bean/message/BaseMessageBean.dart';
import 'package:yf_code/bean/message/TextMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/TextTcpManager.dart';
import 'package:yf_code/utils/log.dart';

class SendTextManager {
  SendTextManager._();

  static Future<void> sendMessage(Message message, String ip,String? deviceId,{bool resend=false}) async {
    if (!resend) {
      final fromMessageId = MessageManager.newFromMessageId();
      message.initBase(InitManager.deviceId, deviceId, fromMessageId);
    }
    if (message.base == null) {
      iLog("不支持的消息类型，无法发送");
      return;
    }
    final payload = jsonEncode(message.toJson());
    final data = utf8.encode(payload);
    if(data.lengthInBytes>5120){
      iLog("大小超过5KB，不允许通过text发送，请使用文件发送");
      return;
    }
    TextTcpManager.sendText(data, ip);
    if(!resend){
      MessageManager.onMessageSent(message,ip,deviceId);
    }
  }

  static void onTextMessage(String text, String ip) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final typeCode = json['type'] as String?;
      final type = typeCode == null ? null : MessageType.fromCode(typeCode);

      switch (type) {
        case MessageType.text:
          final msg = TextMessageBean.fromJson(json);
          iLog("收到文本消息 from=$ip text=${msg.text} fromDeviceId=${msg.base?.fromDeviceId}");
          MessageManager.onMessageReceived(msg);
          _sendAckMessage(ip,msg.base?.fromMessageId);
          break;
        case MessageType.rawAck:
          final msg = RawAckBean.fromJson(json);
          iLog("收到ack消息 from=$ip fromMessageId=${msg.fromMessageId}");
          MessageManager.onAck(msg);
          break;
        case null:
          iLog("未知消息类型 from=$ip raw=$text");
          break;
      }
    } catch (e) {
      iLog("消息解析失败 from=$ip: $e");
    }
  }

  static Future<void> _sendAckMessage(String ip,String? fromMessageId)async{
    final ack=RawAckBean(fromMessageId:fromMessageId,);
    final data = utf8.encode(jsonEncode(ack.toJson()));
    TextTcpManager.sendText(data, ip);
  }
}
