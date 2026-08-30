import 'dart:convert';
import 'dart:io';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/channel/TextChannel.dart';
import 'package:yf_code/utils/log.dart';

class SendMessageManager {
  SendMessageManager._();
  static const int MAX_SIZE = 16 * 1024;

  static Future<void> sendMessage(Message message, String ip, String? deviceId, {bool resend = false,}) async {
    if (!resend) {
      final fromMessageId = MessageManager.newFromMessageId();
      message.initBase(InitManager.deviceId, deviceId, fromMessageId);
    }
    if (message.base == null) {
      iLog("不支持的消息类型，无法发送");
      return;
    }
    FileTransferRecord? savedSenderTransfer;
    FileTransferRecord? savedReceiverTransfer;
    String? savedAckReceiverPath;
    if (message is SendFileBean) {
      savedSenderTransfer = message.senderTransfer;
      savedReceiverTransfer = message.receiverTransfer;
      message.senderTransfer = null;
      message.receiverTransfer = null;
    } else if (message is AckFileBean) {
      savedAckReceiverPath = message.receiverLocalPath;
      message.receiverLocalPath = null;
    }
    final payload = jsonEncode(message.toJson());
    if (message is SendFileBean) {
      message.senderTransfer = savedSenderTransfer;
      message.receiverTransfer = savedReceiverTransfer;
    } else if (message is AckFileBean) {
      message.receiverLocalPath = savedAckReceiverPath;
    }
    final payloadUint8 = utf8.encode(payload);
    if (payloadUint8.lengthInBytes > MAX_SIZE) {
      iLog("大小超过${MAX_SIZE / 1024}KB，不允许通过text发送，请使用文件发送");
      return;
    }
    await TextChannel.sendText(payload, payloadUint8, ip);
    if (!resend) {
      MessageManager.onMessageSent(message, ip, deviceId);
    }
  }

  static Future<void> sendFile(File file, String ip, String? deviceId) async {
    await FileTransferManager.offer(file, ip, deviceId);
  }

  static void onTextMessage(String text, String ip) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final typeCode = json['type'] as String?;
      final type = typeCode == null ? null : MessageType.fromCode(typeCode);

      switch (type) {
        case MessageType.text:
          final msg = TextMessageBean.fromJson(json);
          iLog("文本消息解析成功=${msg.text}");
          MessageManager.onMessageReceived(msg);
          sendAckMessage(ip, msg.base?.fromMessageId);
          break;
        case MessageType.rawAck:
          final msg = CmdAckBean.fromJson(json);
          iLog("文本消息解析成功 ACK");
          MessageManager.onAck(msg);
          break;
        case null:
          iLog("文本消息解析失败 from=$ip raw=$text");
          break;
        case MessageType.file:
          _onFileMessage(json, ip);
          final base = json['base'] as Map<String, dynamic>?;
          sendAckMessage(ip, base?['from_message_id']?.toString());
          break;
      }
    } catch (e) {
      iLog("文本消息解析异常 from=$ip: $e");
    }
  }

  static void _onFileMessage(Map<String, dynamic> json, String ip) {
    final state = FileTransferState.fromCode(json['state'] as String? ?? '');
    switch (state) {
      case FileTransferState.send:
        final msg = SendFileBean.fromJson(json);
        FileTransferManager.onOffer(msg, ip);
        MessageManager.onMessageReceived(msg);
        break;
      case FileTransferState.rejected:
      case FileTransferState.transferring:
        final msg = ReplySendFileBean.fromJson(json);
        MessageManager.onMessageReceived(msg);
        FileTransferManager.onReply(msg, ip);
        break;
      case FileTransferState.success:
      case FileTransferState.failed:
        final msg = AckFileBean.fromJson(json);
        MessageManager.onMessageReceived(msg);
        FileTransferManager.onAck(msg);
        break;
      case null:
        iLog("未知文件消息 state=${json['state']} from=$ip");
        break;
    }
  }

  static Future<void> sendAckMessage(String ip, String? fromMessageId) async {
    final ack = CmdAckBean(fromMessageId: fromMessageId);
    final payload = jsonEncode(ack.toJson());
    final payloadUint8 = utf8.encode(payload);
    TextChannel.sendText(payload, payloadUint8, ip);
  }
}
