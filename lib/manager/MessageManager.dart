import 'dart:async';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
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

  static final Map<String, MessageModel> sessionMessageModels = {};

  static final Map<String, Timer> _ackTimers = {};

  /// 回调发了哪些消息
  static void onMessageSent(Message message, String ip, String? deviceId) {
    _addMessage(message);

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
    _addMessage(message);
  }

  static void updateFile(
    String transferId, {
    FileTransferState? state,
    String? receiverLocalPath,
    String? errorMsg,
    String? localPath,
    int? current,
    int? total,
  }) {
    _applySenderTransfer(transferId, state: state, errorMsg: errorMsg, localPath: localPath, current: current, total: total);
    final sessionId = _transferSessionIds[transferId];
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.updateFile(
      transferId,
      state: state,
      receiverLocalPath: receiverLocalPath,
      current: current,
      total: total,
    );
  }

  static SendFileBean? _findSendFile(String transferId) {
    for (final message in historyMessages) {
      if (message is SendFileBean && message.transferId == transferId) return message;
    }
    return null;
  }

  static void _applySenderTransfer(String transferId, {FileTransferState? state, String? errorMsg, String? localPath, int? current, int? total}) {
    final offer = _findSendFile(transferId);
    if (offer == null) return;
    if (offer.base?.fromDeviceId != InitManager.deviceId) return;
    offer.senderTransfer ??= FileTransferRecord(transferId: transferId, isSender: true, total: offer.totalSize);
    final record = offer.senderTransfer!;
    if (state != null) record.state = state.code;
    if (errorMsg != null) record.errorMessage = errorMsg;
    if (localPath != null) record.localPath = localPath;
    if (current != null) record.current = current;
    if (total != null) record.total = total;
  }

  static void _addMessage(Message message) {
    if (_isExists(message)) return;
    historyMessages.add(message);
    final transferId = _transferIdOf(message);
    final sessionId = message.base?.sessionId;
    if (transferId != null &&
        sessionId != null &&
        !_transferSessionIds.containsKey(transferId)) {
      _transferSessionIds[transferId] = sessionId;
    }
    _getSessionModel(message)?.addMessage(message);
  }

  /// 协议历史中是否已有该消息。
  static bool _isExists(Message message) {
    final fromMessageId = message.base?.fromMessageId;
    if (fromMessageId != null &&
        historyMessages.any((m) => m.base?.fromMessageId == fromMessageId)) {
      return true;
    }
    if (message is SendFileBean) {
      final transferId = message.transferId;
      if (transferId != null && _transferSessionIds.containsKey(transferId)) {
        return true;
      }
    }
    return false;
  }

  static void _notifySession(String? sessionId) {
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.notifyUpdated();
  }

  static MessageModel? _getSessionModel(Message message) {
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
