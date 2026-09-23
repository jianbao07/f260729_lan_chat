import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/AppFileStore.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/cipher/KeyNegotiator.dart';
import 'package:yf_code/enum/CipherSessionState.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/IMessage/FileMessageDisplay.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';
import 'package:yf_code/model/IMessage/TextMessageDisplay.dart';
import 'package:yf_code/model/MessageModel.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ImagePreviewPage.dart';
import 'package:yf_code/ui/MePage.dart';
import 'package:yf_code/ui/ProfilePage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';
import 'package:yf_code/utils/log.dart';
import 'package:yf_code/utils/page.dart';

bool get _isDesktopPlatform => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.device});

  final DeviceBean device;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _pickingFile = false;
  final Set<String> _fileActionBusy = {};

  late final String _conversationId;
  late final MessageModel _messageModel;
  int _lastMessageCount = 0;
  StreamSubscription<CipherSessionEvent>? _cipherSub;
  CipherSessionState _cipherState = CipherSessionState.idle;
  String? _cipherError;
  bool _encryptOn = false;

  String get _peerName {
    final name = widget.device.name;
    if (name != null && name.isNotEmpty) return name;
    return context.l10n.unknownDevice;
  }

  String get _displayName => AppSettings.instance.displayNameOf(widget.device.deviceId, _peerName);
  String get _peerIp => widget.device.ipAddress ?? '';
  String? get _peerDeviceId => widget.device.deviceId;
  bool get _online => OnlineDeviceModel.instance.deviceList.any((d) => d.deviceId == widget.device.deviceId);

  @override
  void initState() {
    super.initState();
    _conversationId = Message.buildConversationId(InitManager.deviceId, widget.device.deviceId);
    _messageModel = MessageStore.createMessageModel(_conversationId);
    _lastMessageCount = _messageModel.messages.length;
    _messageModel.addListener(_onMessagesChanged);
    AppSettings.instance.addListener(_onChromeChanged);
    OnlineDeviceModel.instance.addListener(_onChromeChanged);
    _encryptOn = AppSettings.instance.encryptOn;
    _cipherState = KeyNegotiator.stateOf(_peerIp);
    _cipherError = KeyNegotiator.errorOf(_peerIp);
    _cipherSub = KeyNegotiator.sessionEvents.listen(_onCipherSession);
    _maybeStartCipher();
  }

  void _onCipherSession(CipherSessionEvent e) {
    if (e.ip != _peerIp || !mounted) return;
    setState(() {
      _cipherState = e.state;
      _cipherError = e.errorMessage;
    });
  }

  void _maybeStartCipher() {
    if (!_encryptOn || _peerIp.isEmpty) return;
    KeyNegotiator.start(_peerIp);
  }

  void _onChromeChanged() {
    if (!mounted) return;
    final encryptOn = AppSettings.instance.encryptOn;
    if (encryptOn != _encryptOn) {
      _encryptOn = encryptOn;
      if (encryptOn) {
        _maybeStartCipher();
      } else {
        setState(() {
          _cipherState = CipherSessionState.idle;
          _cipherError = null;
        });
        return;
      }
    }
    setState(() {});
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final count = _messageModel.messages.length;
    final appended = count > _lastMessageCount;
    _lastMessageCount = count;
    setState(() {});
    if (appended) _scrollToBottom();
  }

  @override
  void dispose() {
    _cipherSub?.cancel();
    _messageModel.removeListener(_onMessagesChanged);
    AppSettings.instance.removeListener(_onChromeChanged);
    OnlineDeviceModel.instance.removeListener(_onChromeChanged);
    MessageStore.destroyMessageModel(_conversationId);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _ensurePeerReady() {
    if (_peerIp.isEmpty) {
      showAppToast(context, context.l10n.peerAddressInvalid);
      return false;
    }
    if (_peerDeviceId == null || InitManager.deviceId == null) {
      showAppToast(context, context.l10n.deviceNotReady);
      return false;
    }
    return true;
  }

  bool _ensureCipherReadyForSend() {
    if (!_encryptOn) return true;
    if (KeyNegotiator.isReady(_peerIp)) return true;
    if (_cipherState == CipherSessionState.failed) {
      showAppToast(context, localizeError(context.l10n, _cipherError));
      return false;
    }
    showAppToast(context, context.l10n.cipherEstablishingWait);
    return false;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_ensurePeerReady()) return;
    if (!_ensureCipherReadyForSend()) return;

    final msg = MessageTextBean(text: text);
    setState(() {
      _sending = true;
      _controller.clear();
    });

    await MessageManager.sendMessage(msg, widget.device);

    if (!mounted) return;
    setState(() => _sending = false);
  }

  Future<void> _pickAndSendFile() async {
    if (_pickingFile || _sending) return;
    if (!_ensurePeerReady()) return;

    setState(() => _pickingFile = true);
    try {
      final picked = await openFile();
      if (picked == null) return;
      final name = picked.name.isNotEmpty
          ? picked.name
          : (picked.path.isNotEmpty ? File(picked.path).uri.pathSegments.last : '');
      if (name.isEmpty) {
        if (!mounted) return;
        showAppToast(context, context.l10n.cannotGetFileName);
        return;
      }

      setState(() => _sending = true);
      final local = await AppFileStore.ensureAccessiblePath(
        name: name,
        sourcePath: picked.path.isEmpty ? null : picked.path,
        openContent: picked.openRead,
      );
      await MessageManager.sendFile(local, widget.device);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, context.l10n.sendFileFailed('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _pickingFile = false;
          _sending = false;
        });
      }
    }
  }

  Future<void> _acceptFile(String transferId) async {
    if (_fileActionBusy.contains(transferId)) return;
    setState(() => _fileActionBusy.add(transferId));
    try {
      await FileTransferManager.accept(transferId);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, context.l10n.receiveFailed('$e'));
    } finally {
      if (mounted) setState(() => _fileActionBusy.remove(transferId));
    }
  }

  Future<void> _rejectFile(String transferId) async {
    if (_fileActionBusy.contains(transferId)) return;
    setState(() => _fileActionBusy.add(transferId));
    try {
      await FileTransferManager.reject(transferId);
    } finally {
      if (mounted) setState(() => _fileActionBusy.remove(transferId));
    }
  }

  Future<void> _resendFile(String transferId) async {
    if (_fileActionBusy.contains(transferId)) return;
    if (!_ensurePeerReady()) return;
    if (!_ensureCipherReadyForSend()) return;
    setState(() => _fileActionBusy.add(transferId));
    try {
      await MessageManager.resendFile(transferId, widget.device);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, context.l10n.sendFileFailed('$e'));
    } finally {
      if (mounted) setState(() => _fileActionBusy.remove(transferId));
    }
  }

  Future<void> _onFileTap(FileMessageDisplay file, {required bool mine}) async {
    if (file.isImage) {
      final imagePath = file.localPath;
      if (imagePath != null && imagePath.isNotEmpty && await File(imagePath).exists()) {
        if (!mounted) return;
        await startPage(context, ImagePreviewPage(path: imagePath, name: file.name ?? context.l10n.image, mimeType: file.mimeType));
        return;
      }
    }
    if (!mounted) return;

    switch (file.fileState) {
      case FileTransferState.send:
        showAppToast(context, mine ? context.l10n.waitingPeerAcceptFile : context.l10n.pleaseAcceptFileFirst);
        return;
      case FileTransferState.transferring:
        showAppToast(context, context.l10n.fileTransferring);
        return;
      case FileTransferState.rejected:
        showAppToast(context, mine ? context.l10n.peerDeclinedFile : context.l10n.fileDeclined);
        return;
      case FileTransferState.failed:
        showAppToast(context, context.l10n.fileTransferFailed);
        return;
      case FileTransferState.success:
        break;
      case null:
        iLog("状态为空");
        break;
    }

    final path = file.localPath;
    if (path == null || path.isEmpty) {
      showAppToast(context, context.l10n.localPathUnavailable);
      return;
    }
    if (!await File(path).exists()) {
      if (!mounted) return;
      showAppToast(context, context.l10n.localFileMissing);
      return;
    }

    final result = await OpenFilex.open(path, type: file.mimeType);
    if (!mounted) return;
    if (result.type != ResultType.done) showAppToast(context, result.message);
  }

  Future<void> _onFileContext(FileMessageDisplay file, {required bool mine, Offset? position}) async {
    final path = file.localPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      if (!mounted) return;
      await _showFileActions(file, path, position: position);
      return;
    }
    if (!mounted) return;
    switch (file.fileState) {
      case FileTransferState.send:
        showAppToast(context, mine ? context.l10n.waitingPeerAcceptFile : context.l10n.pleaseAcceptFileFirst);
        return;
      case FileTransferState.transferring:
        showAppToast(context, context.l10n.fileTransferring);
        return;
      case FileTransferState.rejected:
        showAppToast(context, mine ? context.l10n.peerDeclinedFile : context.l10n.fileDeclined);
        return;
      case FileTransferState.failed:
        showAppToast(context, context.l10n.fileTransferFailed);
        return;
      case FileTransferState.success:
      case null:
        showAppToast(context, context.l10n.localFileMissing);
        return;
    }
  }

  Future<void> _showFileActions(FileMessageDisplay file, String path, {Offset? position}) async {
    if (_isDesktopPlatform && position != null) {
      await _showFileContextMenu(file, path, position);
      return;
    }
    final c = context.colors;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(999)),
                ),
                ListTile(
                  leading: Icon(Icons.ios_share_rounded, color: c.textPrimary),
                  title: Text(ctx.l10n.share, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
                  onTap: () => Navigator.pop(ctx, 'share'),
                ),
                ListTile(
                  leading: Icon(Icons.save_alt_rounded, color: c.textPrimary),
                  title: Text(ctx.l10n.saveAs, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
                  onTap: () => Navigator.pop(ctx, 'save'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    await _runFileAction(action, file, path);
  }

  Future<void> _showFileContextMenu(FileMessageDisplay file, String path, Offset globalPosition) async {
    if (!mounted) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final c = context.colors;
    final local = overlay.globalToLocal(globalPosition);
    final action = await showMenu<String>(
      context: context,
      color: c.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      position: RelativeRect.fromLTRB(local.dx, local.dy, overlay.size.width - local.dx, overlay.size.height - local.dy),
      items: [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.ios_share_rounded, size: 18, color: c.textPrimary),
              const SizedBox(width: 10),
              Text(context.l10n.share, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save_alt_rounded, size: 18, color: c.textPrimary),
              const SizedBox(width: 10),
              Text(context.l10n.saveAs, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'folder',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 18, color: c.textPrimary),
              const SizedBox(width: 10),
              Text(context.l10n.showInFolder, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    await _runFileAction(action, file, path);
  }

  Future<void> _runFileAction(String action, FileMessageDisplay file, String path) async {
    if (action == 'share') await _shareLocalFile(path, name: file.name, mimeType: file.mimeType);
    if (action == 'save') await _saveLocalFileAs(path, name: file.name);
    if (action == 'folder') await _showInFolder(path);
  }

  Future<void> _showInFolder(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) showAppToast(context, context.l10n.localFileMissing);
        return;
      }
      final folder = file.parent.absolute.path;
      if (Platform.isWindows) {
        await Process.start('explorer', [folder.replaceAll('/', r'\')]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [folder]);
      } else {
        await Process.start('xdg-open', [folder]);
      }
    } catch (_) {
      if (mounted) showAppToast(context, context.l10n.showInFolderFailed);
    }
  }

  Future<void> _shareLocalFile(String path, {String? name, String? mimeType}) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: mimeType, name: name)],
          title: name ?? context.l10n.file,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) showAppToast(context, context.l10n.shareFailed);
    }
  }

  Future<void> _saveLocalFileAs(String path, {String? name}) async {
    final suggested = (name != null && name.trim().isNotEmpty) ? name.trim() : 'file';
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final saved = await FlutterFileDialog.saveFile(params: SaveFileDialogParams(sourceFilePath: path, fileName: suggested));
        if (!mounted || saved == null) return;
        showAppToast(context, context.l10n.saved);
        return;
      }
      final location = await getSaveLocation(suggestedName: suggested);
      if (location == null) return;
      if (location.path == path) {
        if (mounted) showAppToast(context, context.l10n.saved);
        return;
      }
      await File(path).copy(location.path);
      if (mounted) showAppToast(context, context.l10n.saved);
    } catch (_) {
      if (mounted) showAppToast(context, context.l10n.saveFailed);
    }
  }

  void _openAvatarPage({required bool mine}) {
    if (mine) {
      startPage(context, const MePage(standalone: true));
      return;
    }
    startPage(context, ProfilePage(device: widget.device));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<_ChatRow> _rowsOf(List<IMessageDisplay> messages, AppLocalizations l10n) {
    final rows = <_ChatRow>[];
    String? lastDate;
    for (final msg in messages) {
      final label = _dateLabelOf(msg, l10n);
      if (label != lastDate) {
        rows.add(_ChatRow.date(label));
        lastDate = label;
      }
      rows.add(_ChatRow.message(msg));
    }
    return rows;
  }

  String _dateLabelOf(IMessageDisplay message, AppLocalizations l10n) {
    final utc = message.baseMessage?.base?.sendTimestampUtc;
    if (utc == null) return l10n.today;
    final t = DateTime.fromMillisecondsSinceEpoch(utc.toInt(), isUtc: true).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;
    if (diff < 7) return weekdayLabel(l10n, t.weekday);
    return '${t.month}/${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final messages = _messageModel.messages;
    final rows = _rowsOf(messages, l10n);
    final busy = _sending || _pickingFile;
    final meName = AppSettings.instance.nickname.isNotEmpty
        ? AppSettings.instance.nickname
        : (InitManager.deviceName ?? l10n.me);
    final meId = InitManager.deviceId ?? 'me';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              id: widget.device.deviceId ?? _peerName,
              name: _displayName,
              online: _online,
              lastSeen: lastSeenLabel(context, widget.device.updateTimestampUtc?.toInt()),
              onBack: () => gotoBack(context),
              onProfile: () => startPage(context, ProfilePage(device: widget.device)),
            ),
            if (_encryptOn)
              _CipherBanner(
                state: _cipherState,
                errorMessage: _cipherError,
                onRetry: _peerIp.isEmpty ? null : () => KeyNegotiator.start(_peerIp),
              ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyChat(peerName: _displayName)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        if (row.dateLabel != null) return _DatePill(label: row.dateLabel!);
                        final msg = row.message!;
                        return _MessageBubble(
                          message: msg,
                          myDeviceId: InitManager.deviceId,
                          meId: meId,
                          meName: meName,
                          peerId: widget.device.deviceId ?? _peerName,
                          peerName: _displayName,
                          fileActionBusy: msg is FileMessageDisplay && _fileActionBusy.contains(msg.fileMessage.transferId),
                          onAcceptFile: _acceptFile,
                          onRejectFile: _rejectFile,
                          onResendFile: _resendFile,
                          onFileTap: _onFileTap,
                          onFileContext: _onFileContext,
                          onAvatarTap: _openAvatarPage,
                        );
                      },
                    ),
            ),
            _Composer(controller: _controller, focusNode: _focusNode, busy: busy, onSend: _send, onAttach: _pickAndSendFile),
          ],
        ),
      ),
    );
  }
}

