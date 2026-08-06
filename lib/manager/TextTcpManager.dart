import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yf_code/bean/Result.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/utils/log.dart';
import 'package:yf_code/utils/NetworkUtils.dart';

class TextTcpManager {
  TextTcpManager._();
  static const int _MESSAGE_PORT = 54833;
  static ServerSocket? _serverSocket;
  static final Map<String, Socket> _connectMap = {};
  static String? myIP;
  static bool isInit=false;

  static void init() async {
    if(isInit){
      return;
    }
    isInit=true;
    _startListenerMessage();
    myIP = await NetworkUtils.getWifiIP();
  }

  /// 先发送 4 字节无符号整数（大端）告知 payload 大小，再发送 UTF-8 正文。
  static Future<Result<bool>> sendText(String payload,Uint8List payloadUint8, String ip) async {
    try {
      iLog("发送文本消息 ${payload}");
      final socket = await _getOrCreateConnect(ip);
      final header = ByteData(4)..setUint32(0, payloadUint8.lengthInBytes);
      socket.add(header.buffer.asUint8List());
      socket.add(payloadUint8);
      await socket.flush();
      return Result.success(true);
    } catch (e) {
      iLog("消息发送失败 to=$ip:$_MESSAGE_PORT err=$e");
      _removeConnect(ip);
      return Result.failure("消息发送失败");
    }
  }

  static void _startListenerMessage() async {
    await _serverSocket?.close();
    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      _MESSAGE_PORT,
      shared: true,
    );
    _serverSocket = server;
    iLog("开始监听文本消息=$_MESSAGE_PORT");
    server.listen((client) {
      final ip = client.remoteAddress.address;
      _putConnect(ip, client);
      _listenSocket(client, ip);
    }, onError: (e) {
      iLog("消息服务异常: $e");
    });
  }

  /// 先读 4 字节长度，再按长度读取完整消息。
  static void _listenSocket(Socket client, String ip) {
    final port = client.remotePort;
    var buffer = Uint8List(0);
    int? expectedLength;

    client.listen(
      (data) {
        buffer = Uint8List.fromList([...buffer, ...data]);
        while (true) {
          if (expectedLength == null) {
            if (buffer.length < 4) break;
            expectedLength = ByteData.sublistView(buffer).getUint32(0);
            buffer = buffer.sublist(4);
            continue;
          }
          if (buffer.length < expectedLength!) break;
          final payload = buffer.sublist(0, expectedLength!);
          buffer = buffer.sublist(expectedLength!);
          expectedLength = null;
          final text = utf8.decode(payload);
          iLog("收到文本消息 from=$ip:$port text=$text");
          SendMessageManager.onTextMessage(text, ip);
        }
      },
      onError: (e) {
        iLog("客户端连接异常 from=$ip:$port err=$e");
        _connectMap.remove(_getConnectKey(ip));
        client.destroy();
      },
      onDone: () {
        iLog("连接断开 from=$ip:$port");
        _connectMap.remove(_getConnectKey(ip));
        client.destroy();
      },
      cancelOnError: true,
    );
  }

  static void _putConnect(String ip, Socket socket) {
    final key = _getConnectKey(ip);
    final old = _connectMap[key];
    if (old != null && old != socket) {
      old.destroy();
    }
    _connectMap[key] = socket;
  }

  static void _removeConnect(String ip) {
    final key = _getConnectKey(ip);
    final socket = _connectMap.remove(key);
    socket?.destroy();
  }

  static Future<Socket> _getOrCreateConnect(String ip) async {
    final key = _getConnectKey(ip);
    final existing = _connectMap[key];
    if (existing != null) {
      return existing;
    }
    final socket = await Socket.connect(
      ip,
      _MESSAGE_PORT,
      timeout: const Duration(seconds: 5),
    );
    _putConnect(ip, socket);
    _listenSocket(socket, ip);
    return socket;
  }

  /// key = myIP + ip，ip 值小的放前面
  static String _getConnectKey(String ip) {
    final local = myIP ?? '';
    if (_ipToInt(local) <= _ipToInt(ip)) {
      return '$local|$ip';
    }
    return '$ip|$local';
  }

  static int _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var value = 0;
    for (final part in parts) {
      value = (value << 8) | (int.tryParse(part) ?? 0);
    }
    return value;
  }
}
