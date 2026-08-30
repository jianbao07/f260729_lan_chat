
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';

/***
 * 未使用
 */
class StateMessageDisplay extends IMessageDisplay{
  StateMessageDisplay(this.message);
  final Message message;

  Message? get baseMessage => message;
}