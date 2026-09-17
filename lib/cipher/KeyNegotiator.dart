import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:yf_code/bean/CmdCiphertextOkBean.dart';
import 'package:yf_code/bean/CmdTempPublicKeyBean.dart';
import 'package:yf_code/channel/TextChannel.dart';
import 'package:yf_code/cipher/AesCipher.dart';
import 'package:yf_code/cipher/Ed25519Key.dart';
import 'package:yf_code/enum/CipherSessionState.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/utils/log.dart';

/// [state] 为 [CipherSessionState.failed] 时 [errorMessage] 有值。
class CipherSessionEvent {
  CipherSessionEvent({required this.ip, required this.state, this.errorMessage});
  final String ip;
  final CipherSessionState state;
  final String? errorMessage;
}

/// 监听文本通道连接销毁，用临时 Ed25519 公钥完成密钥协商。
///
/// 外部调用 [start] 后才会作为发起方发送 [CmdTempPublicKeyBean]；未建连时先请求文本通道建连。
/// 对端回临时公钥和 [CmdCiphertextOkBean]。双方用临时钥 ECDH 派生 AES 密钥，确认后标记为可加密传输。
class KeyNegotiator {
  KeyNegotiator._();

  static final Map<String, _Session> _sessions = {};
  static final Map<String, Future<void>> _inflight = {};
  static final StreamController<CipherSessionEvent> _sessionController = StreamController.broadcast();
  static StreamSubscription<TextConnectEvent>? _sub;
  static bool _inited = false;

  /// 加密会话状态变化。可被多处同时 listen。
  static Stream<CipherSessionEvent> get sessionEvents => _sessionController.stream;

  static void init() {
    if (_inited) return;
    _inited = true;
    _sub = TextChannel.connectEvents.listen(_onConnect);
  }

  static bool isReady(String ip) => stateOf(ip) == CipherSessionState.ready;

  static CipherSessionState stateOf(String ip) => _sessions[ip]?.state ?? CipherSessionState.idle;

  static String? errorOf(String ip) => _sessions[ip]?.errorMessage;

  static AesCipher? cipherOf(String ip) {
    final s = _sessions[ip];
    if (s == null || s.state != CipherSessionState.ready) return null;
    return s.aes;
  }

  /// 发起密钥协商。已就绪或正在发送临时公钥则忽略；失败后可再次调用重试。
  static void start(String ip) {
    _enqueue(ip, () => _start(ip));
  }

  static void onTempPublicKey(CmdTempPublicKeyBean msg, String ip) {
    _enqueue(ip, () => _onTempPublicKey(msg, ip));
  }

  static void onCiphertextOk(CmdCiphertextOkBean msg, String ip) {
    _enqueue(ip, () => _onCiphertextOk(msg, ip));
  }

  @visibleForTesting
  static void resetForTest() {
    _inited = false;
    _sub?.cancel();
    _sub = null;
    _sessions.clear();
    _inflight.clear();
  }

  static void _onConnect(TextConnectEvent e) {
    _enqueue(e.ip, () async {
      if (e.isEstablished) return;
      final s = _sessions.remove(e.ip);
      if (s != null) _emit(s, CipherSessionState.idle);
      iLog("密钥协商会话已清除 ip=${e.ip}");
    });
  }

  static Future<void> _start(String ip) async {
    final existing = _sessions[ip];
    if (existing?.state == CipherSessionState.ready) return;
    if (existing?.state == CipherSessionState.establishing && existing!.sentTempKey) return;
    if (existing?.state == CipherSessionState.failed) {
      _sessions.remove(ip);
    }
    final s = _ensureSession(ip);
    _emit(s, CipherSessionState.establishing);
    if (!TextChannel.isConnected(ip)) {
      final result = await TextChannel.ensureConnect(ip);
      if (!identical(_sessions[ip], s)) return;
      if (!result.isSuccess) {
        _fail(s, result.error ?? "连接建立失败");
        return;
      }
    }
    if (!await _sendTempPublicKey(s) && identical(_sessions[ip], s)) {
      _fail(s, "协商消息发送失败");
    }
  }

  static Future<void> _onTempPublicKey(CmdTempPublicKeyBean msg, String ip) async {
    final peerPk = _hexDecode(msg.tempPublicKey);
    final sign = _hexDecode(msg.tempPublicKeySign);
    final idPk = _hexDecode(msg.beatBean?.publicKey);
    if (peerPk == null || peerPk.length != Ed25519Key.keyLength) {
      _fail(_ensureSession(ip), "对方临时公钥无效");
      return;
    }
    if (sign == null || sign.length != Ed25519Key.signatureLength || idPk == null || idPk.length != Ed25519Key.keyLength) {
      _fail(_ensureSession(ip), "对方身份签名无效");
      return;
    }
    if (!await Ed25519Key.verify(peerPk, signature: sign, publicKey: idPk)) {
      _fail(_ensureSession(ip), "对方临时公钥验签失败");
      return;
    }
    if (!await _identityMatchesKnownDevice(msg, ip)) {
      _fail(_ensureSession(ip), "对方身份与已知设备不符");
      return;
    }

    final s = _ensureSession(ip);
    if (s.state == CipherSessionState.idle || s.state == CipherSessionState.failed) {
      _emit(s, CipherSessionState.establishing);
    }
    if (s.peerTempPublic != null && s.sentTempKey) {
      iLog("忽略重复的临时公钥 ip=$ip");
      return;
    }
    s.peerTempPublic = peerPk;
    if (!s.sentTempKey) {
      if (!await _sendTempPublicKey(s) && identical(_sessions[ip], s)) {
        _fail(s, "协商消息发送失败");
        return;
      }
    }
    if (!identical(_sessions[ip], s) || s.localTemp == null || !s.sentTempKey) return;
    s.aes = AesCipher(await s.localTemp!.deriveSharedKey(peerPk));
    if (!await _sendCiphertextOk(s) && identical(_sessions[ip], s)) {
      _fail(s, "协商消息发送失败");
      return;
    }
    final pending = s.pendingOk;
    if (pending != null) {
      s.pendingOk = null;
      await _onCiphertextOk(pending, ip);
    }
  }

