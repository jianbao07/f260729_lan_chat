import 'package:flutter/cupertino.dart';
import 'package:yf_code/bean/message/BaseMessageBean.dart';

class MessageModel extends ChangeNotifier {
  MessageModel(this.sessionId, List<Message> historyMessages)
      : _historyMessages = historyMessages;

  String sessionId;
  final List<Message> _historyMessages;

  List<Message> get messages => List.unmodifiable(_historyMessages);

  void addMessage(Message message) {
    _historyMessages.add(message);
    notifyListeners();
  }

  void notifyUpdated() {
    notifyListeners();
  }
}
