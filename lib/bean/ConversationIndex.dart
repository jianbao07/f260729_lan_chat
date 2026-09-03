/// conversationId : "peer_device_abc"
/// currentDir : "/path/to/conversation"
/// totalMessages : 2350
/// totalPages : 24
/// pages : [{"name":"1.json","count":30},{"name":"2.json","count":17}]

class ConversationIndex {
  ConversationIndex({
      this.conversationId,
      this.currentDir,
      this.totalMessages, 
      this.totalPages, 
      this.pages,});

  ConversationIndex.fromJson(dynamic json) {
    conversationId = json['conversationId'];
    currentDir = json['currentDir'];
    totalMessages = json['totalMessages'];
    totalPages = json['totalPages'];
    if (json['pages'] != null) {
      pages = [];
      json['pages'].forEach((v) {
        pages?.add(Pages.fromJson(v));
      });
    }
  }
  String? conversationId;
  String? currentDir;
  int? totalMessages;
  int? totalPages;
  List<Pages>? pages;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['conversationId'] = conversationId;
    map['currentDir'] = currentDir;
    map['totalMessages'] = totalMessages;
    map['totalPages'] = totalPages;
    if (pages != null) {
      map['pages'] = pages?.map((v) => v.toJson()).toList();
    }
    return map;
  }

}

/// name : "name"
/// count : 30

class Pages {
  Pages({
      this.name, 
      this.count,});

  Pages.fromJson(dynamic json) {
    name = json['name'];
    count = json['count'];
  }
  String? name;
  int? count;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['count'] = count;
    return map;
  }

}