import 'package:flutter/foundation.dart';
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/ConversationBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';

class ConversationModel with ChangeNotifier {
  ConversationModel._();
  static final ConversationModel instance = ConversationModel._();

  final Map<String, ConversationBean> _conversationList = {};

  List<ConversationBean> get deviceList {
    final list = _conversationList.values.toList();
    list.sort((a, b) {
      return (b.lastMessagesTimestampUtc ?? 0).compareTo(a.lastMessagesTimestampUtc ?? 0);
    });
    return List.unmodifiable(list);
  }

  int get deviceCount => _conversationList.length;

  void onConversation(Message message) {
    final conversationId = message.base?.conversationId;
    final deviceId = message.peerDeviceId;
    if (deviceId.isEmpty) return;

    final existing = _conversationList[deviceId];
    final timestamp = message.base?.sendTimestampUtc?.toInt();
    final canPreview = message is MessageTextBean || message is MessageSendFileBean;
    int? lastOnline;
    for (final d in OnlineDeviceModel.instance.deviceList) {
      if (d.deviceId == deviceId) {
        lastOnline = d.updateTimestampUtc?.toInt();
        break;
      }
    }

    if (existing != null) {
      var changed = false;
      if (lastOnline != null && lastOnline > (existing.lastOnlineTimestampUtc ?? 0)) {
        existing.lastOnlineTimestampUtc = lastOnline;
        changed = true;
      }
      if (canPreview) {
        final existingTs = existing.lastMessagesTimestampUtc ?? 0;
        if (timestamp != null && timestamp > existingTs) {
          existing.lastMessagesPreview = _previewOf(message);
          existing.lastMessagesTimestampUtc = timestamp;
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } else {
      _conversationList[deviceId] = ConversationBean(
        conversationId: conversationId,
        lastMessagesPreview: _previewOf(message),
        lastMessagesTimestampUtc: timestamp,
        conversationDeviceId: deviceId,
        lastOnlineTimestampUtc: lastOnline,
      );
      notifyListeners();
    }
  }

  void onDeviceUpdate(DeviceBean device) {
    final deviceId = device.deviceId;
    if (deviceId == null || deviceId.isEmpty) return;
    final existing = _conversationList[deviceId];
    if (existing == null) return;
    final lastOnline = device.updateTimestampUtc?.toInt();
    if (lastOnline == null) return;
    if (lastOnline <= (existing.lastOnlineTimestampUtc ?? 0)) return;
    existing.lastOnlineTimestampUtc = lastOnline;
    notifyListeners();
  }

  String _previewOf(Message message) {
    if (message is MessageTextBean) {
      final text = message.text;
      if (text != null && text.isNotEmpty) return text;
      return '';
    }
    return '[文件]';
  }

  void clear() {
    _conversationList.clear();
    notifyListeners();
  }
}
