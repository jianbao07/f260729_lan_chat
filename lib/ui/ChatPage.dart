import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/AppFileStore.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/IMessage/FileMessageDisplay.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';
import 'package:yf_code/model/IMessage/TextMessageDisplay.dart';
import 'package:yf_code/model/MessageModel.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ProfilePage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';
import 'package:yf_code/utils/log.dart';
import 'package:yf_code/utils/page.dart';

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

  String get _peerName {
    final name = widget.device.name;
    if (name != null && name.isNotEmpty) return name;
    return '未知设备';
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
  }

  void _onChromeChanged() {
    if (mounted) setState(() {});
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
      showAppToast(context, '对方地址无效，无法发送');
      return false;
    }
    if (_peerDeviceId == null || InitManager.deviceId == null) {
      showAppToast(context, '设备信息未就绪，无法发送');
      return false;
    }
    return true;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_ensurePeerReady()) return;

    final msg = TextMessageBean(text: text);
    setState(() {
      _sending = true;
      _controller.clear();
    });

    await MessageManager.sendMessage(msg, _peerIp, _peerDeviceId);

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
        showAppToast(context, '无法获取文件名');
        return;
      }

      setState(() => _sending = true);
      final local = await AppFileStore.ensureAccessiblePath(
        name: name,
        sourcePath: picked.path.isEmpty ? null : picked.path,
        openContent: picked.openRead,
      );
      await MessageManager.sendFile(local, _peerIp, _peerDeviceId);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '发送文件失败：$e');
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
      showAppToast(context, '接收失败：$e');
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

  Future<void> _onFileTap(FileMessageDisplay file, {required bool mine}) async {
    switch (file.fileState) {
      case FileTransferState.send:
        showAppToast(context, mine ? '等待对方接收文件' : '请先接收文件');
        return;
      case FileTransferState.transferring:
        showAppToast(context, '文件正在传输中');
        return;
      case FileTransferState.rejected:
        showAppToast(context, mine ? '对方已拒绝该文件' : '已拒绝该文件');
        return;
      case FileTransferState.failed:
        showAppToast(context, '文件传输失败');
        return;
      case FileTransferState.success:
        break;
      case null:
        iLog("状态为空");
        break;
    }

    final path = file.localPath;
    if (path == null || path.isEmpty) {
      showAppToast(context, '本地文件路径不可用');
      return;
    }
    if (!await File(path).exists()) {
      if (!mounted) return;
      showAppToast(context, '本地文件不存在或已被移动');
      return;
    }

    final result = await OpenFilex.open(path, type: file.mimeType);
    if (!mounted) return;
    if (result.type != ResultType.done) showAppToast(context, result.message);
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

  List<_ChatRow> _rowsOf(List<IMessageDisplay> messages) {
    final rows = <_ChatRow>[];
    String? lastDate;
    for (final msg in messages) {
      final label = _dateLabelOf(msg);
      if (label != lastDate) {
        rows.add(_ChatRow.date(label));
        lastDate = label;
      }
      rows.add(_ChatRow.message(msg));
    }
    return rows;
  }

  String _dateLabelOf(IMessageDisplay message) {
    final utc = message.baseMessage?.base?.sendTimestampUtc;
    if (utc == null) return '今天';
    final t = DateTime.fromMillisecondsSinceEpoch(utc.toInt(), isUtc: true).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[t.weekday - 1];
    }
    return '${t.month}/${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final messages = _messageModel.messages;
    final rows = _rowsOf(messages);
    final busy = _sending || _pickingFile;
    final meName = AppSettings.instance.nickname.isNotEmpty
        ? AppSettings.instance.nickname
        : (InitManager.deviceName ?? '我');
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
              lastSeen: lastSeenLabel(widget.device.updateTimestampUtc?.toInt()),
              onBack: () => gotoBack(context),
              onProfile: () => startPage(context, ProfilePage(device: widget.device)),
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
                          onFileTap: _onFileTap,
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
                    online ? '在线' : '离线 · 最后在线 $lastSeen',
                    style: TextStyle(fontSize: 11.5, color: c.textSecondary),
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
    return EmptyState(text: '与 $peerName 开始对话', sub: '可发送文字或文件，经局域网直连送达', icon: Icons.forum_outlined);
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
    required this.onFileTap,
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
  final void Function(FileMessageDisplay file, {required bool mine}) onFileTap;

  bool get _isMine => message.baseMessage?.base?.fromDeviceId == myDeviceId;

  MessageStateType get _deliveryState =>
      MessageStateType.fromCode(message.baseMessage?.base?.state ?? '') ?? MessageStateType.sending;

  String get _timeLabel {
    final utc = message.baseMessage?.base?.sendTimestampUtc;
    if (utc == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(utc.toInt(), isUtc: true).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
          if (!mine) PeerAvatar(id: peerId, name: peerName, size: 38, radius: 11, showStatus: false),
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
                          onAccept: () => onAcceptFile((message as FileMessageDisplay).fileMessage.transferId!),
                          onReject: () => onRejectFile((message as FileMessageDisplay).fileMessage.transferId!),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: SelectableText(
                            message is TextMessageDisplay ? ((message as TextMessageDisplay).textMessage.text ?? '') : '',
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
          if (mine) PeerAvatar(id: meId, name: meName, size: 38, radius: 11, showStatus: false),
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
    required this.onAccept,
    required this.onReject,
  });

  final FileMessageDisplay file;
  final bool mine;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  static String formatSize(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String stateLabel(FileTransferState state, {required bool mine}) {
    switch (state) {
      case FileTransferState.send:
        return mine ? '等待对方接收' : '待你确认接收';
      case FileTransferState.transferring:
        return '正在传输…';
      case FileTransferState.success:
        return '传输完成 · 点击打开';
      case FileTransferState.rejected:
        return mine ? '对方已拒绝' : '已拒绝';
      case FileTransferState.failed:
        return '传输失败';
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
    final c = context.colors;
    final fg = mine ? c.onAccent : c.textPrimary;
    final sub = mine ? c.onAccentMuted : c.textTertiary;
    final transferring = file.fileState == FileTransferState.transferring;
    final sizeLabel = transferring && file.total != null && file.total! > 0
        ? '${formatSize(file.current)} / ${formatSize(file.total)}'
        : formatSize(file.totalSize);
    final showActions = !mine && file.fileState == FileTransferState.send && !busy;
    final showProgress = file.fileState == FileTransferState.transferring || busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                        Text(file.name ?? '文件', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
                        if (sizeLabel.isNotEmpty) Text(sizeLabel, style: TextStyle(fontSize: 11.5, color: sub)),
                        const SizedBox(height: 4),
                        Text(stateLabel(file.fileState!, mine: mine), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _stateColor(c))),
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
                if (showActions) const SizedBox(height: 10),
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
                        child: const Text('拒绝'),
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
                        child: const Text('接收'),
                      ),
                    ),
                  ],
                ),
              if (!mine && file.fileState == FileTransferState.success && file.localPath != null)
                Text('已保存至本地', style: TextStyle(fontSize: 11.5, color: sub)),
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
              tooltip: '发送文件',
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
                hintText: '发送消息...',
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
