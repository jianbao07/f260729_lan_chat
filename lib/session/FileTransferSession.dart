import 'dart:async';

import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/channel/FileSendHandle.dart';
import 'package:yf_code/enum/FileStateType.dart';
import 'package:yf_code/channel/FileByteChannel.dart';

/// 一次文件传输的运行时会话（按 [transferId] 索引）。
class FileTransferSession {
  FileTransferSession({
    required this.transferId,
    required this.isSender,
    required this.peerIp,
    this.peerDeviceId,
    this.state = FileStateType.send,
    this.name,
    this.mimeType,
    this.totalSize,
    this.sha256,
    this.port,
    this.localPath,
    this.offerMessage,
    this.sendHandle,
  });

  final String transferId;
  final bool isSender;
  FileStateType state;
  String peerIp;
  String? peerDeviceId;

  String? name;
  String? mimeType;
  int? totalSize;
  String? sha256;
  int? port;
  String? localPath;

  /// 原始 offer，接收方用于构造 Reply / Ack。
  SendFileBean? offerMessage;

  /// 发送方 TCP 监听句柄。
  FileSendHandle? sendHandle;

  Timer? replyTimeout;

  Future<void> closeServer() async {
    replyTimeout?.cancel();
    replyTimeout = null;
    final handle = sendHandle;
    sendHandle = null;
    if (handle != null) {
      await handle.cancel();
    }
  }
}
