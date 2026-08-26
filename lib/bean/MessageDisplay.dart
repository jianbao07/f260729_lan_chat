import 'package:yf_code/bean/BaseMessageBean.dart';

/// 聊天列表展示条目的统一接口。
abstract class MessageDisplay {
  BaseMessageBean? get base;
}
