
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';

class TextMessageDisplay extends IMessageDisplay{
  TextMessageDisplay(this.textMessage);
  final MessageTextBean textMessage;

  @override
  Message? get baseMessage => textMessage;
}