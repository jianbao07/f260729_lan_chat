import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageStore.dart';

/// transfer_id : "xxx"
/// type : "file"
/// base : {"conversation_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "success"
/// receiver_local_path : "/storage/emulated/0/..../新建文本文件.txt"

class AckFileBean extends Message {
  AckFileBean({
    this.transferId,
    this.state,
    this.receiverLocalPath,
  }) : messageId = MessageStore.newMessageId(MessageType.file);

  AckFileBean.fromJson(dynamic json) : messageId = json['message_id']?.toString() ?? '' {
    transferId = json['transfer_id'];
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    pageName = json['page_name'];
    state = json['state'];
    receiverLocalPath = json['receiver_local_path'];
  }

  String? transferId;
  @override
  MessageType get type => MessageType.file;
  @override
  final String messageId;
  String? state;

  /// 接收者本地保存路径（由接收者赋值；仅本地记录，网络发送时为空）
  String? receiverLocalPath;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['transfer_id'] = transferId;
    map['type'] = type.code;
    map['message_id'] = messageId;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['page_name'] = pageName;
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
      state: FileTransferState.success.code,
      receiverLocalPath: receiverLocalPath,
    );
  }

  static AckFileBean buildFailed(SendFileBean sendFileBean) {
    return AckFileBean(
      transferId: sendFileBean.transferId,
      state: FileTransferState.failed.code,
    );
  }
}
