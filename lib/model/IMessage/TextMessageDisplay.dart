
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';

class TextMessageDisplay extends IMessageDisplay{
  TextMessageDisplay(this.textMessage);
  final TextMessageBean textMessage;

  @override
  Message? get baseMessage => textMessage;
}