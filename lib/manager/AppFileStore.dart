import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:yf_code/utils/FileUtils.dart';

/// 应用私有文件仓库：接收落地；发送时仅在无法直接访问原路径时才拷入应用目录。
class AppFileStore {
  AppFileStore._();

  static const _incoming = 'incoming';
  static const _outgoing = 'outgoing';

  static Directory? _root;

  /// 接收文件的本地保存路径。同一 [transferId] 重复调用返回同一路径，便于续传。
  static Future<String> pathForIncoming({required String transferId, String? name}) async {
    final dir = await _subdir(
      '$_incoming${Platform.pathSeparator}${_safeName(transferId, 'transfer')}',
    );
    final fileName = _safeName(name, transferId);
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  /// 原路径可直接读写时原样返回，否则把内容写入应用目录。
  static Future<File> importOutgoing({required String name, String? sourcePath, Stream<List<int>> Function()? openContent}) async {
    if (await canAccessDirectly(sourcePath)) {
      return File(sourcePath!);
    }
    final content = openContent?.call();
    if (content == null) {
      throw StateError('无法直接访问所选文件，且未提供可读内容');
    }
    final dir = await _subdir(_outgoing);
    final fileName = _safeName(name, 'file');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dest = File(
      '${dir.path}${Platform.pathSeparator}${stamp}_$fileName',
    );
    final sink = dest.openWrite();
    try {
      await sink.addStream(content);
    } finally {
      await sink.close();
    }
    return dest;
  }

  /// 已有本地文件：可直接访问则返回原文件，否则拷入应用目录。
  static Future<File> importOutgoingFile(File source, {String? name}) {
    return importOutgoing(
      name: name ?? FileUtils.fileNameOf(source),
      sourcePath: source.path,
      openContent: source.openRead,
    );
  }

  /// 是否能直接按路径打开应用外（或任意本地）文件。
  static Future<bool> canAccessDirectly(String? path) async {
    if (path == null || path.isEmpty) return false;
    if (path.contains('://') && !path.startsWith('file:')) return false;
    final file = File(path);
    try {
      if (!await file.exists()) return false;
      final raf = await file.open();
      try {
        await raf.length();
      } finally {
        await raf.close();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory> _ensureRoot() async {
    final cached = _root;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}files',
    );
    await root.create(recursive: true);
    _root = root;
    return root;
  }

  static Future<Directory> _subdir(String name) async {
    final root = await _ensureRoot();
    final dir = Directory('${root.path}${Platform.pathSeparator}$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _safeName(String? name, String fallback) {
    final raw = (name == null || name.trim().isEmpty) ? fallback : name.trim();
    final base = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll('..', '_');
    return base.isEmpty ? fallback : base;
  }
}
