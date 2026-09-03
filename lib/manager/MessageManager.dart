import 'dart:async';

import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/manager/SendMessageManager.dart';

class MessageManager {
  MessageManager._();

  /// 正在发送的协议消息（messageId -> Message）
  static final Map<String, Message> sendingMessages = {};
  static final Map<String, String> transferSessionIds = {};//transfer_id -> conversation_id

  static final Map<String, Timer> _ackTimers = {};

  /// 回调发了哪些消息
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
          SendMessageManager.sendMessage(message, ip, deviceId, resend: true);
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

  /// 回调收到了哪些消息
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
    final sessionId = transferSessionIds[transferId];
    final candidates = sessionId != null
        ? [MessageStore.historyMessages[sessionId] ?? const <Message>[]]
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
        !transferSessionIds.containsKey(transferId)) {
      transferSessionIds[transferId] = conversationId;
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
