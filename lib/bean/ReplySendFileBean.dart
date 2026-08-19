import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileStateType.dart';

/// type : "file"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "rejected"
/// transfer_id : "xxx"
/// mime_type : "text/plain"
/// name : "txt"
/// total_size : 15728640
/// sha256 : "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"

class ReplySendFileBean extends Message {
  ReplySendFileBean({
      this.type, 
      this.state,
      this.transferId,
      this.mimeType, 
      this.name, 
      this.totalSize, 
      this.sha256,});

  ReplySendFileBean.fromJson(dynamic json) {
    type = json['type'];
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    state = json['state'];
    transferId = json['transfer_id'];
    mimeType = json['mime_type'];
    name = json['name'];
    totalSize = json['total_size'];
    sha256 = json['sha256'];
  }
  String? type;
  String? state;
  /// 传输 id
  String? transferId;
  String? mimeType;
  String? name;
  int? totalSize;
  String? sha256;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['state'] = state;
    map['transfer_id'] = transferId;
    map['mime_type'] = mimeType;
    map['name'] = name;
    map['total_size'] = totalSize;
    map['sha256'] = sha256;
    return map;
  }

  static ReplySendFileBean buildRejected(SendFileBean sendFileBean) {
    return ReplySendFileBean(
      type: sendFileBean.type,
      state: FileStateType.rejected.code,
      transferId: sendFileBean.transferId,
      mimeType: sendFileBean.mimeType,
      name: sendFileBean.name,
      totalSize: sendFileBean.totalSize,
      sha256: sendFileBean.sha256,
    );
  }

  static ReplySendFileBean buildAccept(SendFileBean sendFileBean) {
    return ReplySendFileBean(
      type: sendFileBean.type,
      state: FileStateType.transferring.code,
      transferId: sendFileBean.transferId,
      mimeType: sendFileBean.mimeType,
      name: sendFileBean.name,
      totalSize: sendFileBean.totalSize,
      sha256: sendFileBean.sha256,
    );
  }

}