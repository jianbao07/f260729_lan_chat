import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

/// 常用摘要 / HMAC 工具。结果均为小写 hex。
class CryptoUtils {
  CryptoUtils._();

  static String md5(String text) => md5Bytes(utf8.encode(text));

  static String md5Bytes(List<int> bytes) => crypto.md5.convert(bytes).toString();

  static Future<String> md5File(File file) => _hashFile(file, crypto.md5);

  static String sha1(String text) => sha1Bytes(utf8.encode(text));

  static String sha1Bytes(List<int> bytes) => crypto.sha1.convert(bytes).toString();

  static Future<String> sha1File(File file) => _hashFile(file, crypto.sha1);

  static String sha256(String text) => sha256Bytes(utf8.encode(text));

  static String sha256Bytes(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  static Future<String> sha256File(File file) => _hashFile(file, crypto.sha256);

  static String sha512(String text) => sha512Bytes(utf8.encode(text));

  static String sha512Bytes(List<int> bytes) => crypto.sha512.convert(bytes).toString();

  static Future<String> sha512File(File file) => _hashFile(file, crypto.sha512);

  static String hmacMd5(String text, String key) => hmacMd5Bytes(utf8.encode(text), utf8.encode(key));

  static String hmacMd5Bytes(List<int> bytes, List<int> key) {
    return crypto.Hmac(crypto.md5, key).convert(bytes).toString();
  }

  static String hmacSha256(String text, String key) => hmacSha256Bytes(utf8.encode(text), utf8.encode(key));

  static String hmacSha256Bytes(List<int> bytes, List<int> key) {
    return crypto.Hmac(crypto.sha256, key).convert(bytes).toString();
  }

  static Future<String> _hashFile(File file, crypto.Hash hash) async {
    final digest = await hash.bind(file.openRead()).first;
    return digest.toString();
  }
}
