import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/utils/page.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({super.key, required this.path, this.name, this.mimeType});

  final String path;
  final String? name;
  final String? mimeType;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  bool _busy = false;

  String get _title {
    final name = widget.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return context.l10n.image;
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.path, mimeType: widget.mimeType, name: widget.name)],
          title: _title,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) showAppToast(context, context.l10n.shareFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _saveToGallery();
      } else {
        await _saveWithPicker();
      }
    } on GalException catch (e) {
      if (!mounted) return;
      showAppToast(context, _galError(e));
    } catch (_) {
      if (mounted) showAppToast(context, context.l10n.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    final l10n = context.l10n;
    final granted = await Gal.hasAccess();
    if (!granted) {
      final ok = await Gal.requestAccess();
      if (!ok) {
        if (mounted) showAppToast(context, l10n.noAlbumPermission);
        return;
      }
    }
    final path = widget.path;
    final sep = path.lastIndexOf(Platform.pathSeparator);
    final dot = path.lastIndexOf('.');
    if (dot > sep) {
      await Gal.putImage(path, album: l10n.appName);
    } else {
      await Gal.putImageBytes(await File(path).readAsBytes(), album: l10n.appName, name: 'image');
    }
    if (mounted) showAppToast(context, l10n.savedToAlbum);
  }

  Future<void> _saveWithPicker() async {
    final location = await getSaveLocation(suggestedName: _title);
    if (location == null) return;
    if (location.path == widget.path) {
      if (mounted) showAppToast(context, context.l10n.saved);
      return;
    }
    await File(widget.path).copy(location.path);
    if (mounted) showAppToast(context, context.l10n.saved);
  }

  String _galError(GalException e) {
    switch (e.type) {
      case GalExceptionType.accessDenied:
        return context.l10n.noAlbumPermission;
      case GalExceptionType.notEnoughSpace:
        return context.l10n.notEnoughSpace;
      case GalExceptionType.notSupportedFormat:
        return context.l10n.unsupportedImageFormat;
      case GalExceptionType.unexpected:
        return context.l10n.saveFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => gotoBack(context),
                    icon: const Icon(Icons.arrow_back, size: 19, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(widget.path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Text(context.l10n.cannotDisplayImage, style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(context.l10n.share),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(context.l10n.save),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
