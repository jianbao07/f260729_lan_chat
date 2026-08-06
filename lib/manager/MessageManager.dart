import 'dart:async';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/CmdFileBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/model/MessageModel.dart';

class MessageManager {
  MessageManager._();

  /// 正在发送的消息（from_message_id -> Message）
  static final Map<String, Message> sendingMessages = {};

  /// 历史消息
  static final List<Message> historyMessages = [];

  /// 会话 MessageModel（session_id -> MessageModel）
  static final Map<String, MessageModel> sessionMessageModels = {};

  static final Map<String, Timer> _ackTimers = {};

  /// 回调发了哪些消息
  static void onMessageSent(Message message, String ip, String? deviceId) {
    historyMessages.add(message);
    final sessionId = message.base?.sessionId;
    if (sessionId != null) {
      sessionMessageModels[sessionId]?.addMessage(message);
    }

    final fromMessageId = message.base?.fromMessageId;
    if (fromMessageId == null) return;

    sendingMessages[fromMessageId] = message;

    // 启动定时：500ms 内没收到 ack 则重发，最多重发三次，间隔 500ms；
    // 1500ms 后仍未收到 ack 则标记为发送失败。
    var resentCount = 0;
    _ackTimers[fromMessageId]?.cancel();
    _ackTimers[fromMessageId] = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        if (!sendingMessages.containsKey(fromMessageId)) {
          timer.cancel();
          _ackTimers.remove(fromMessageId);
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
          sendingMessages.remove(fromMessageId);
          timer.cancel();
          _ackTimers.remove(fromMessageId);
          final sid = message.base?.sessionId;
          if (sid != null) {
            sessionMessageModels[sid]?.notifyUpdated();
          }
        }
      },
    );
  }

  /// 回调收到了哪些消息
  static void onMessageReceived(Message message) {
    final fromMessageId = message.base?.fromMessageId;
    if (fromMessageId != null) {
      final exists = historyMessages.any(
        (m) => m.base?.fromMessageId == fromMessageId,
      );
      if (exists) {
        // 重发消息，丢弃
        return;
      }
    }

    historyMessages.add(message);
    final sessionId = message.base?.sessionId;
    if (sessionId != null) {
      sessionMessageModels[sessionId]?.addMessage(message);
    }
  }

  /// 收到 ack
  static void onAck(CmdAckBean ack) {
    final fromMessageId = ack.fromMessageId;
    if (fromMessageId == null) return;
    final message = sendingMessages.remove(fromMessageId);
    _ackTimers.remove(fromMessageId)?.cancel();
    if (message == null) return;

    message.base?.state = MessageStateType.success.code;
    message.base?.successTimestampUtc =
        DateTime.now().toUtc().millisecondsSinceEpoch;
    final sessionId = message.base?.sessionId;
    if (sessionId != null) {
      sessionMessageModels[sessionId]?.notifyUpdated();
    }
  }

  static String newFromMessageId() {
    return "${InitManager.deviceId}-${historyMessages.length}";
  }

  static MessageModel createMessageModel(String sessionId) {
    final existing = sessionMessageModels[sessionId];
    if (existing != null) return existing;

    final messages = historyMessages
        .where((m) => m.base?.sessionId == sessionId)
        .toList();
    final model = MessageModel(sessionId, messages);
    sessionMessageModels[sessionId] = model;
    return model;
  }

  static void destroyMessageModel(String sessionId) {
    sessionMessageModels.remove(sessionId)?.dispose();
  }
}
