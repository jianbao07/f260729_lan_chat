import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/channel/TextChannel.dart';
import 'package:yf_code/utils/log.dart';

class MessageManager {
  MessageManager._();
  static const int MAX_SIZE = 16 * 1024;

  /// 正在发送的协议消息（messageId -> Message）
  static final Map<String, Message> sendingMessages = {};
  static final Map<String, String> transferConversationIds = {};//transfer_id -> conversation_id

  static final Map<String, Timer> _ackTimers = {};

  static Future<void> sendMessage(Message message, String ip, String? deviceId, {bool resend = false,}) async {
    if (!resend) {
      message.initBase(InitManager.deviceId, deviceId);
    }
    if (message.base == null) {
      iLog("不支持的消息类型，无法发送");
      return;
    }
    FileTransferRecord? savedTransferRecord;
    String? savedAckReceiverPath;
    if (message is SendFileBean) {
      savedTransferRecord = message.transferRecord;
      message.transferRecord = null;
    } else if (message is AckFileBean) {
      savedAckReceiverPath = message.receiverLocalPath;
      message.receiverLocalPath = null;
    }
    final payload = jsonEncode(message.toJson());
    if (message is SendFileBean) {
      message.transferRecord = savedTransferRecord;
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
      onMessageSent(message, ip, deviceId);
    }
  }

  static Future<void> sendFile(File file, String ip, String? deviceId) async {
    await FileTransferManager.offer(file, ip, deviceId);
  }

  static Future<void> sendAckMessage(String ip, String? messageId) async {
    final ack = CmdAckBean(messageId: messageId);
    final payload = jsonEncode(ack.toJson());
    final payloadUint8 = utf8.encode(payload);
    TextChannel.sendText(payload, payloadUint8, ip);
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
          onMessageReceived(msg);
          sendAckMessage(ip, msg.messageId);
          break;
        case MessageType.rawAck:
          final msg = CmdAckBean.fromJson(json);
          iLog("文本消息解析成功 ACK");
          onAck(msg);
          break;
        case null:
          iLog("文本消息解析失败 from=$ip raw=$text");
          break;
        case MessageType.file:
          _onFileMessage(json, ip);
          sendAckMessage(ip, json['message_id']?.toString());
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
        onMessageReceived(msg);
        FileTransferManager.onOffer(msg, ip);
        break;
      case FileTransferState.rejected:
      case FileTransferState.transferring:
        final msg = ReplySendFileBean.fromJson(json);
        onMessageReceived(msg);
        FileTransferManager.onReply(msg, ip);
        break;
      case FileTransferState.success:
      case FileTransferState.failed:
        final msg = AckFileBean.fromJson(json);
        onMessageReceived(msg);
        FileTransferManager.onAck(msg);
        break;
      case null:
        iLog("未知文件消息 state=${json['state']} from=$ip");
        break;
    }
  }

  static void onMessageSent(Message message, String ip, String? deviceId) {
    message.base?.isSender=true;
    MessageStore.addMessage(message);
    _addMessage(message);

    final messageId = message.messageId;
    if (messageId.isEmpty) return;

    sendingMessages[messageId] = message;

    // 启动定时：500ms 内没收到 ack 则重发，最多重发三次，间隔 500ms；
    // 1500ms 后仍未收到 ack 则标记为发送失败。
    var resentCount = 0;
    _ackTimers[messageId]?.cancel();
    _ackTimers[messageId] = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        if (!sendingMessages.containsKey(messageId)) {
          timer.cancel();
          _ackTimers.remove(messageId);
          return;
        }

        resentCount++;
        if (resentCount <= 3) {
          sendMessage(message, ip, deviceId, resend: true);
        }
        if (resentCount >= 3) {
          message.base?.state = MessageStateType.fail.code;
          message.base?.failTimestampUtc =
              DateTime.now().toUtc().millisecondsSinceEpoch;
          sendingMessages.remove(messageId);
          timer.cancel();
          _ackTimers.remove(messageId);
          MessageStore.onChangeMessage(message);
        }
      },
    );
  }

  static void onMessageReceived(Message message) {
    message.base?.isSender=false;
    MessageStore.addMessage(message);
    _addMessage(message);
  }

  static void updateFile(String transferId, {FileTransferState? state, String? errorMsg, String? localPath, int? current, int? total,}) {
    final offer = _findSendFile(transferId);
    if (offer == null) return;
    offer.transferRecord ??= FileTransferRecord(transferId: transferId, isSender: offer.base?.isSender == true, total: offer.totalSize);
    final record = offer.transferRecord!;
    if (state != null) record.state = state.code;
    if (errorMsg != null) record.errorMessage = errorMsg;
    if (localPath != null) record.localPath = localPath;
    if (current != null) record.current = current;
    if (total != null) record.total = total;

    MessageStore.onChangeMessage(offer);
  }

  static SendFileBean? _findSendFile(String transferId) {
    final conversationId = transferConversationIds[transferId];
    final candidates = conversationId != null
        ? [MessageStore.historyMessages[conversationId] ?? const <Message>[]]
        : MessageStore.historyMessages.values;
    for (final messages in candidates) {
      for (final message in messages) {
        if (message is SendFileBean && message.transferId == transferId) return message;
      }
    }
    return null;
  }

  static void _addMessage(Message message) {
    final transferId = transferIdOf(message);
    final conversationId = message.base?.conversationId;
    if (transferId != null &&
        conversationId != null &&
        !transferConversationIds.containsKey(transferId)) {
      transferConversationIds[transferId] = conversationId;
    }
  }

  static String? transferIdOf(Message message) {
    if (message is SendFileBean) return message.transferId;
    if (message is ReplySendFileBean) return message.transferId;
    if (message is AckFileBean) return message.transferId;
    return null;
  }

  /// 收到 ack
  static void onAck(CmdAckBean ack) {
    final messageId = ack.messageId;
    if (messageId == null) return;
    final message = sendingMessages.remove(messageId);
    _ackTimers.remove(messageId)?.cancel();
    if (message == null) return;

    message.base?.state = MessageStateType.success.code;
    message.base?.successTimestampUtc =
        DateTime.now().toUtc().millisecondsSinceEpoch;
    MessageStore.onChangeMessage(message);
  }
}
