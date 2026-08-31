import 'dart:math';

import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';

class MessageStore {
  MessageStore._();
  static final List<Message> historyMessages = [];
  static final Random _random = Random.secure();

  static void init(){

  }

  static String newMessageId(MessageType type) {
    return '${type.code}-${_generateUuid()}';
  }

  static void getMessage(int pageCount,int pageSize){

  }

  static void onChangeMessage(Message message){

  }

  /// RFC 4122 UUID v4，例如 `550e8400-e29b-41d4-a716-446655440000`
  static String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}