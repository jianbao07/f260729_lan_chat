/// transfer_id : "xxx"
/// state : "send"
/// is_sender : true
/// current : 524
/// total : 63254
/// error_message : "xxx"

class FileTransferRecord {
  FileTransferRecord({
      this.transferId, 
      this.state, 
      this.isSender, 
      this.current, 
      this.total,
      this.errorMessage,});

  FileTransferRecord.fromJson(dynamic json) {
    transferId = json['transfer_id'];
    state = json['state'];
    isSender = json['is_sender'];
    current = json['current'];
    total = json['total'];
    errorMessage = json['error_message'];
  }
  String? transferId;
  String? state;
  bool? isSender;
  int? current;
  int? total;
  String? errorMessage;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['transfer_id'] = transferId;
    map['state'] = state;
    map['is_sender'] = isSender;
    map['current'] = current;
    map['total'] = total;
    map['error_message'] = errorMessage;
    return map;
  }

}