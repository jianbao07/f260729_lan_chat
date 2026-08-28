/// transfer_id : "xxx"
/// state : "send"
/// is_sender : true
/// current : 524
/// total : 63254
/// error_message : "xxx"
/// local_path : "/storage/emulated/0/..../新建文本文件.txt"

class FileTransferRecord {
  FileTransferRecord({
    this.transferId,
    this.state,
    this.isSender,
    this.current,
    this.total,
    this.errorMessage,
    this.localPath,
  });

  FileTransferRecord.fromJson(dynamic json) {
    transferId = json['transfer_id'];
    state = json['state'];
    isSender = json['is_sender'];
    current = json['current'];
    total = json['total'];
    errorMessage = json['error_message'];
    localPath = json['local_path'];
  }

  String? transferId;
  String? state;
  bool? isSender;
  int? current;
  int? total;
  String? errorMessage;

  /// 本地文件路径（发送者或接收者各自赋值）
  String? localPath;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['transfer_id'] = transferId;
    map['state'] = state;
    map['is_sender'] = isSender;
    map['current'] = current;
    map['total'] = total;
    map['error_message'] = errorMessage;
    map['local_path'] = localPath;
    return map;
  }
}