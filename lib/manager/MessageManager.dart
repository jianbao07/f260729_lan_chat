import 'dart:async';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/CmdAckBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileMessageDisplay.dart';
import 'package:yf_code/bean/MessageDisplay.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileStateType.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/model/MessageModel.dart';

class MessageManager {
  MessageManager._();

  /// 正在发送的协议消息（from_message_id -> Message）
  static final Map<String, Message> sendingMessages = {};

  /// 历史展示消息（文本直接入列；文件为 [FileMessageDisplay]）
  static final List<MessageDisplay> historyMessages = [];

  /// transfer_id -> 文件展示条目
  static final Map<String, FileMessageDisplay> fileDisplays = {};

  /// 会话 MessageModel（session_id -> MessageModel）
  static final Map<String, MessageModel> sessionMessageModels = {};

  static final Map<String, Timer> _ackTimers = {};

  /// 回调发了哪些消息
  static void onMessageSent(Message message, String ip, String? deviceId) {
    _ingestForDisplay(message);

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
      // 文件 offer 也可能按 transfer_id 已存在
      if (message is SendFileBean) {
        final tid = message.transferId;
        if (tid != null && fileDisplays.containsKey(tid)) {
          return;
        }
      }
    }

    _ingestForDisplay(message);
  }

  static void _ingestForDisplay(Message message) {
    if (message is SendFileBean) {
      upsertFileOffer(message);
      return;
    }
    if (message is ReplySendFileBean) {
      applyFileReply(message);
      return;
    }
    if (message is AckFileBean) {
      applyFileAck(message);
      return;
    }
    if (message is MessageDisplay) {
      final display = message as MessageDisplay;
      historyMessages.add(display);
      final sessionId = display.base?.sessionId;
      if (sessionId != null) {
        sessionMessageModels[sessionId]?.addMessage(display);
      }
    }
  }

  /// 按 transfer_id 新建或更新文件展示（offer）。
  static FileMessageDisplay? upsertFileOffer(SendFileBean offer) {
    final transferId = offer.transferId;
    if (transferId == null || transferId.isEmpty) {
      return null;
    }

    final existing = fileDisplays[transferId];
    if (existing != null) {
      existing.applyOffer(offer);
      _notifySession(existing.base?.sessionId);
      return existing;
    }

    final display = FileMessageDisplay(
      transferId: transferId,
      fileState: FileStateType.send,
      offer: offer,
    );
    fileDisplays[transferId] = display;
    historyMessages.add(display);
    final sessionId = display.base?.sessionId;
    if (sessionId != null) {
      sessionMessageModels[sessionId]?.addMessage(display);
    }
    return display;
  }

  static void applyFileReply(ReplySendFileBean reply) {
    final transferId = reply.transferId;
    if (transferId == null) return;
    final display = fileDisplays[transferId];
    if (display == null) return;
    display.applyReply(reply);
    _notifySession(display.base?.sessionId);
  }

  static void applyFileAck(AckFileBean ack) {
    final transferId = ack.transferId;
    if (transferId == null) return;
    final display = fileDisplays[transferId];
    if (display == null) return;
    display.applyAck(ack);
    _notifySession(display.base?.sessionId);
  }

  static void updateFileState(
    String transferId,
    FileStateType state, {
    String? receiverLocalPath,
  }) {
    final display = fileDisplays[transferId];
    if (display == null) return;
    display.setFileState(state);
    if (receiverLocalPath != null) {
      display.receiverLocalPath = receiverLocalPath;
    }
    _notifySession(display.base?.sessionId);
  }

  static FileMessageDisplay? getFileDisplay(String transferId) {
    return fileDisplays[transferId];
  }

  static void _notifySession(String? sessionId) {
    if (sessionId == null) return;
    sessionMessageModels[sessionId]?.notifyUpdated();
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

    // 文件展示气泡的送达态来自 offer.base
    if (message is SendFileBean) {
      _notifySession(message.base?.sessionId);
    } else if (message is MessageDisplay) {
      _notifySession(message.base?.sessionId);
    } else {
      final tid = _transferIdOf(message);
      if (tid != null) {
        _notifySession(fileDisplays[tid]?.base?.sessionId);
      } else {
        _notifySession(message.base?.sessionId);
      }
    }
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
