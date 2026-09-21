import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yf_code/bean/Result.dart';
import 'package:yf_code/cipher/KeyNegotiator.dart';
import 'package:yf_code/enum/PayloadType.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/l10n/app_error_code.dart';
import 'package:yf_code/utils/log.dart';

/// [isOutgoing] true=本机发起，false=对端连入；[isEstablished] true=建立，false=销毁。
class TextConnectEvent {
  TextConnectEvent({required this.ip, required this.isOutgoing, required this.isEstablished});
  final String ip;
  final bool isOutgoing;
  final bool isEstablished;
}

class _TextConnect {
  _TextConnect({required this.ip, required this.socket, required this.isOutgoing});
  final String ip;
  final Socket socket;
  final bool isOutgoing;
  bool closed = false;
}

class TextChannel {
  TextChannel._();
  static const int _MESSAGE_PORT = 54833;
  static const int _PROTOCOL_VERSION = 1;
  static const int _HEADER_SIZE = 8;
  static ServerSocket? _serverSocket;
  static final Map<String, _TextConnect> _connectMap = {};
  static final StreamController<TextConnectEvent> _connectEventController = StreamController.broadcast();
  static bool isInit=false;

  /// 连接建立、销毁事件。可被多处同时 listen。
  static Stream<TextConnectEvent> get connectEvents => _connectEventController.stream;

  static bool isConnected(String ip) {
    final c = _connectMap[ip];
    return c != null && !c.closed;
  }

  /// 没有连接则主动拨号，已有则复用。只建连，不发业务数据。
  static Future<Result<bool>> ensureConnect(String ip) async {
    try {
      await _getOrCreateConnect(ip);
      return Result.success(true);
    } catch (e) {
      iLog("建立文本连接失败 to=$ip:$_MESSAGE_PORT err=$e");
      _removeConnect(ip);
      return Result.failure(AppErrorCode.connectFailed);
    }
  }

  static void init() async {
    if(isInit){
      return;
    }
    isInit=true;
    _startListenerLink();
  }

  /// 发送明文 JSON 荷载；开启加密且密钥就绪时在通道内加密为 jsonStringCipher。
  static Future<Result<bool>> sendText(Uint8List plainPayload, String ip) async {
    try {
      var body = plainPayload;
      var type = PayloadType.jsonString;
      if (AppSettings.instance.encryptOn && KeyNegotiator.isReady(ip)) {
        final aes = KeyNegotiator.cipherOf(ip);
        if (aes == null) return Result.failure(AppErrorCode.cipherNotReady);
        body = Uint8List.fromList(await aes.encrypt(plainPayload));
        type = PayloadType.jsonStringCipher;
      }
      final socket = await _getOrCreateConnect(ip);
      socket.add(_buildHeader(type, body.lengthInBytes));
      socket.add(body);
      await socket.flush();
      return Result.success(true);
    } catch (e) {
      iLog("消息发送失败 to=$ip:$_MESSAGE_PORT err=$e");
      _removeConnect(ip);
      return Result.failure(AppErrorCode.sendFailed);
    }
  }

  static Uint8List _buildHeader(PayloadType type, int payloadLength) {
    final header = ByteData(_HEADER_SIZE);
    header.setUint8(0, _PROTOCOL_VERSION);
    header.setUint8(1, type.code);
    header.setUint32(2, payloadLength);
    header.setUint16(6, 0);
    return header.buffer.asUint8List();
  }

  static void _startListenerLink() async {
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
      iLog("收到连接-ip=${ip}");
      final conn = _putConnect(ip, client, isOutgoing: false);
      _listenMessage(conn);
    }, onError: (e) {
      iLog("消息服务异常: $e");
    });
  }

  /// 先读 8 字节头（版本、荷载类型、长度、预留），再按长度读取完整消息。
  static void _listenMessage(_TextConnect conn) {
    final client = conn.socket;
    final ip = conn.ip;
    final port = client.remotePort;
    var buffer = Uint8List(0);
    int? expectedLength;
    PayloadType? payloadType;

    client.listen(
      (data) async{
        buffer = Uint8List.fromList([...buffer, ...data]);
        while (true) {
          if (expectedLength == null) {
            if (buffer.length < _HEADER_SIZE) break;
            final header = ByteData.sublistView(buffer);
            final version = header.getUint8(0);
            payloadType = PayloadType.fromCode(header.getUint8(1));
            expectedLength = header.getUint32(2);
            buffer = buffer.sublist(_HEADER_SIZE);
            if (version != _PROTOCOL_VERSION) {
              iLog("文本通道协议版本不匹配 version=$version expected=$_PROTOCOL_VERSION from=$ip:$port");
            }
            continue;
          }
          if (buffer.length < expectedLength!) break;
          final payload = buffer.sublist(0, expectedLength!);
          buffer = buffer.sublist(expectedLength!);
          expectedLength = null;
          final type = payloadType;
          payloadType = null;
          switch (type) {
            case PayloadType.jsonString:
              final text = utf8.decode(payload);
              iLog("收到文本消息 from=$ip:$port text=$text");
              MessageManager.onTextMessage(text, ip);
            case PayloadType.jsonStringCipher:
              final aes = KeyNegotiator.cipherOf(ip);
              if (aes == null) {
                iLog("收到密文但未协商密钥 from=$ip");
                return;
              }
              try {
                final text = utf8.decode(await aes.decrypt(payload));
                iLog("收到密文文本消息 from=$ip:$port text=$text");
                MessageManager.onTextMessage(text, ip);
              } catch (e) {
                iLog("密文解密失败 from=$ip err=$e");
              }
              break;
            default:
              iLog("未处理的荷载类型 type=$type from=$ip:$port size=${payload.length}");
          }
        }
      },
      onError: (e) {
        iLog("客户端连接异常 from=$ip:$port err=$e");
        _closeConnect(conn);
      },
      onDone: () {
        iLog("连接断开 from=$ip:$port");
        _closeConnect(conn);
      },
      cancelOnError: true,
    );
  }

  static _TextConnect _putConnect(String ip, Socket socket, {required bool isOutgoing}) {
    final old = _connectMap[ip];
    if (old != null && !identical(old.socket, socket)) {
      _closeConnect(old);
    }
    final conn = _TextConnect(ip: ip, socket: socket, isOutgoing: isOutgoing);
    _connectMap[ip] = conn;
    _emitConnectEvent(conn, isEstablished: true);
    return conn;
  }

  static void _removeConnect(String ip) {
    final conn = _connectMap[ip];
    if (conn == null) return;
    _closeConnect(conn);
  }

  static void _closeConnect(_TextConnect conn) {
    if (conn.closed) return;
    conn.closed = true;
    if (identical(_connectMap[conn.ip], conn)) {
      _connectMap.remove(conn.ip);
    }
    _emitConnectEvent(conn, isEstablished: false);
    conn.socket.destroy();
  }

  static void _emitConnectEvent(_TextConnect conn, {required bool isEstablished}) {
    _connectEventController.add(TextConnectEvent(
      ip: conn.ip,
      isOutgoing: conn.isOutgoing,
      isEstablished: isEstablished,
    ));
  }

  static Future<Socket> _getOrCreateConnect(String ip) async {
    final existing = _connectMap[ip];
    if (existing != null) {
      return existing.socket;
    }
    final socket = await Socket.connect(
      ip,
      _MESSAGE_PORT,
      timeout: const Duration(seconds: 5),
    );
    iLog("发起连接-ip=$ip");
    final conn = _putConnect(ip, socket, isOutgoing: true);
    _listenMessage(conn);
    return socket;
  }
}
