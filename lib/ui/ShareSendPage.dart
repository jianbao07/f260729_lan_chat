import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/cipher/KeyNegotiator.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/manager/AppFileStore.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/manager/ShareIntentManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';
import 'package:yf_code/utils/FileUtils.dart';
import 'package:yf_code/utils/page.dart';

class ShareSendPage extends StatefulWidget {
  const ShareSendPage({super.key});

  @override
  State<ShareSendPage> createState() => _ShareSendPageState();
}

class _ShareSendPageState extends State<ShareSendPage> {
  static const int _maxTextBytes = 12 * 1024;

  IncomingShare? _share;
  var _scanning = false;
  var _sending = false;
  var _negotiating = false;
  String? _sendingDeviceId;

  @override
  void initState() {
    super.initState();
    _share = ShareIntentManager.current.value;
    ShareIntentManager.current.addListener(_onShareChanged);
    OnlineDeviceModel.instance.addListener(_onChanged);
    AppSettings.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ShareIntentManager.current.removeListener(_onShareChanged);
    OnlineDeviceModel.instance.removeListener(_onChanged);
    AppSettings.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onShareChanged() {
    if (!mounted) return;
    setState(() => _share = ShareIntentManager.current.value);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    if (_scanning || _sending) return;
    setState(() => _scanning = true);
    OnlineDeviceManager.refreshNow();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _scanning = false);
    showAppToast(context, context.l10n.scanDone(OnlineDeviceModel.instance.deviceList.length));
  }

  Future<void> _sendTo(DeviceBean device) async {
    if (_sending) return;
    final share = _share;
    if (share == null || share.isEmpty) {
      showAppToast(context, context.l10n.shareNothing);
      return;
    }
    final ip = device.ipAddress ?? '';
    if (ip.isEmpty) {
      showAppToast(context, context.l10n.peerAddressInvalid);
      return;
    }
    if (device.deviceId == null || InitManager.deviceId == null) {
      showAppToast(context, context.l10n.deviceNotReady);
      return;
    }

    setState(() {
      _sending = true;
      _negotiating = AppSettings.instance.encryptOn && !KeyNegotiator.isReady(ip);
      _sendingDeviceId = device.deviceId;
    });

    try {
      if (AppSettings.instance.encryptOn) {
        final ready = await KeyNegotiator.ensureReady(ip);
        if (!mounted) return;
        if (!ready) {
          showAppToast(context, localizeError(context.l10n, KeyNegotiator.errorOf(ip)));
          return;
        }
        setState(() => _negotiating = false);
      }

      if (share.hasText) {
        await _sendText(share.text!.trim(), device);
      }
      for (final file in share.files) {
        await _sendFile(file, device);
      }
      if (!mounted) return;
      showAppToast(context, context.l10n.shareSent);
      startPageReplace(context, ChatPage(device: device));
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, context.l10n.shareSendFailed('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _negotiating = false;
          _sendingDeviceId = null;
        });
      }
    }
  }

  Future<void> _sendText(String text, DeviceBean device) async {
    if (utf8.encode(text).length > _maxTextBytes) {
      final local = await AppFileStore.ensureAccessiblePath(
        name: 'shared.txt',
        openContent: () => Stream<List<int>>.fromIterable([utf8.encode(text)]),
      );
      await MessageManager.sendFile(local, device);
      return;
    }
    await MessageManager.sendMessage(MessageTextBean(text: text), device);
  }

  Future<void> _sendFile(IncomingShareFile file, DeviceBean device) async {
    final local = await AppFileStore.ensureAccessiblePath(
      name: file.displayName,
      sourcePath: file.path,
      openContent: () => File(file.path).openRead(),
    );
    await MessageManager.sendFile(local, device);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final share = _share;
    final devices = OnlineDeviceModel.instance.deviceList;
    final encryptOn = AppSettings.instance.encryptOn;

    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _sending ? null : () => gotoBack(context),
                      icon: Icon(Icons.arrow_back, size: 19, color: c.textPrimary),
                    ),
                    Expanded(
                      child: Text(l10n.shareSendTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    ),
                    InkWell(
                      onTap: _sending ? null : _scan,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border),
                        ),
                        child: _scanning
                            ? Padding(
                                padding: const EdgeInsets.all(7),
                                child: CircularProgressIndicator(strokeWidth: 1.6, color: c.textSecondary),
                              )
                            : Icon(Icons.refresh, size: 15, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (share != null) _SharePreview(share: share),
              if (encryptOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: c.online),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l10n.shareEncryptHint, style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '${l10n.shareSendHint} · ${l10n.onlineCount(devices.length)}',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontFamily: kMonoFont),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (devices.isEmpty)
                      EmptyState(text: l10n.noOnlineDevices, sub: l10n.noOnlineDevicesHint)
                    else
                      ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return _DeviceRow(
                            device: device,
                            busy: _sending && _sendingDeviceId == device.deviceId,
                            enabled: !_sending,
                            onTap: () => _sendTo(device),
                          );
                        },
                      ),
                    if (_sending)
                      ColoredBox(
                        color: c.bg.withValues(alpha: 0.72),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _negotiating ? l10n.shareNegotiating : l10n.shareSending,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharePreview extends StatelessWidget {
  const _SharePreview({required this.share});

  final IncomingShare share;

  static String formatSize(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static IconData iconForMime(String? mime) {
    final m = mime ?? '';
    if (m.startsWith('image/')) return Icons.image_outlined;
    if (m.startsWith('video/')) return Icons.movie_outlined;
    if (m.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (m.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (m.contains('zip') || m.contains('compressed')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (share.hasText)
            Text(
              share.text!.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: c.textPrimary),
            ),
          if (share.hasText && share.hasFiles) const SizedBox(height: 8),
          if (share.hasFiles)
            ...share.files.map((file) {
              final path = file.path;
              final image = FileUtils.isImage(mime: file.mimeType, name: file.displayName) && File(path).existsSync();
              int? size;
              try {
                size = File(path).lengthSync();
              } catch (_) {}
              final sizeLabel = formatSize(size);
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image
                          ? Image.file(File(path), width: 40, height: 40, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                          : Container(
                              width: 40,
                              height: 40,
                              color: c.surfaceAlt,
                              child: Icon(iconForMime(file.mimeType), size: 18, color: c.textSecondary),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          if (sizeLabel.isNotEmpty) Text(sizeLabel, style: TextStyle(fontSize: 11.5, color: c.textTertiary, fontFamily: kMonoFont)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (!share.hasText && !share.hasFiles)
            Text(l10n.shareNothing, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.busy, required this.enabled, required this.onTap});

  final DeviceBean device;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rawName = device.name?.isNotEmpty == true ? device.name! : context.l10n.unknownDevice;
    final displayName = AppSettings.instance.displayNameOf(device.deviceId, rawName);
    final id = device.deviceId ?? displayName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              PeerAvatar(id: id, name: displayName, size: 42, online: true, pulse: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.ipAddress ?? '—',
                      style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: kMonoFont),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: c.accent),
                )
              else
                Icon(Icons.send_rounded, size: 16, color: enabled ? c.textTertiary : c.border),
            ],
          ),
        ),
      ),
    );
  }
}