class _ChatRow {
  _ChatRow.date(this.dateLabel) : message = null;
  _ChatRow.message(this.message) : dateLabel = null;

  final String? dateLabel;
  final IMessageDisplay? message;
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.id,
    required this.name,
    required this.online,
    required this.lastSeen,
    required this.onBack,
    required this.onProfile,
  });

  final String id;
  final String name;
  final bool online;
  final String lastSeen;
  final VoidCallback onBack;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, size: 19, color: c.textPrimary),
          ),
          GestureDetector(
            onTap: onProfile,
            child: PeerAvatar(id: id, name: name, size: 34, radius: 10, online: online),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  Text(
                    online ? context.l10n.online : context.l10n.offlineLastSeen(lastSeen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: online ? FontWeight.w600 : FontWeight.w400,
                      color: online ? c.online : c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CipherBanner extends StatelessWidget {
  const _CipherBanner({required this.state, this.errorMessage, this.onRetry});

  final CipherSessionState state;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String? subtitle;
    final showRetry =
        (state == CipherSessionState.failed || state == CipherSessionState.idle) && onRetry != null;

    switch (state) {
      case CipherSessionState.ready:
        bg = c.onlineDim;
        fg = c.online;
        icon = Icons.lock_rounded;
        title = l10n.cipherReadyTitle;
        subtitle = l10n.cipherReadySubtitle;
        break;
      case CipherSessionState.establishing:
        bg = c.accentDim;
        fg = c.accent;
        icon = Icons.sync_rounded;
        title = l10n.cipherEstablishing;
        subtitle = null;
        break;
      case CipherSessionState.failed:
        bg = Color.alphaBlend(c.danger.withValues(alpha: 0.12), c.surface);
        fg = c.danger;
        icon = Icons.lock_open_rounded;
        title = l10n.cipherFailed;
        subtitle = errorMessage == null ? null : localizeError(l10n, errorMessage);
        break;
      case CipherSessionState.idle:
        bg = c.surfaceAlt;
        fg = c.textSecondary;
        icon = Icons.lock_outline_rounded;
        title = l10n.cipherWaiting;
        subtitle = null;
        break;
    }

    return Material(
      color: bg,
      child: InkWell(
        onTap: showRetry ? onRetry : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (state == CipherSessionState.establishing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                  ],
                ),
              ),
              if (showRetry)
                Text(l10n.retry, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(fontSize: 11.5, color: c.textTertiary)),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    return EmptyState(text: context.l10n.startChatWith(peerName), sub: context.l10n.startChatHint, icon: Icons.forum_outlined);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.myDeviceId,
    required this.meId,
    required this.meName,
    required this.peerId,
    required this.peerName,
    required this.fileActionBusy,
    required this.onAcceptFile,
    required this.onRejectFile,
    required this.onResendFile,
    required this.onFileTap,
    required this.onFileContext,
    required this.onAvatarTap,
  });

  final IMessageDisplay message;
  final String? myDeviceId;
  final String meId;
  final String meName;
  final String peerId;
  final String peerName;
  final bool fileActionBusy;
  final ValueChanged<String> onAcceptFile;
  final ValueChanged<String> onRejectFile;
  final ValueChanged<String> onResendFile;
  final void Function(FileMessageDisplay file, {required bool mine}) onFileTap;
  final void Function(FileMessageDisplay file, {required bool mine, Offset? position}) onFileContext;
  final void Function({required bool mine}) onAvatarTap;

  bool get _isMine => message.baseMessage?.base?.fromDeviceId == myDeviceId;

  MessageStateType get _deliveryState =>
      MessageStateType.fromCode(message.baseMessage?.base?.state ?? '') ?? MessageStateType.sending;

  String get _timeLabel {
    final utc = message.baseMessage?.base?.sendTimestampUtc;
    if (utc == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(utc.toInt(), isUtc: true).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get _text => message is TextMessageDisplay ? ((message as TextMessageDisplay).textMessage.text ?? '') : '';

  Future<void> _copyText(BuildContext context) async {
    final text = _text;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showAppToast(context, context.l10n.copied);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mine = _isMine;
    final isFile = message is FileMessageDisplay;
    final radius = mine
        ? const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(4), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14))
        : const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine)
            GestureDetector(
              onTap: () => onAvatarTap(mine: false),
              child: PeerAvatar(id: peerId, name: peerName, size: 38, radius: 11, showStatus: false),
            ),
          if (!mine) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                  decoration: BoxDecoration(
                    color: mine ? c.accent : c.raised,
                    borderRadius: radius,
                    border: mine ? null : Border.all(color: c.bubbleBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isFile
                      ? _FileBubbleBody(
                          file: message as FileMessageDisplay,
                          mine: mine,
                          busy: fileActionBusy,
                          onTap: () => onFileTap(message as FileMessageDisplay, mine: mine),
                          onLongPress: _isDesktopPlatform || (message as FileMessageDisplay).isImage
                              ? null
                              : () => onFileContext(message as FileMessageDisplay, mine: mine),
                          onSecondaryTapUp: _isDesktopPlatform
                              ? (details) => onFileContext(message as FileMessageDisplay, mine: mine, position: details.globalPosition)
                              : null,
                          onAccept: () => onAcceptFile((message as FileMessageDisplay).fileMessage.transferId!),
                          onReject: () => onRejectFile((message as FileMessageDisplay).fileMessage.transferId!),
                          onResend: () => onResendFile((message as FileMessageDisplay).fileMessage.transferId!),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: SelectableText(
                            _text,
                            onTap: () => _copyText(context),
                            cursorColor: mine ? c.onAccent : c.accent,
                            style: TextStyle(fontSize: 14, height: 1.45, color: mine ? c.onAccent : c.textPrimary),
                          ),
                        ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_timeLabel, style: TextStyle(fontSize: 10.5, color: c.textTertiary)),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      _StatusIcon(state: _deliveryState),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (mine) const SizedBox(width: 8),
          if (mine)
            GestureDetector(
              onTap: () => onAvatarTap(mine: true),
              child: PeerAvatar(id: meId, name: meName, size: 38, radius: 11, showStatus: false),
            ),
        ],
      ),
    );
  }
}

