
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';
import 'package:yf_code/utils/FileUtils.dart';

class FileMessageDisplay extends IMessageDisplay{
  FileMessageDisplay(this.fileMessage);
  final MessageSendFileBean fileMessage;

  String? get name => fileMessage.name;
  String? get mimeType => fileMessage.mimeType;
  bool get isImage => FileUtils.isImage(mime: mimeType, name: name);
  int? get totalSize => fileMessage.totalSize;
  String? get localPath => fileMessage.transferRecord?.localPath;
  FileTransferState? get fileState=>FileTransferState.fromCode(fileMessage.transferRecord?.state)??FileTransferState.send;
  int? get current => fileMessage.transferRecord?.current;
  int? get total => fileMessage.transferRecord?.total;

  double? get progress {
    final t = fileMessage.totalSize;
    final current=fileMessage.transferRecord?.current;
    if (t == null || t <= 0||current==null) return null;
    return (current / t).clamp(0.0, 1.0);
  }

  Message? get baseMessage => fileMessage;
}