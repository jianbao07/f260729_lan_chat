import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/MessageDisplay.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';

/// 文件传输在聊天列表中的聚合展示（多条信令 → 一条记录）。
class FileMessageDisplay implements MessageDisplay {
  FileMessageDisplay({
    required this.transferId,
    this.fileState = FileTransferState.send,
    this.offer,
    this.receiverLocalPath,
    this.current = 0,
    int? total,
  }) : total = total ?? offer?.totalSize;

  final String transferId;
  FileTransferState fileState;
  SendFileBean? offer;
  String? receiverLocalPath;

  /// 已传输字节数。
  int current;

  /// 文件总字节数。
  int? total;

  @override
  BaseMessageBean? get base => offer?.base;

  String? get name => offer?.name;
  String? get mimeType => offer?.mimeType;
  int? get totalSize => total ?? offer?.totalSize;
  String? get senderLocalPath => offer?.senderLocalPath;
  String? get localPath => receiverLocalPath ?? senderLocalPath;

  /// 0.0–1.0；总大小未知时返回 null，UI 可走不确定进度。
  double? get progress {
    final t = total;
    if (t == null || t <= 0) return null;
    return (current / t).clamp(0.0, 1.0);
  }

  void applyOffer(SendFileBean message) {
    offer = message;
    fileState = FileTransferState.send;
    total ??= message.totalSize;
  }

  void applyReply(ReplySendFileBean message) {
    final state = FileTransferState.fromCode(message.state ?? '');
    if (state != null) {
      fileState = state;
    }
  }

  void applyAck(AckFileBean message) {
    fileState = FileTransferState.success;
    _markComplete();
    if (message.receiverLocalPath != null) {
      receiverLocalPath = message.receiverLocalPath;
    }
  }

  void setFileState(FileTransferState state) {
    fileState = state;
    if (state == FileTransferState.success) {
      _markComplete();
    }
  }

  void updateProgress({int? current, int? total}) {
    if (current != null) this.current = current;
    if (total != null) this.total = total;
  }

  void _markComplete() {
    final t = total;
    if (t != null) current = t;
  }
}
