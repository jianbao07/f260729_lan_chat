import 'dart:io';
import 'dart:typed_data';

import 'package:yf_code/cipher/KeyNegotiator.dart';
import 'package:yf_code/utils/log.dart';


class FileByteChannel {
  FileByteChannel(this.ip, {this.encrypted = false});

  final String ip;
  final bool encrypted;

  Future<ServerSocket> startSendFile(File file, {void Function()? waitConnection, void Function(int current, int total)? onProgress, void Function(String errorMsg)? onSendFailed, void Function()? onSendSuccess}) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    iLog("文件发送服务已启动 port=${server.port}");
    waitConnection?.call();

    _awaitReceiverAndSend(server, file, onProgress, onSendFailed, onSendSuccess);
    return server;
  }

  /// 等待接收方连接，按其上报的已下载偏移继续发送剩余内容。
  Future<void> _awaitReceiverAndSend(ServerSocket server, File file, void Function(int current, int total)? onProgress, void Function(String errorMsg)? onSendFailed, void Function()? onSendSuccess) async {
    Socket? socket;
    try {
      socket = await server.first;
      var headerBuf = Uint8List(0);
      await for (final data in socket) {
        headerBuf = Uint8List.fromList([...headerBuf, ...data]);
        if (headerBuf.length < 4) continue;

        final offset = ByteData.sublistView(headerBuf).getUint32(0);
        final total = await file.length();
        iLog("对方已下载 offset=$offset total=$total path=${file.path} encrypted=$encrypted");
        var current = offset;
        onProgress?.call(current, total);
        if (offset < total) {
          Stream<List<int>> source = file.openRead(offset).map((chunk) {
            current += chunk.length;
            onProgress?.call(current, total);
            return chunk;
          });
          if (encrypted) {
            final aes = KeyNegotiator.cipherOf(ip);
            if (aes == null) {
              throw StateError('加密通道未就绪 ip=$ip');
            }
            source = aes.encryptStream(source);
          }
          await socket.addStream(source);
        }
        await socket.flush();
        await socket.close();
        onSendSuccess?.call();
        break;
      }
    } catch (e) {
      iLog("文件发送结束/异常: $e");
      onSendFailed?.call('$e');
      socket?.destroy();
    } finally {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  /// 向发送方建立连接并接收文件。
  /// 完成后返回实际保存路径。
  Future<String> startReceiveFile({required int port, required String localPath, required int totalSize, String? name, void Function(int current, int total)? onProgress, void Function(String errorMsg)? onReceiveFailed, void Function(String savedPath)? onReceiveSuccess}) async {
    final file = File(localPath);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    final receivedSize = await file.length();
    iLog("开始接收文件 name=$name received=$receivedSize total=$totalSize encrypted=$encrypted");
    onProgress?.call(receivedSize, totalSize);

    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 10),
    );
    final header = ByteData(4)..setUint32(0, receivedSize);
    socket.add(header.buffer.asUint8List());
    await socket.flush();

    final raf = await file.open(mode: FileMode.append);
    var written = receivedSize;
    try {
      Stream<List<int>> incoming = socket;
      if (encrypted && (totalSize <= 0 || written < totalSize)) {
        final aes = KeyNegotiator.cipherOf(ip);
        if (aes == null) {
          throw StateError('加密通道未就绪 ip=$ip');
        }
        incoming = aes.decryptStream(socket);
      }
      await for (final data in incoming) {
        await raf.writeFrom(data);
        written += data.length;
        onProgress?.call(written, totalSize);
        if (!encrypted && totalSize > 0 && written >= totalSize) {
          break;
        }
      }
      await raf.flush();
      if (totalSize > 0 && written >= totalSize) {
        iLog("文件接收完成 name=$name size=$written");
        onReceiveSuccess?.call(localPath);
      } else {
        iLog("文件接收未完成 written=$written total=$totalSize");
        throw StateError('文件接收未完成 written=$written total=$totalSize');
      }
    } catch (e) {
      iLog("文件接收异常: $e");
      onReceiveFailed?.call('$e');
      rethrow;
    } finally {
      await raf.close();
      socket.destroy();
    }
    return localPath;
  }
}