import 'dart:io';
import 'dart:typed_data';

import 'package:yf_code/channel/FileSendHandle.dart';
import 'package:yf_code/channel/FileSendParams.dart';
import 'package:yf_code/utils/log.dart';


class FileByteChannel {
  FileByteChannel(this.ip, this.deviceId);

  final String ip;
  final String? deviceId;
  int totalSize = 0;

  /// 从文件路径提取文件名。
  static String fileNameOf(File file) {
    return file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
  }

  /// 根据文件名猜测 MIME 类型。
  static String mimeTypeOf(File file) {
    return _guessMimeType(fileNameOf(file));
  }

  /// 启动文件发送服务并等待接收方连接传输。
  /// 返回可取消的 [FileSendHandle]；不负责构建或发送信令消息。
  Future<FileSendHandle> startSendFile(File file) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    iLog("文件发送服务已启动 port=${server.port}");

    final name = fileNameOf(file);
    final size = await file.length();
    totalSize = size;
    final params = FileSendParams(
      mimeType: _guessMimeType(name),
      name: name,
      totalSize: size,
      port: server.port,
      localPath: file.path,
    );

    final completed = _awaitReceiverAndSend(server, file);
    return FileSendHandle(
      params: params,
      server: server,
      completed: completed,
    );
  }

  /// 等待接收方连接，按其上报的已下载偏移继续发送剩余内容。
  Future<void> _awaitReceiverAndSend(ServerSocket server, File file) async {
    Socket? socket;
    try {
      socket = await server.first;
      var headerBuf = Uint8List(0);
      await for (final data in socket) {
        headerBuf = Uint8List.fromList([...headerBuf, ...data]);
        if (headerBuf.length < 4) continue;

        final offset = ByteData.sublistView(headerBuf).getUint32(0);
        final total = await file.length();
        iLog("对方已下载 offset=$offset total=$total path=${file.path}");
        if (offset < total) {
          await socket.addStream(file.openRead(offset));
        }
        await socket.flush();
        await socket.close();
        break;
      }
    } catch (e) {
      iLog("文件发送结束/异常: $e");
      socket?.destroy();
    } finally {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  /// 默认本地保存路径，供接收方写入。
  static String defaultSavePath({String? name, String? fromMessageId}) {
    final fileName = name ?? fromMessageId ?? 'file';
    return '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
  }

  /// 向发送方建立连接并接收文件。
  /// 完成后返回实际保存路径。
  Future<String> startReceiveFile({
    required int port,
    required String localPath,
    required int totalSize,
    String? name,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    final receivedSize = await file.length();
    iLog("开始接收文件 name=$name received=$receivedSize total=$totalSize");

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
      await for (final data in socket) {
        await raf.writeFrom(data);
        written += data.length;
        if (totalSize > 0 && written >= totalSize) {
          break;
        }
      }
      await raf.flush();
      if (totalSize > 0 && written >= totalSize) {
        iLog("文件接收完成 name=$name size=$written");
      } else {
        iLog("文件接收未完成 written=$written total=$totalSize");
        throw StateError('文件接收未完成 written=$written total=$totalSize');
      }
    } catch (e) {
      iLog("文件接收异常: $e");
      rethrow;
    } finally {
      await raf.close();
      socket.destroy();
    }
    return localPath;
  }

  static String _guessMimeType(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return 'application/octet-stream';
    }
    switch (name.substring(dot + 1).toLowerCase()) {
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'pdf':
        return 'application/pdf';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
