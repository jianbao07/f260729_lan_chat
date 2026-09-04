/// conversationId : "peer_device_abc"
/// lastMessagesPreview : "[文件]"
/// lastMessagesTimestampUtc : 123456
/// conversationDeviceId : "1235d"
/// lastOnlineTimestampUtc : 123456

class ConversationBean {
  ConversationBean({
      this.conversationId,
      this.lastMessagesPreview,
      this.lastMessagesTimestampUtc,
      this.conversationDeviceId,
      this.lastOnlineTimestampUtc,});

  ConversationBean.fromJson(dynamic json) {
    conversationId = json['conversationId'];
    lastMessagesPreview = json['lastMessagesPreview'];
    lastMessagesTimestampUtc = json['lastMessagesTimestampUtc'];
    conversationDeviceId = json['conversationDeviceId'];
    lastOnlineTimestampUtc = json['lastOnlineTimestampUtc'];
  }
  String? conversationId;
  String? lastMessagesPreview;
  int? lastMessagesTimestampUtc;
  String? conversationDeviceId;
  int? lastOnlineTimestampUtc;

  /// 距最后在线超过两个心跳周期（10s）视为离线
  bool isOnline() {
    final ts = lastOnlineTimestampUtc;
    if (ts == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    return DateTime.now().toUtc().difference(last) <= const Duration(seconds: 10);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['conversationId'] = conversationId;
    map['lastMessagesPreview'] = lastMessagesPreview;
    map['lastMessagesTimestampUtc'] = lastMessagesTimestampUtc;
    map['conversationDeviceId'] = conversationDeviceId;
    map['lastOnlineTimestampUtc'] = lastOnlineTimestampUtc;
    return map;
  }

}