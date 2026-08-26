import 'dart:async';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/model/MessageModel.dart';

class MessageManager {
  MessageManager._();

  /// 正在发送的协议消息（from_message_id -> Message）
  static final Map<String, Message> sendingMessages = {};

  /// 历史协议消息（供 MessageModel 重建展示）
  static final List<Message> historyMessages = [];

  /// transfer_id -> session_id
  static final Map<String, String> _transferSessionIds = {};

  /// 会话 MessageModel（仅页面打开期间存在）
  static final Map<String, MessageModel> sessionMessageModels = {};

  static final Map<String, Timer> _ackTimers = {};

  /// 回调发了哪些消息
  static void onMessageSent(Message message, String ip, String? deviceId) {
    _ingest(message);

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
          _notifySession(message.base?.sessionId);
        }
      },
    );
  }

  /// 回调收到了哪些消息
  static void onMessageReceived(Message message) {
    _ingest(message);
  }

  static void applyFileReply(ReplySendFileBean reply) {
    _ingest(reply);
  }

  static void applyFileAck(AckFileBean ack) {
    _ingest(ack);
  }

  static void updateFileState(
    String transferId,
    FileTransferState state, {
    String? receiverLocalPath,
  }) {
    final sessionId = _transferSessionIds[transferId];
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.updateFileState(
      transferId,
      state,
      receiverLocalPath: receiverLocalPath,
    );
  }

  static void updateFileProgress(
    String transferId, {
    int? current,
    int? total,
  }) {
    final sessionId = _transferSessionIds[transferId];
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.updateFileProgress(
      transferId,
      current: current,
      total: total,
    );
  }

  static void _ingest(Message message) {
    if (!_store(message)) return;
    _existingModel(message)?.addMessage(message);
  }

  /// 写入协议历史。重复消息返回 false。
  static bool _store(Message message) {
    final fromMessageId = message.base?.fromMessageId;
    if (fromMessageId != null &&
        historyMessages.any((m) => m.base?.fromMessageId == fromMessageId)) {
      return false;
    }
    if (message is SendFileBean) {
      final transferId = message.transferId;
      if (transferId != null && _transferSessionIds.containsKey(transferId)) {
        return false;
      }
    }

    historyMessages.add(message);
    final transferId = _transferIdOf(message);
    final sessionId = message.base?.sessionId;
    if (transferId != null &&
        sessionId != null &&
        !_transferSessionIds.containsKey(transferId)) {
      _transferSessionIds[transferId] = sessionId;
    }
    return true;
  }

  static void _notifySession(String? sessionId) {
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.notifyUpdated();
  }

  static MessageModel? _existingModel(Message message) {
    final sessionId = message.base?.sessionId ??
        _sessionIdOfTransfer(_transferIdOf(message));
    if (sessionId == null) return null;
    return sessionMessageModels[sessionId];
  }

  static String? _sessionIdOfTransfer(String? transferId) {
    if (transferId == null) return null;
    return _transferSessionIds[transferId];
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

    _notifySession(message.base?.sessionId);
  }

  static String? _transferIdOf(Message message) {
    if (message is SendFileBean) return message.transferId;
    if (message is ReplySendFileBean) return message.transferId;
    if (message is AckFileBean) return message.transferId;
    return null;
  }

  static String newFromMessageId() {
    return "${InitManager.deviceId}-${historyMessages.length}";
  }

  static MessageModel createMessageModel(String sessionId) {
    final existing = sessionMessageModels[sessionId];
    if (existing != null) return existing;

    final messages = historyMessages.where((message) {
      final sid = message.base?.sessionId ??
          _sessionIdOfTransfer(_transferIdOf(message));
      return sid == sessionId;
    }).toList();
    final model = MessageModel(sessionId, messages);
    sessionMessageModels[sessionId] = model;
    return model;
  }

  static void destroyMessageModel(String sessionId) {
    sessionMessageModels.remove(sessionId)?.dispose();
  }
}
