import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/manager/MessageStore.dart';

/// type : "file"
/// base : {"conversation_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// state : "send"
/// transfer_id : "xxx"
/// mime_type : "text/plain"
/// name : "新建文本文件.txt"
/// total_size : 15728640
/// sha256 : "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
/// port : 8080
/// encrypted : true
/// transfer_record : {"transfer_id":"xxx","state":"send","is_sender":true,"local_path":"/storage/emulated/0/..../新建文本文件.txt"}

class MessageSendFileBean extends Message {
  MessageSendFileBean({
    this.transferId,
    this.mimeType,
    this.name,
    this.totalSize,
    this.sha256,
    this.port,
    this.encrypted = false,
    this.transferRecord,
  }) : messageId = MessageStore.newMessageId(MessageType.file);

  MessageSendFileBean.fromJson(dynamic json) : messageId = json['message_id']?.toString() ?? '' {
    base = json['base'] != null ? MessageBaseBean.fromJson(json['base']) : null;
    pageName = json['page_name'];
    transferId = json['transfer_id'];
    mimeType = json['mime_type'];
    name = json['name'];
    totalSize = json['total_size'];
    sha256 = json['sha256'];
    port = json['port'];
    encrypted = json['encrypted'] == true;
    transferRecord = json['transfer_record'] != null ? FileTransferRecord.fromJson(json['transfer_record']) : null;
  }

  @override
  MessageType get type => MessageType.file;
  @override
  final String messageId;
  final String state = FileTransferState.send.code;

  /// 传输 id
  String? transferId;
  String? mimeType;
  String? name;
  int? totalSize;
  String? sha256;
  int? port;

  /// 发送方赋值：TCP 文件内容是否 AES 加密。
  bool encrypted=false;

  /// 本端文件传输状态（由本地维护；网络发送时为空）
  FileTransferRecord? transferRecord;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type.code;
    map['message_id'] = messageId;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['page_name'] = pageName;
    map['state'] = state;
    map['transfer_id'] = transferId;
    map['mime_type'] = mimeType;
    map['name'] = name;
    map['total_size'] = totalSize;
    map['sha256'] = sha256;
    map['port'] = port;
    map['encrypted'] = encrypted;
    if (transferRecord != null) {
      map['transfer_record'] = transferRecord?.toJson();
    }
    return map;
  }
}
