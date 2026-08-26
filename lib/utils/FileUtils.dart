
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
}