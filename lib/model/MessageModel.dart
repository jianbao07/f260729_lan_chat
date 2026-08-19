import 'package:flutter/cupertino.dart';
import 'package:yf_code/bean/MessageDisplay.dart';

class MessageModel extends ChangeNotifier {
  MessageModel(this.sessionId, List<MessageDisplay> historyMessages)
      : _historyMessages = historyMessages;

  String sessionId;
  final List<MessageDisplay> _historyMessages;

  List<MessageDisplay> get messages => List.unmodifiable(_historyMessages);

  void addMessage(MessageDisplay message) {
    _historyMessages.add(message);
    notifyListeners();
  }

  void notifyUpdated() {
    notifyListeners();
  }
}
