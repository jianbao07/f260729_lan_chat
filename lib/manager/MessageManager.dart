import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileMessageBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/CmdCiphertextOkBean.dart';
import 'package:yf_code/bean/CmdTempPublicKeyBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/MessageReplySendFileBean.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/channel/TextChannel.dart';
import 'package:yf_code/cipher/KeyNegotiator.dart';
import 'package:yf_code/utils/log.dart';

class MessageManager {
  MessageManager._();
  static const int MAX_SIZE = 16 * 1024;

  /// 正在发送的协议消息（messageId -> Message）
  static final Map<String, Message> sendingMessages = {};
  static final Map<String, String> transferConversationIds = {};//transfer_id -> conversation_id

  static final Map<String, Timer> _ackTimers = {};

  static Future<void> sendMessage(Message message, DeviceBean device, {bool resend = false}) async {
    if (!resend) {
      message.initBase(InitManager.deviceId, device.deviceId);
    }
    if (message.base == null) {
      iLog("不支持的消息类型，无法发送");
      return;
    }
    FileTransferRecord? savedTransferRecord;
    String? savedAckReceiverPath;
    if (message is MessageSendFileBean) {
      savedTransferRecord = message.transferRecord;
      message.transferRecord = null;
    } else if (message is AckFileMessageBean) {
      savedAckReceiverPath = message.receiverLocalPath;
      message.receiverLocalPath = null;
    }
    final payload = jsonEncode(message.toJson());
    iLog("发送消息 ${payload}");
    if (message is MessageSendFileBean) {
      message.transferRecord = savedTransferRecord;
    } else if (message is AckFileMessageBean) {
      message.receiverLocalPath = savedAckReceiverPath;
    }
    final payloadUint8 = utf8.encode(payload);
    if (payloadUint8.lengthInBytes > MAX_SIZE) {
      iLog("大小超过${MAX_SIZE / 1024}KB，不允许通过text发送，请使用文件发送");
      return;
    }
    final ip = device.ipAddress;
    if (ip == null || ip.isEmpty) {
      iLog("对方地址无效，无法发送");
      return;
    }
    final result = await TextChannel.sendText(payloadUint8, ip);
    if (!result.isSuccess) {
      iLog("消息发送失败 ip=$ip err=${result.error}");
      return;
    }
    if (!resend) {
      onMessageSent(message, device);
    }
  }

  static Future<void> sendFile(File file, DeviceBean device) async {
    await FileTransferManager.offer(file, device);
  }

  static Future<void> sendAckMessage(String ip, String? messageId) async {
    final ack = CmdAckBean(messageId: messageId);
    final payload = jsonEncode(ack.toJson());
    iLog("发送文本消息 ${payload}");
    final payloadUint8 = utf8.encode(payload);
    TextChannel.sendText(payloadUint8, ip);
  }

  static void onTextMessage(String text, String ip) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final typeCode = json['type'] as String?;
      final type = typeCode == null ? null : MessageType.fromCode(typeCode);

      switch (type) {
        case MessageType.text:
          final msg = MessageTextBean.fromJson(json);
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
        case MessageType.tempPublicKey:
          KeyNegotiator.onTempPublicKey(CmdTempPublicKeyBean.fromJson(json), ip);
          break;
        case MessageType.ciphertextOk:
          KeyNegotiator.onCiphertextOk(CmdCiphertextOkBean.fromJson(json), ip);
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
        final msg = MessageSendFileBean.fromJson(json);
        onMessageReceived(msg);
        FileTransferManager.onOffer(msg, ip);
        break;
      case FileTransferState.rejected:
      case FileTransferState.transferring:
        final msg = MessageReplySendFileBean.fromJson(json);
        onMessageReceived(msg);
        FileTransferManager.onReply(msg, ip);
        break;
      case FileTransferState.success:
      case FileTransferState.failed:
        final msg = AckFileMessageBean.fromJson(json);
        onMessageReceived(msg);
        FileTransferManager.onAck(msg);
        break;
      case null:
        iLog("未知文件消息 state=${json['state']} from=$ip");
        break;
    }
  }

  static void onMessageSent(Message message, DeviceBean device) {
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
          sendMessage(message, device, resend: true);
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
    message.base?.arriveTimestampUtc =
        DateTime.now().toUtc().millisecondsSinceEpoch;
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

  static MessageSendFileBean? _findSendFile(String transferId) {
    final conversationId = transferConversationIds[transferId];
    final candidates = conversationId != null
        ? [MessageStore.historyMessages[conversationId] ?? const <Message>[]]
        : MessageStore.historyMessages.values;
    for (final messages in candidates) {
      for (final message in messages) {
        if (message is MessageSendFileBean && message.transferId == transferId) return message;
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
    if (message is MessageSendFileBean) return message.transferId;
    if (message is MessageReplySendFileBean) return message.transferId;
    if (message is AckFileMessageBean) return message.transferId;
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
