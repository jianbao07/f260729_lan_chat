import 'dart:async';
import 'dart:io';

import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';

/// 一次文件传输的运行时会话（按 [transferId] 索引）。
class FileTransferSession {
  FileTransferSession({
    required this.transferId,
    required this.isSender,
    required this.peerIp,
    this.peerDeviceId,
    this.state = FileTransferState.send,
    this.name,
    this.mimeType,
    this.totalSize,
    this.sha256,
    this.port,
    this.localPath,
    this.offerMessage,
    this.server,
  });

  final String transferId;
  final bool isSender;
  FileTransferState state;
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

  /// 发送方 TCP 监听。
  ServerSocket? server;

  Timer? replyTimeout;

  Future<void> closeServer() async {
    replyTimeout?.cancel();
    replyTimeout = null;
    final socket = server;
    server = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
  }
}
