
import 'dart:convert';
import 'dart:io';

class FileUtils{
  FileUtils._();
  static String mimeTypeOf(File file) {
    return guessMimeType(fileNameOf(file));
  }

  static String fileNameOf(File file) {
    return file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
  }

  static String guessMimeType(String name) {
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

  static bool isImage({String? mime, String? name}) {
    if (mime != null && mime.startsWith('image/')) return true;
    if (name == null || name.isEmpty) return false;
    return guessMimeType(name).startsWith('image/');
  }

  /// 先写临时文件再 rename，避免中途中断把目标 JSON 截成半截。
  static Future<void> writeJsonAtomic(File file, Object data) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    }
  }

  /// 读 JSON；文件缺失、为空或格式损坏时返回 null。
  static Future<dynamic> readJson(File file) async {
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}