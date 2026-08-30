
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';

class FileMessageDisplay extends IMessageDisplay{
  FileMessageDisplay(this.fileMessage);
  final SendFileBean fileMessage;

  String? get name => fileMessage.name;
  String? get mimeType => fileMessage.mimeType;
  int? get totalSize => fileMessage.totalSize;
  FileTransferRecord? get transferRecord => fileMessage.base?.isSender==true?fileMessage.senderTransfer:fileMessage.receiverTransfer;
  String? get localPath => transferRecord?.localPath;
  FileTransferState? get fileState=>FileTransferState.fromCode(transferRecord?.state);
  int? get current => transferRecord?.current;
  int? get total => transferRecord?.total;

  double? get progress {
    final t = fileMessage.totalSize;
    final current=transferRecord?.current;
    if (t == null || t <= 0||current==null) return null;
    return (current / t).clamp(0.0, 1.0);
  }

  Message? get baseMessage => fileMessage;
}