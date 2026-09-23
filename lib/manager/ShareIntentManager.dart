import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/pigeon/share_intent_api.g.dart';
import 'package:yf_code/ui/ShareSendPage.dart';
import 'package:yf_code/utils/log.dart';
import 'package:yf_code/utils/page.dart';

class IncomingShareFile {
  IncomingShareFile({required this.path, this.name, this.mimeType});

  final String path;
  final String? name;
  final String? mimeType;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    final seg = path.split(RegExp(r'[\\/]')).last;
    return seg.isEmpty ? 'file' : seg;
  }
}

class IncomingShare {
  IncomingShare({this.text, this.files = const []});

  final String? text;
  final List<IncomingShareFile> files;

  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get hasFiles => files.isNotEmpty;
  bool get isEmpty => !hasText && !hasFiles;
}

class ShareIntentManager {
  ShareIntentManager._();

  static final ValueNotifier<IncomingShare?> current = ValueNotifier(null);
  static bool _inited = false;
  static bool _homeReady = false;
  static bool _pageOpen = false;
  static IncomingShare? _pending;

  static void init() {
    if (_inited) return;
    _inited = true;
    ShareIntentFlutterApi.setUp(_FlutterApi());
    if (!Platform.isAndroid) return;
    ShareIntentHostApi().takePendingShare().then((payload) {
      final share = fromPayload(payload);
      if (share != null) _handle(share);
    }).catchError((e) {
      iLog("读取待处理分享失败: $e");
    });
  }

  static void markHomeReady() {
    _homeReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentIfNeeded());
  }

  static void onPageClosed() {
    _pageOpen = false;
    current.value = null;
  }

  static IncomingShare? fromPayload(SharedPayload? payload) {
    if (payload == null) return null;
    final files = <IncomingShareFile>[];
    for (final item in payload.files ?? const <SharedFileItem>[]) {
      final path = item.path;
      if (path == null || path.isEmpty) continue;
      files.add(IncomingShareFile(path: path, name: item.name, mimeType: item.mimeType));
    }
    final share = IncomingShare(text: payload.text, files: files);
    return share.isEmpty ? null : share;
  }

  static void _handle(IncomingShare share) {
    iLog("收到系统分享 text=${share.hasText} files=${share.files.length}");
    if (_pageOpen) {
      current.value = share;
      _pending = null;
      return;
    }
    _pending = share;
    _presentIfNeeded();
  }

  static void _presentIfNeeded() {
    if (!_homeReady) return;
    final share = _pending;
    if (share == null || share.isEmpty) return;
    final ctx = FileTransferManager.navigatorKey?.currentContext;
    if (ctx == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _presentIfNeeded());
      return;
    }
    _pending = null;
    current.value = share;
    _pageOpen = true;
    startPage(ctx, const ShareSendPage()).whenComplete(onPageClosed);
  }
}

class _FlutterApi implements ShareIntentFlutterApi {
  @override
  void onShareReceived(SharedPayload payload) {
    final share = ShareIntentManager.fromPayload(payload);
    if (share != null) ShareIntentManager._handle(share);
  }
}