class _FileBubbleBody extends StatelessWidget {
  const _FileBubbleBody({
    required this.file,
    required this.mine,
    required this.busy,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    required this.onAccept,
    required this.onReject,
    required this.onResend,
  });

  final FileMessageDisplay file;
  final bool mine;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onResend;

  static String formatSize(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String stateLabel(FileTransferState state, AppLocalizations l10n, {required bool mine}) {
    switch (state) {
      case FileTransferState.send:
        return mine ? l10n.waitingPeerAccept : l10n.waitingYourAccept;
      case FileTransferState.transferring:
        return l10n.transferring;
      case FileTransferState.success:
        return l10n.transferDoneTapOpen;
      case FileTransferState.rejected:
        return mine ? l10n.peerDeclined : l10n.declined;
      case FileTransferState.failed:
        return l10n.transferFailed;
    }
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

  bool get _canShowImage {
    if (!file.isImage) return false;
    final path = file.localPath;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  Color _stateColor(AppColors c) {
    switch (file.fileState) {
      case FileTransferState.send:
        return mine ? c.onAccentMuted : c.accent;
      case FileTransferState.transferring:
        return mine ? c.onAccent : c.accent;
      case FileTransferState.success:
        return mine ? c.onAccent : c.online;
      case FileTransferState.rejected:
      case FileTransferState.failed:
        return c.danger;
      case null:
        return c.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_canShowImage) return _imageBody(context);
    return _fileBody(context);
  }

  Widget _imageBody(BuildContext context) {
    final overlay = file.fileState != null && file.fileState != FileTransferState.success;
    final transferring = file.fileState == FileTransferState.transferring || busy;
    final showResend = mine && file.fileState == FileTransferState.failed && !busy;
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            File(file.localPath!),
            fit: BoxFit.cover,
            width: MediaQuery.sizeOf(context).width * 0.62,
            height: 220,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => _fileBody(context),
          ),
          if (overlay)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: transferring
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white, value: file.progress),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stateLabel(file.fileState!, context.l10n, mine: mine),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            if (showResend) ...[
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: onResend,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(context.l10n.resend),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileBody(BuildContext context) {
    final c = context.colors;
    final fg = mine ? c.onAccent : c.textPrimary;
    final sub = mine ? c.onAccentMuted : c.textTertiary;
    final transferring = file.fileState == FileTransferState.transferring;
    final sizeLabel = transferring && file.total != null && file.total! > 0
        ? '${formatSize(file.current)} / ${formatSize(file.total)}'
        : formatSize(file.totalSize);
    final showActions = !mine && file.fileState == FileTransferState.send && !busy;
    final showResend = mine && file.fileState == FileTransferState.failed && !busy;
    final showProgress = file.fileState == FileTransferState.transferring || busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTapUp: onSecondaryTapUp,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: mine ? const Color(0x2915171C) : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconForMime(file.mimeType), size: 16, color: mine ? c.onAccent : c.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name ?? context.l10n.file, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
                        if (sizeLabel.isNotEmpty) Text(sizeLabel, style: TextStyle(fontSize: 11.5, color: sub)),
                        const SizedBox(height: 4),
                        Text(stateLabel(file.fileState!, context.l10n, mine: mine), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _stateColor(c))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showProgress) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: file.progress,
                    color: mine ? c.onAccent : c.accent,
                    backgroundColor: mine ? const Color(0x3315171C) : c.border,
                  ),
                ),
                if (showActions || showResend) const SizedBox(height: 10),
              ],
              if (showActions)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.danger,
                          side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(context.l10n.decline),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: c.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(context.l10n.accept),
                      ),
                    ),
                  ],
                ),
              if (showResend)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onResend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.onAccent,
                      side: BorderSide(color: c.onAccent.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(context.l10n.resend),
                  ),
                ),
              if (!mine && file.fileState == FileTransferState.success && file.localPath != null)
                Text(context.l10n.savedLocally, style: TextStyle(fontSize: 11.5, color: sub)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.state});

  final MessageStateType state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    switch (state) {
      case MessageStateType.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: c.textTertiary),
        );
      case MessageStateType.success:
        return Icon(Icons.done_rounded, size: 14, color: c.online);
      case MessageStateType.fail:
        return Icon(Icons.error_outline_rounded, size: 14, color: c.danger);
    }
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              onPressed: widget.busy ? null : widget.onAttach,
              tooltip: context.l10n.sendFile,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: c.surfaceAlt,
                foregroundColor: c.textSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.attach_file_rounded, size: 17),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              minLines: 1,
              maxLines: 5,
              enabled: !widget.busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.35),
              decoration: InputDecoration(
                hintText: context.l10n.messageHint,
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
                filled: true,
                fillColor: c.surfaceAlt,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.accent),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              onPressed: widget.busy || !hasText ? null : widget.onSend,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: hasText ? c.accent : c.surfaceAlt,
                foregroundColor: hasText ? c.onAccent : c.textTertiary,
                disabledBackgroundColor: c.surfaceAlt,
                disabledForegroundColor: c.textTertiary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: widget.busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: hasText ? c.onAccent : c.textTertiary),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
