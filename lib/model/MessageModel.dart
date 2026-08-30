import 'package:flutter/cupertino.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/model/IMessage/FileMessageDisplay.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';
import 'package:yf_code/model/IMessage/TextMessageDisplay.dart';

class MessageModel extends ChangeNotifier {
  MessageModel(this.sessionId, List<Message> historyMessages) {
    for (var item in historyMessages) {
      _ingest(item);
    }
  }

  String sessionId;
  final List<IMessageDisplay> _messageList = [];

  List<IMessageDisplay> get messages => List.unmodifiable(_messageList);

  void addMessage(Message message) {
    _ingest(message);
    notifyListeners();
  }

  void _ingest(Message message) {
    if (message is SendFileBean) {
      final f=FileMessageDisplay(message);
      _messageList.add(f);
    } else if (message is TextMessageBean) {
      final f=TextMessageDisplay(message);
      _messageList.add(f);
    }else{
      // StateMessageDisplay(message);
    }
  }

  void onChangeMessage(Message message) {
    // _messageList.find((item)=>message==item.getOriMessage());
    notifyListeners();
  }
}
