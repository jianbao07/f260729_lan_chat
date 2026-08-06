import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';

/// type : "file"
/// base : {"session_id":"xxx","from_device_id":"xxx","to_device_id":"yyy","send_timestamp_utc":1785173158277,"success_timestamp_utc":1785173158277,"fail_timestamp_utc":1785173158277,"state":"sending"}
/// mime_type : "text/plain"
/// name : "新建文本文件.txt"
/// total_size : 15728640
/// sha256 : "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
/// port : 8080
/// local_path : "/storage/emulated/0/..../新建文本文件.txt"

class CmdFileBean extends Message {
  CmdFileBean({
      this.mimeType,
      this.name,
      this.totalSize,
      this.sha256,
      this.port,
      this.localPath,});

  CmdFileBean.fromJson(dynamic json) {
    base = json['base'] != null ? BaseMessageBean.fromJson(json['base']) : null;
    mimeType = json['mime_type'];
    name = json['name'];
    totalSize = json['total_size'];
    sha256 = json['sha256'];
    port = json['port'];
    localPath = json['local_path'];
  }
  final String type = MessageType.file.code;
  String? mimeType;
  String? name;
  int? totalSize;
  String? sha256;
  int? port;
  /// 本机目标文件路径（发送方为源文件路径，接收方为保存路径）
  String? localPath;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['type'] = type;
    if (base != null) {
      map['base'] = base?.toJson();
    }
    map['mime_type'] = mimeType;
    map['name'] = name;
    map['total_size'] = totalSize;
    map['sha256'] = sha256;
    map['port'] = port;
    map['local_path'] = localPath;
    return map;
  }

}
