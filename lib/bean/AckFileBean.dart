import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileStateType.dart';

/// transfer_id : "xxx"
/// type : "file"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "success"
/// receiver_local_path : "/storage/emulated/0/..../新建文本文件.txt"

class AckFileBean extends Message {
  AckFileBean({
    this.transferId,
    this.type,
    this.state,
    this.receiverLocalPath,
  });

  AckFileBean.fromJson(dynamic json) {
    transferId = json['transfer_id'];
    type = json['type'];
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    state = json['state'];
    receiverLocalPath = json['receiver_local_path'];
  }

  String? transferId;
  String? type;
  String? state;

  /// 接收者本地保存路径（由接收者赋值；仅本地记录，网络发送时为空）
  String? receiverLocalPath;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['transfer_id'] = transferId;
    map['type'] = type;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['state'] = state;
    map['receiver_local_path'] = receiverLocalPath;
    return map;
  }

  static AckFileBean buildSuccess(
    SendFileBean sendFileBean, {
    String? receiverLocalPath,
  }) {
    return AckFileBean(
      transferId: sendFileBean.transferId,
      type: sendFileBean.type,
      state: FileStateType.success.code,
      receiverLocalPath: receiverLocalPath,
    );
  }
}
