import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/CmdFileBean.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/TextTcpManager.dart';
import 'package:yf_code/utils/log.dart';

class FileTcpManager{
  FileTcpManager(this.ip,this.deviceId);

  final String ip;
  final String? deviceId;
  int totalSize=0;

  Future<void> sendFile(File file,{bool resend=false})async{
    //建立一个serverSocket，获得一个socket
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    iLog("文件发送服务已启动 port=${server.port}");

    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
    totalSize=await file.length();
    final cmdFileBean = CmdFileBean(
      mimeType: _guessMimeType(name),
      name: name,
      totalSize: totalSize,
      port: server.port,
    );
    if (!resend) {
      final fromMessageId = MessageManager.newFromMessageId();
      cmdFileBean.initBase(InitManager.deviceId, deviceId, fromMessageId);
    }

    //使用 TextTcpManager.sendText 发送一条 CmdFileBean 消息
    final payload = jsonEncode(cmdFileBean.toJson());
    final payloadUint8 = utf8.encode(payload);
    await TextTcpManager.sendText(payload, payloadUint8, ip);

    //然后给 CmdFileBean的local_path赋值，赋值后调用 MessageManager.onMessageSent
    cmdFileBean.localPath = file.path;
    if (!resend) {
      MessageManager.onMessageSent(cmdFileBean, ip, deviceId);
    }

    final socket = await server.first;
    //监听文件接受者发送的数据：收到对方已下载大小，继续发送剩余部分
    try {
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
      iLog("文件发送异常: $e");
      socket.destroy();
    } finally {
      await server.close();
    }
  }

  Future<void> startConnection(CmdFileBean cmdFileBean) async {
    //向发送者建立连接，向MessageManager查询sendingMessages的记录是否存在cmdFileBean，如果存在，读取里面的localPath，构建file,读取长度。
    //将文件长度（已接收大小），以4个字节的大小发送给对方（告知已下载大小）
    final port = cmdFileBean.port;
    if (port == null) {
      iLog("文件接收失败：port 为空");
      return;
    }

    final fromMessageId = cmdFileBean.base?.fromMessageId;
    final existing = fromMessageId == null
        ? null
        : MessageManager.sendingMessages[fromMessageId];
    if (existing is CmdFileBean &&
        existing.localPath != null &&
        existing.localPath!.isNotEmpty) {
      cmdFileBean.localPath = existing.localPath;
    }
    if (cmdFileBean.localPath == null || cmdFileBean.localPath!.isEmpty) {
      final name = cmdFileBean.name ?? fromMessageId ?? 'file';
      cmdFileBean.localPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
    }

    final file = File(cmdFileBean.localPath!);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    final receivedSize = await file.length();
    final totalSize = cmdFileBean.totalSize ?? 0;
    iLog("开始接收文件 name=${cmdFileBean.name} received=$receivedSize total=$totalSize");

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
        iLog("文件接收完成 name=${cmdFileBean.name} size=$written");
      } else {
        iLog("文件接收未完成 written=$written total=$totalSize");
      }
    } catch (e) {
      iLog("文件接收异常: $e");
    } finally {
      await raf.close();
      socket.destroy();
    }
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
