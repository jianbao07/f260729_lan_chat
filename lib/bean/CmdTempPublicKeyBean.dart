import 'package:yf_code/bean/CmdBeatBean.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageStore.dart';

/// type : "tempPublicKey"
/// message_id : "tempPublicKey-xxx"
/// tempPublicKey : "xxxx"
/// tempPublicKeySign : "ffff"
/// beatBean : null

class CmdTempPublicKeyBean {
  CmdTempPublicKeyBean({this.tempPublicKey, this.tempPublicKeySign, this.beatBean}) : messageId = MessageStore.newMessageId(MessageType.tempPublicKey);

  CmdTempPublicKeyBean.fromJson(dynamic json) : messageId = json['message_id']?.toString() ?? '' {
    tempPublicKey = json['tempPublicKey'];
    tempPublicKeySign = json['tempPublicKeySign'];
    beatBean = json['beatBean'] != null ? CmdBeatBean.fromJson(json['beatBean']) : null;
  }
  final String type = MessageType.tempPublicKey.code;
  final String messageId;
  String? tempPublicKey;
  String? tempPublicKeySign;
  CmdBeatBean? beatBean;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    map['message_id'] = messageId;
    map['tempPublicKey'] = tempPublicKey;
    map['tempPublicKeySign'] = tempPublicKeySign;
    if (beatBean != null) {
      map['beatBean'] = beatBean?.toJson();
    }
    return map;
  }
}