  static Future<void> _onCiphertextOk(CmdCiphertextOkBean msg, String ip) async {
    final s = _sessions[ip];
    if (s == null) return;
    if (s.aes == null || s.localTemp == null) {
      s.pendingOk = msg;
      return;
    }
    final raw = msg.peerTempPublicKeyCiphertext;
    if (raw == null || raw.isEmpty) {
      _fail(s, "密钥确认密文为空");
      return;
    }
    try {
      final plain = await s.aes!.decrypt(base64Decode(raw));
      if (!identical(_sessions[ip], s)) return;
      if (!listEquals(plain, s.localTemp!.publicKey)) {
        _fail(s, "密钥确认与本地临时公钥不一致");
        return;
      }
      _emit(s, CipherSessionState.ready);
      iLog("密钥协商完成，可加密传输 ip=$ip");
    } catch (e) {
      _fail(s, "密钥确认解密失败");
    }
  }

  static Future<bool> _sendTempPublicKey(_Session s) async {
    if (s.sentTempKey) return true;
    s.localTemp ??= await Ed25519Key.getTemporaryKey();
    if (!identical(_sessions[s.ip], s) || s.sentTempKey) return identical(_sessions[s.ip], s);
    final longTerm = await Ed25519Key.getLongTermKey();
    if (!identical(_sessions[s.ip], s)) return false;
    final bean = CmdTempPublicKeyBean(
      tempPublicKey: s.localTemp!.publicKeyHex,
      tempPublicKeySign: _hexEncode(await longTerm.sign(s.localTemp!.publicKey)),
      beatBean: await OnlineDeviceManager.getBeatBean(),
    );
    if (!identical(_sessions[s.ip], s)) return false;
    if (!await _sendJson(bean.toJson(), s.ip)) return false;
    s.sentTempKey = true;
    iLog("已发送临时公钥 ip=${s.ip}");
    return true;
  }

  static Future<bool> _sendCiphertextOk(_Session s) async {
    final aes = s.aes;
    final peer = s.peerTempPublic;
    if (aes == null || peer == null) return false;
    if (s.sentCipherOk) return true;
    if (!identical(_sessions[s.ip], s)) return false;
    final cipher = await aes.encrypt(peer);
    if (!identical(_sessions[s.ip], s)) return false;
    if (!await _sendJson(CmdCiphertextOkBean(peerTempPublicKeyCiphertext: base64Encode(cipher)).toJson(), s.ip)) return false;
    s.sentCipherOk = true;
    iLog("已发送密钥确认 ip=${s.ip}");
    return true;
  }

  static Future<bool> _identityMatchesKnownDevice(CmdTempPublicKeyBean msg, String ip) async {
    final deviceId = msg.beatBean?.deviceId;
    if (deviceId == null || deviceId.isEmpty) return true;
    final known = await OnlineDeviceManager.getDeviceInfo(deviceId);
    final knownPk = known?.publicKey;
    if (knownPk == null || knownPk.isEmpty) return true;
    if (knownPk == msg.beatBean?.publicKey) return true;
    iLog("临时公钥身份与已知设备不一致 ip=$ip deviceId=$deviceId");
    return false;
  }

  static _Session _ensureSession(String ip) => _sessions.putIfAbsent(ip, () => _Session(ip));

  static void _emit(_Session s, CipherSessionState state, {String? errorMessage}) {
    final message = state == CipherSessionState.failed ? errorMessage : null;
    if (s.state == state && s.errorMessage == message) return;
    s.state = state;
    s.errorMessage = message;
    _sessionController.add(CipherSessionEvent(ip: s.ip, state: state, errorMessage: message));
  }

  static void _fail(_Session s, String errorMessage) {
    if (!identical(_sessions[s.ip], s)) return;
    if (s.state == CipherSessionState.ready || s.state == CipherSessionState.failed) return;
    iLog("密钥协商失败 ip=${s.ip} err=$errorMessage");
    _emit(s, CipherSessionState.failed, errorMessage: errorMessage);
  }

  static Future<void> _enqueue(String ip, Future<void> Function() action) {
    final next = (_inflight[ip] ?? Future.value()).catchError((_) {}).then((_) async {
      try {
        await action();
      } catch (e) {
        iLog("密钥协商异常 ip=$ip err=$e");
        final s = _sessions[ip];
        if (s != null) _fail(s, "密钥协商异常: $e");
      }
    });
    _inflight[ip] = next;
    return next;
  }

  static Future<bool> _sendJson(Map<String, dynamic> json, String ip) async {
    final payload = utf8.encode(jsonEncode(json));
    iLog("发送协商消息 to=$ip $json");
    final result = await TextChannel.sendText(payload, ip);
    if (!result.isSuccess) {
      iLog("协商消息发送失败 to=$ip err=${result.error}");
    }
    return result.isSuccess;
  }

  static String _hexEncode(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List? _hexDecode(String? hex) {
    if (hex == null || hex.isEmpty || hex.length.isOdd) return null;
    try {
      final out = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}

class _Session {
  _Session(this.ip);
  final String ip;
  Ed25519Key? localTemp;
  Uint8List? peerTempPublic;
  AesCipher? aes;
  CmdCiphertextOkBean? pendingOk;
  bool sentTempKey = false;
  bool sentCipherOk = false;
  CipherSessionState state = CipherSessionState.idle;
  String? errorMessage;
}
