import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// AES-CTR + HMAC-SHA256（[package:cryptography]）。
///
/// 密文格式：`nonce(16 字节) + CTR 密文 + HMAC(32 字节)`，即 [SecretBox.concatenation]。
/// [encrypt] / [decrypt] 为一次性接口；[encryptStream] / [decryptStream] 为流式接口。
/// 相同 key / IV 下，两种接口对同一明文的密文一致。
class AesCipher {
  AesCipher(Uint8List key, {Uint8List? iv})
      : _algorithm = _ctrForKeyLength(key.length),
        _secretKey = SecretKeyData(Uint8List.fromList(key)),
        _iv = iv == null ? null : Uint8List.fromList(iv) {
    final nonce = _iv;
    if (nonce != null && nonce.length != _algorithm.nonceLength) {
      throw ArgumentError('AES IV 长度必须是 ${_algorithm.nonceLength} 字节，当前为 ${nonce.length}');
    }
  }

  /// 用密码的 SHA-256 作为 32 字节 AES-256 密钥。
  factory AesCipher.fromPassword(String password, {Uint8List? iv}) {
    final digest = crypto.sha256.convert(utf8.encode(password));
    return AesCipher(Uint8List.fromList(digest.bytes), iv: iv);
  }

  static const int ivLength = 16;
  static const int macLength = 32;

  static final AesCtr _aes256 = AesCtr.with256bits(macAlgorithm: Hmac.sha256());

  final AesCtr _algorithm;
  final SecretKeyData _secretKey;
  final Uint8List? _iv;

  static Uint8List randomIv() => Uint8List.fromList(_aes256.newNonce());

  static Uint8List generateKey({int length = 32}) {
    _ctrForKeyLength(length);
    return Uint8List.fromList(SecretKeyData.random(length: length).bytes);
  }

  /// 一次性加密，返回 `nonce + 密文 + MAC`。
  Future<Uint8List> encrypt(List<int> plain) async {
    final box = await _algorithm.encrypt(plain, secretKey: _secretKey, nonce: _nonce());
    return box.concatenation();
  }

  /// 一次性解密，输入须为 `nonce + 密文 + MAC`。
  Future<Uint8List> decrypt(List<int> cipher) async {
    final box = SecretBox.fromConcatenation(
      cipher,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
      copy: false,
    );
    return Uint8List.fromList(await _algorithm.decrypt(box, secretKey: _secretKey));
  }

  /// 流式加密。依次输出 nonce、密文分片、最后一块 MAC。
  Stream<Uint8List> encryptStream(Stream<List<int>> source) async* {
    final nonce = _nonce();
    yield Uint8List.fromList(nonce);
    Mac? mac;
    await for (final chunk in _algorithm.encryptStream(source, secretKey: _secretKey, nonce: nonce, onMac: (m) => mac = m)) {
      if (chunk.isNotEmpty) yield _asUint8List(chunk);
    }
    final macBytes = mac?.bytes;
    if (macBytes != null && macBytes.isNotEmpty) {
      yield Uint8List.fromList(macBytes);
    }
  }

  /// 流式解密。从流开头读取 nonce，末尾读取 MAC，中间按分片解密。
  Stream<Uint8List> decryptStream(Stream<List<int>> source) async* {
    final nonceLen = _algorithm.nonceLength;
    final macLen = _algorithm.macAlgorithm.macLength;
    final pending = BytesBuilder(copy: false);
    final hold = BytesBuilder(copy: false);
    CipherState? state;

    await for (final chunk in source) {
      if (chunk.isEmpty) continue;
      if (state == null) {
        pending.add(chunk);
        if (pending.length < nonceLen) continue;
        final buf = pending.takeBytes();
        state = _algorithm.newState();
        await state.initialize(isEncrypting: false, secretKey: _secretKey, nonce: buf.sublist(0, nonceLen));
        final first = _takeHeldPlain(state, hold, buf.sublist(nonceLen), macLen);
        if (first != null) yield first;
      } else {
        final plain = _takeHeldPlain(state, hold, chunk, macLen);
        if (plain != null) yield plain;
      }
    }

    if (state == null) {
      throw StateError('密文过短，无法读取 nonce');
    }
    if (hold.length != macLen) {
      throw StateError('密文过短，无法读取 MAC');
    }
    final last = await state.convert(const <int>[], expectedMac: Mac(hold.takeBytes()));
    if (last.isNotEmpty) yield _asUint8List(last);
  }

  List<int> _nonce() => _iv ?? _algorithm.newNonce();

  static AesCtr _ctrForKeyLength(int length) {
    final mac = Hmac.sha256();
    switch (length) {
      case 16:
        return AesCtr.with128bits(macAlgorithm: mac);
      case 24:
        return AesCtr.with192bits(macAlgorithm: mac);
      case 32:
        return AesCtr.with256bits(macAlgorithm: mac);
      default:
        throw ArgumentError('AES key 长度必须是 16、24 或 32 字节，当前为 $length');
    }
  }

  /// 暂存末尾 [macLen] 字节作为 MAC，其余送入 [state] 解密。
  static Uint8List? _takeHeldPlain(CipherState state, BytesBuilder hold, List<int> incoming, int macLen) {
    if (incoming.isEmpty) return null;
    if (macLen == 0) {
      final out = state.convertChunkSync(incoming);
      return out.isEmpty ? null : _asUint8List(out);
    }
    hold.add(incoming);
    if (hold.length <= macLen) return null;
    final buf = hold.takeBytes();
    final emitCount = buf.length - macLen;
    hold.add(buf.sublist(emitCount));
    final out = state.convertChunkSync(buf.sublist(0, emitCount));
    return out.isEmpty ? null : _asUint8List(out);
  }

  static Uint8List _asUint8List(List<int> data) {
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}
