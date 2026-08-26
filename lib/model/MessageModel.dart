import 'package:flutter/cupertino.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileMessageDisplay.dart';
import 'package:yf_code/bean/MessageDisplay.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';

class MessageModel extends ChangeNotifier {
  MessageModel(this.sessionId, List<Message> historyMessages) {
    for (final message in historyMessages) {
      _ingest(message, notify: false);
    }
  }

  String sessionId;
  final List<MessageDisplay> _historyMessages = [];
  final Map<String, FileMessageDisplay> _fileDisplays = {};
  final Map<String, int> _lastProgressNotifyMs = {};

  List<MessageDisplay> get messages => List.unmodifiable(_historyMessages);

  /// 将协议 [Message] 转为 [MessageDisplay] 并入列。
  /// 文本直接入列；文件多条信令聚合为一条 [FileMessageDisplay]。
  void addMessage(Message message) {
    _ingest(message, notify: true);
  }

  void _ingest(Message message, {required bool notify}) {
    if (message is SendFileBean) {
      _upsertFileOffer(message, notify: notify);
      return;
    }
    if (message is ReplySendFileBean) {
      _applyFileReply(message, notify: notify);
      return;
    }
    if (message is AckFileBean) {
      _applyFileAck(message, notify: notify);
      return;
    }
    if (message is MessageDisplay) {
      _historyMessages.add(message as MessageDisplay);
      if (notify) notifyListeners();
    }
  }

  void updateFileState(
    String transferId,
    FileTransferState state, {
    String? receiverLocalPath,
  }) {
    final display = _fileDisplays[transferId];
    if (display == null) return;
    display.setFileState(state);
    if (receiverLocalPath != null) {
      display.receiverLocalPath = receiverLocalPath;
    }
    notifyListeners();
  }

  void updateFileProgress(
    String transferId, {
    int? current,
    int? total,
  }) {
    final display = _fileDisplays[transferId];
    if (display == null) return;
    display.updateProgress(current: current, total: total);
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = display.total ?? 0;
    final done = t > 0 && display.current >= t;
    final last = _lastProgressNotifyMs[transferId] ?? 0;
    if (!done && now - last < 100) return;
    _lastProgressNotifyMs[transferId] = now;
    notifyListeners();
  }

  void notifyUpdated() {
    notifyListeners();
  }

  void _upsertFileOffer(SendFileBean offer, {required bool notify}) {
    final transferId = offer.transferId;
    if (transferId == null || transferId.isEmpty) {
      return;
    }

    final existing = _fileDisplays[transferId];
    if (existing != null) {
      existing.applyOffer(offer);
      if (notify) notifyListeners();
      return;
    }

    final display = FileMessageDisplay(
      transferId: transferId,
      fileState: FileTransferState.send,
      offer: offer,
    );
    _fileDisplays[transferId] = display;
    _historyMessages.add(display);
    if (notify) notifyListeners();
  }

  void _applyFileReply(ReplySendFileBean reply, {required bool notify}) {
    final transferId = reply.transferId;
    if (transferId == null) return;
    final display = _fileDisplays[transferId];
    if (display == null) return;
    display.applyReply(reply);
    if (notify) notifyListeners();
  }

  void _applyFileAck(AckFileBean ack, {required bool notify}) {
    final transferId = ack.transferId;
    if (transferId == null) return;
    final display = _fileDisplays[transferId];
    if (display == null) return;
    display.applyAck(ack);
    if (notify) notifyListeners();
  }
}
