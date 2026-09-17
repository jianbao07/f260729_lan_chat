import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ed25519 身份密钥。共享密钥走 X25519 ECDH，再用 HKDF-SHA256 派生成对称密钥。
///
/// Ed25519 本身是签名算法，不能直接做密钥协商。这里把本机私钥 / 对方公钥
/// 转成 X25519 后再做 ECDH，得到的原始共享秘密再经 KDF 派生，供 [AesCipher] 使用。
class Ed25519Key {
  Ed25519Key._(this.privateKey, this.publicKey);

  static const int keyLength = 32;
  static const int derivedKeyLength = 32;
  static const int signatureLength = 64;

  static const String _privateStorageKey = 'yf_code.ed25519.long_term.private';
  static const String _publicStorageKey = 'yf_code.ed25519.long_term.public';

  static final Ed25519 _ed25519 = Ed25519();
  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: derivedKeyLength);
  static final List<int> _defaultInfo = utf8.encode('yf_code/ed25519-hkdf/aes-256');
  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Ed25519Key? _longTermCache;

  /// 32 字节 Ed25519 seed。
  final Uint8List privateKey;

  /// 32 字节 Ed25519 公钥。
  final Uint8List publicKey;

  /// 32 字节公钥的小写 hex，64 个字符。
  String get publicKeyHex => publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Future<Ed25519Key> generate() async {
    final pair = await _ed25519.newKeyPair();
    return fromPrivateKey(await pair.extractPrivateKeyBytes());
  }

  static Future<Ed25519Key> fromPrivateKey(List<int> privateKey) async {
    if (privateKey.length != keyLength) {
      throw ArgumentError('Ed25519 私钥长度必须是 $keyLength 字节，当前为 ${privateKey.length}');
    }
    final seed = Uint8List.fromList(privateKey);
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final publicKey = await pair.extractPublicKey();
    return Ed25519Key._(seed, Uint8List.fromList(publicKey.bytes));
  }

  /// 直接使用已有公私钥，不由私钥计算公钥。
  static Ed25519Key fromKeyPair(List<int> privateKey, List<int> publicKey) {
    if (privateKey.length != keyLength) {
      throw ArgumentError('Ed25519 私钥长度必须是 $keyLength 字节，当前为 ${privateKey.length}');
    }
    if (publicKey.length != keyLength) {
      throw ArgumentError('Ed25519 公钥长度必须是 $keyLength 字节，当前为 ${publicKey.length}');
    }
    return Ed25519Key._(Uint8List.fromList(privateKey), Uint8List.fromList(publicKey));
  }

  /// 获取本机长期身份密钥。没有则生成，并把公钥、私钥都写入安全存储；读取时不由私钥重算公钥。
  static Future<Ed25519Key> getLongTermKey() async {
    final cached = _longTermCache;
    if (cached != null) return cached;

    final storedPrivate = await _secureStorage.read(key: _privateStorageKey);
    final storedPublic = await _secureStorage.read(key: _publicStorageKey);
    if (storedPrivate != null && storedPublic != null) {
      try {
        return _longTermCache = fromKeyPair(base64Decode(storedPrivate), base64Decode(storedPublic));
      } catch (_) {}
    }

    final key = await generate();
    await _secureStorage.write(key: _privateStorageKey, value: base64Encode(key.privateKey));
    await _secureStorage.write(key: _publicStorageKey, value: base64Encode(key.publicKey));
    return _longTermCache = key;
  }

  /// 每次返回新的临时密钥，不写入存储。
  static Future<Ed25519Key> getTemporaryKey() => generate();

  @visibleForTesting
  static void resetForTest() {
    _longTermCache = null;
  }

  /// 用本机私钥 + 对方 Ed25519 公钥协商，再 HKDF 派生 [derivedKeyLength] 字节对称密钥。
  ///
  /// 双方必须传入相同的 [salt] / [info] 才能得到同一把密钥。
  /// 不传 [salt] 时，用双方公钥按字节序拼接，保证两端结果一致。
  Future<Uint8List> deriveSharedKey(List<int> peerPublicKey, {List<int>? salt, List<int>? info}) async {
    if (peerPublicKey.length != keyLength) {
      throw ArgumentError('Ed25519 公钥长度必须是 $keyLength 字节，当前为 ${peerPublicKey.length}');
    }
    final peer = Uint8List.fromList(peerPublicKey);
    final raw = await _rawSharedSecret(peer);
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(raw),
      nonce: salt ?? _sortedPublicKeys(publicKey, peer),
      info: info ?? _defaultInfo,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// 用本机私钥对 [data] 签名，返回 64 字节 Ed25519 签名。
  Future<Uint8List> sign(List<int> data) async {
    final pair = await _ed25519.newKeyPairFromSeed(privateKey);
    final signature = await _ed25519.sign(data, keyPair: pair);
    return Uint8List.fromList(signature.bytes);
  }

  /// 用 Ed25519 公钥校验 [signature] 是否对应 [data]。
  static Future<bool> verify(List<int> data, {required List<int> signature, required List<int> publicKey}) async {
    if (publicKey.length != keyLength) {
      throw ArgumentError('Ed25519 公钥长度必须是 $keyLength 字节，当前为 ${publicKey.length}');
    }
    if (signature.length != signatureLength) return false;
    return _ed25519.verify(
      data,
      signature: Signature(signature, publicKey: SimplePublicKey(Uint8List.fromList(publicKey), type: KeyPairType.ed25519)),
    );
  }

  Future<Uint8List> _rawSharedSecret(Uint8List peerPublicKey) async {
    final xPrivate = await _ed25519SeedToX25519Private(privateKey);
    final xKeyPair = await _x25519.newKeyPairFromSeed(xPrivate);
    final xPeerPublic = SimplePublicKey(_ed25519PublicToX25519(peerPublicKey), type: KeyPairType.x25519);
    final secret = await _x25519.sharedSecretKey(keyPair: xKeyPair, remotePublicKey: xPeerPublic);
    return Uint8List.fromList(await secret.extractBytes());
  }

  /// Ed25519 seed → X25519 私钥：SHA-512(seed) 前 32 字节再 clamp。
  static Future<Uint8List> _ed25519SeedToX25519Private(Uint8List seed) async {
    final hash = await Sha512().hash(seed);
    final key = Uint8List.fromList(hash.bytes.sublist(0, keyLength));
    key[0] &= 0xf8;
    key[31] &= 0x7f;
    key[31] |= 0x40;
    return key;
  }

  /// Ed25519 公钥（Edwards y）→ X25519 公钥（Montgomery u = (1+y)/(1-y)）。
  static Uint8List _ed25519PublicToX25519(Uint8List edPublicKey) {
    final y = (_leBytesToBigInt(edPublicKey) & ((BigInt.one << 255) - BigInt.one)) % _p;
    final denom = (BigInt.one - y) % _p;
    if (denom == BigInt.zero) {
      throw ArgumentError('无效的 Ed25519 公钥');
    }
    final u = ((BigInt.one + y) * denom.modInverse(_p)) % _p;
    return _bigIntToLe32(u);
  }

  static List<int> _sortedPublicKeys(Uint8List a, Uint8List b) {
    final aFirst = _compareBytes(a, b) <= 0;
    final out = Uint8List(keyLength * 2);
    out.setRange(0, keyLength, aFirst ? a : b);
    out.setRange(keyLength, out.length, aFirst ? b : a);
    return out;
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      if (d != 0) return d;
    }
    return 0;
  }

  static BigInt _leBytesToBigInt(List<int> bytes) {
    var value = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      value = (value << 8) | BigInt.from(bytes[i]);
    }
    return value;
  }

  static Uint8List _bigIntToLe32(BigInt value) {
    final out = Uint8List(32);
    var n = value;
    for (var i = 0; i < 32; i++) {
      out[i] = (n & BigInt.from(0xff)).toInt();
      n >>= 8;
    }
    return out;
  }
}
