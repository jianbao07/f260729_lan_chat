import 'dart:io';

import 'package:yf_code/channel/FileSendParams.dart';

/// 一次发送端 TCP 监听句柄，支持在对方拒绝时取消。
class FileSendHandle {
  FileSendHandle({
    required this.params,
    required this.server,
    required this.completed,
  });

  final FileSendParams params;
  final ServerSocket server;
  final Future<void> completed;

  Future<void> cancel() async {
    try {
      await server.close();
    } catch (_) {}
  }
}