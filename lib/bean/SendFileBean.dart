import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';

/// type : "file"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "send"
/// transfer_id : "xxx"
/// mime_type : "text/plain"
/// name : "新建文本文件.txt"
/// total_size : 15728640
/// sha256 : "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
/// port : 8080
/// sender_transfer : {"transfer_id":"xxx","state":"send","is_sender":true,"local_path":"/storage/emulated/0/..../新建文本文件.txt"}
/// receiver_transfer : {"transfer_id":"xxx","state":"send","is_sender":false,"local_path":"/storage/emulated/0/..../新建文本文件.txt"}

class SendFileBean extends Message {
  SendFileBean({
    this.transferId,
    this.mimeType,
    this.name,
    this.totalSize,
    this.sha256,
    this.port,
    this.senderTransfer,
    this.receiverTransfer,
  });

  SendFileBean.fromJson(dynamic json) {
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    transferId = json['transfer_id'];
    mimeType = json['mime_type'];
    name = json['name'];
    totalSize = json['total_size'];
    sha256 = json['sha256'];
    port = json['port'];
    senderTransfer = json['sender_transfer'] != null
        ? FileTransferRecord.fromJson(json['sender_transfer'])
        : null;
    receiverTransfer = json['receiver_transfer'] != null
        ? FileTransferRecord.fromJson(json['receiver_transfer'])
        : null;
  }

  final String type = MessageType.file.code;
  final String state = FileTransferState.send.code;

  /// 传输 id
  String? transferId;
  String? mimeType;
  String? name;
  int? totalSize;
  String? sha256;
  int? port;

  /// 发送者文件传输状态（由发送者赋值；网络发送时为空）
  FileTransferRecord? senderTransfer;

  /// 接收者文件传输状态（由接收者赋值；网络发送时为空）
  FileTransferRecord? receiverTransfer;

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
    map['port'] = port;
    if (senderTransfer != null) {
      map['sender_transfer'] = senderTransfer?.toJson();
    }
    if (receiverTransfer != null) {
      map['receiver_transfer'] = receiverTransfer?.toJson();
    }
    return map;
  }
}
