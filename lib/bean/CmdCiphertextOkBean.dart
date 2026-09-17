import 'package:yf_code/enum/MessageType.dart';

/// type : "ciphertextOk"
/// peerTempPublicKeyCiphertext : "xxxx"

class CmdCiphertextOkBean {
  CmdCiphertextOkBean({this.peerTempPublicKeyCiphertext});

  CmdCiphertextOkBean.fromJson(dynamic json) {
    peerTempPublicKeyCiphertext = json['peerTempPublicKeyCiphertext'];
  }
  final String type = MessageType.ciphertextOk.code;
  String? peerTempPublicKeyCiphertext;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    map['peerTempPublicKeyCiphertext'] = peerTempPublicKeyCiphertext;
    return map;
  }

}
