import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageStore.dart';

/// transfer_id : "xxx"
/// type : "file"
/// base : {"conversation_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"arrive_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "success"
/// receiver_local_path : "/storage/emulated/0/..../新建文本文件.txt"

class AckFileMessageBean extends Message {
  AckFileMessageBean({
    this.transferId,
    this.state,
    this.receiverLocalPath,
  }) : messageId = MessageStore.newMessageId(MessageType.file);

  AckFileMessageBean.fromJson(dynamic json) : messageId = json['message_id']?.toString() ?? '' {
    transferId = json['transfer_id'];
    base = json['base'] != null ? MessageBaseBean.fromJson(json['base']) : null;
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

  static AckFileMessageBean buildSuccess(
    MessageSendFileBean sendFileBean, {
    String? receiverLocalPath,
  }) {
    return AckFileMessageBean(
      transferId: sendFileBean.transferId,
      state: FileTransferState.success.code,
      receiverLocalPath: receiverLocalPath,
    );
  }

  static AckFileMessageBean buildFailed(MessageSendFileBean sendFileBean) {
    return AckFileMessageBean(
      transferId: sendFileBean.transferId,
      state: FileTransferState.failed.code,
    );
  }
}
