import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/AppFileStore.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/manager/MessageStore.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/model/IMessage/FileMessageDisplay.dart';
import 'package:yf_code/model/IMessage/IMessageDisplay.dart';
import 'package:yf_code/model/IMessage/TextMessageDisplay.dart';
import 'package:yf_code/model/MessageModel.dart';
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

  String get _peerName =>
      widget.device.name?.isNotEmpty == true ? widget.device.name! : '未知设备';

  String get _peerIp => widget.device.ipAddress ?? '';
  String? get _peerDeviceId => widget.device.deviceId;

  @override
  void initState() {
    super.initState();
    _conversationId = _buildConversationId(
      InitManager.deviceId,
      widget.device.deviceId,
    );
    _messageModel = MessageStore.createMessageModel(_conversationId);
    _lastMessageCount = _messageModel.messages.length;
    _messageModel.addListener(_onMessagesChanged);
  }

  static String _buildConversationId(String? myDeviceId, String? peerDeviceId) {
    final myId = myDeviceId ?? '';
    final peerId = peerDeviceId ?? '';
    return myId.compareTo(peerId) <= 0 ? '$myId:$peerId' : '$peerId:$myId';
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
    MessageStore.destroyMessageModel(_conversationId);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _ensurePeerReady() {
    if (_peerIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对方地址无效，无法发送')),
      );
      return false;
    }
    if (_peerDeviceId == null || InitManager.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备信息未就绪，无法发送')),
      );
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

    await SendMessageManager.sendMessage(msg, _peerIp, _peerDeviceId);

    if (!mounted) return;
    setState(() {
      _sending = false;
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件名')),
        );
        return;
      }

      setState(() => _sending = true);
      final local = await AppFileStore.ensureAccessiblePath(
        name: name,
        sourcePath: picked.path.isEmpty ? null : picked.path,
        openContent: picked.openRead,
      );
      await SendMessageManager.sendFile(local, _peerIp, _peerDeviceId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送文件失败：$e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('接收失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _fileActionBusy.remove(transferId));
      }
    }
  }

  Future<void> _rejectFile(String transferId) async {
    if (_fileActionBusy.contains(transferId)) return;
    setState(() => _fileActionBusy.add(transferId));
    try {
      await FileTransferManager.reject(transferId);
    } finally {
      if (mounted) {
        setState(() => _fileActionBusy.remove(transferId));
      }
    }
  }

  Future<void> _onFileTap(FileMessageDisplay file, {required bool mine}) async {
    switch (file.fileState) {
      case FileTransferState.send:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mine ? '等待对方接收文件' : '请先接收文件'),
          ),
        );
        return;
      case FileTransferState.transferring:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件正在传输中')),
        );
        return;
      case FileTransferState.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mine ? '对方已拒绝该文件' : '已拒绝该文件')),
        );
        return;
      case FileTransferState.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件传输失败')),
        );
        return;
      case FileTransferState.success:
        break;
      case null:
        iLog("状态为空");
        break;
    }

    final path = file.localPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地文件路径不可用')),
      );
      return;
    }
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地文件不存在或已被移动')),
      );
      return;
    }

    final result = await OpenFilex.open(path, type: file.mimeType);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final messages = _messageModel.messages;
    final busy = _sending || _pickingFile;
    return Scaffold(
      body: Stack(
        children: [
          const _AtmosphereBackground(),
          SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  name: _peerName,
                  ip: _peerIp,
                  onBack: () => gotoBack(context),
                ),
                Expanded(
                  child: messages.isEmpty
                      ? _EmptyChat(peerName: _peerName)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return _MessageBubble(
                              message: msg,
                              myDeviceId: InitManager.deviceId,
                              fileActionBusy: msg is FileMessageDisplay &&
                                  _fileActionBusy.contains(msg.fileMessage.transferId),
                              onAcceptFile: _acceptFile,
                              onRejectFile: _rejectFile,
                              onFileTap: _onFileTap,
                            );
                          },
                        ),
                ),
                _Composer(
                  controller: _controller,
                  focusNode: _focusNode,
                  busy: busy,
                  onSend: _send,
                  onAttach: _pickAndSendFile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE4F0ED),
            Color(0xFFEEF2EF),
            Color(0xFFF4F1EB),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.ip,
    required this.onBack,
  });

  final String name;
  final String ip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF152422),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A9B90), Color(0xFF0E6E68)],
              ),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF152422),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ip.isEmpty ? '地址未知' : ip,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6A7C79),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF0E6E68).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 30,
                color: Color(0xFF0E6E68),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '与 $peerName 开始对话',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF152422),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '可发送文字或文件，经局域网直连送达',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF6A7C79),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.myDeviceId,
    required this.fileActionBusy,
    required this.onAcceptFile,
    required this.onRejectFile,
    required this.onFileTap,
  });

  final IMessageDisplay message;
  final String? myDeviceId;
  final bool fileActionBusy;
  final ValueChanged<String> onAcceptFile;
  final ValueChanged<String> onRejectFile;
  final void Function(FileMessageDisplay file, {required bool mine}) onFileTap;

  bool get _isMine => message.baseMessage?.base?.fromDeviceId == myDeviceId;

  MessageStateType get _deliveryState =>
      MessageStateType.fromCode(message.baseMessage?.base?.state ?? '') ??
      MessageStateType.sending;

  DateTime get _timestamp {
    final utc = message.baseMessage?.base?.sendTimestampUtc;
    if (utc == null) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(utc.toInt(), isUtc: true)
        .toLocal();
  }

  String get _timeLabel {
    final t = _timestamp;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final mine = _isMine;
    final isFile = message is FileMessageDisplay;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? const Color(0xFF0E6E68)
                        : const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                    border: mine
                        ? null
                        : Border.all(color: const Color(0x1A0E6E68)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isFile
                      ? _FileBubbleBody(
                          file: message as FileMessageDisplay,
                          mine: mine,
                          busy: fileActionBusy,
                          onTap: () => onFileTap(
                            message as FileMessageDisplay,
                            mine: mine,
                          ),
                          onAccept: () => onAcceptFile(
                              (message as FileMessageDisplay).fileMessage.transferId!),
                          onReject: () => onRejectFile(
                              (message as FileMessageDisplay).fileMessage.transferId!),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: SelectableText(
                            message is TextMessageDisplay
                                ? ((message as TextMessageDisplay).textMessage.text ?? '')
                                : '',
                            cursorColor: mine
                                ? Colors.white
                                : const Color(0xFF0E6E68),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: mine
                                  ? Colors.white
                                  : const Color(0xFF152422),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6A7C79),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      _StatusIcon(state: _deliveryState),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (mine) const SizedBox(width: 4),
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
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
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
    if (m.contains('zip') || m.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _stateColor({required bool mine}) {
    switch (file.fileState) {
      case FileTransferState.send:
        return mine ? const Color(0xFFFFE08A) : const Color(0xFF0E6E68);
      case FileTransferState.transferring:
        return mine ? const Color(0xFFB8E0FF) : const Color(0xFF2A7CB8);
      case FileTransferState.success:
        return mine ? const Color(0xFFB6F0C8) : const Color(0xFF2A9B6A);
      case FileTransferState.rejected:
        return mine ? const Color(0xFFFFC4B8) : const Color(0xFFC45C4A);
      case FileTransferState.failed:
        return mine ? const Color(0xFFFFC4B8) : const Color(0xFFC45C4A);
      case null:
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : const Color(0xFF152422);
    final sub = mine
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF6A7C79);
    final transferring = file.fileState == FileTransferState.transferring;
    final sizeLabel = transferring && file.total != null && file.total! > 0
        ? '${formatSize(file.current)} / ${formatSize(file.total)}'
        : formatSize(file.totalSize);
    final showActions =
        !mine && file.fileState == FileTransferState.send && !busy;
    final showProgress =
        file.fileState == FileTransferState.transferring || busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.14)
                          : const Color(0xFF0E6E68).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconForMime(file.mimeType),
                      size: 22,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name ?? '文件',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: fg,
                          ),
                        ),
                        if (sizeLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            sizeLabel,
                            style: TextStyle(fontSize: 12.5, color: sub),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? Colors.white.withValues(alpha: 0.16)
                                : _stateColor(mine: false)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            stateLabel(file.fileState!, mine: mine),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: mine
                                  ? _stateColor(mine: true)
                                  : _stateColor(mine: false),
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
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            showProgress || showActions || (!mine &&
                    file.fileState == FileTransferState.success &&
                    file.localPath != null)
                ? 10
                : 12,
            12,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showProgress) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: file.progress,
                    color: mine ? Colors.white : const Color(0xFF0E6E68),
                    backgroundColor: mine
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0x1A0E6E68),
                  ),
                ),
                if (showActions ||
                    (!mine &&
                        file.fileState == FileTransferState.success &&
                        file.localPath != null))
                  const SizedBox(height: 12),
              ],
              if (showActions)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC45C4A),
                          side: const BorderSide(color: Color(0x66C45C4A)),
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
                          backgroundColor: const Color(0xFF0E6E68),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('接收'),
                      ),
                    ),
                  ],
                ),
              if (!mine &&
                  file.fileState == FileTransferState.success &&
                  file.localPath != null)
                Text(
                  '已保存至本地',
                  style: TextStyle(fontSize: 11.5, color: sub),
                ),
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
    switch (state) {
      case MessageStateType.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Color(0xFF6A7C79),
          ),
        );
      case MessageStateType.success:
        return const Icon(
          Icons.done_rounded,
          size: 14,
          color: Color(0xFF2A9B6A),
        );
      case MessageStateType.fail:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Color(0xFFC45C4A),
        );
    }
  }
}

class _Composer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1A0E6E68)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: busy ? null : onAttach,
              tooltip: '发送文件',
              icon: Icon(
                Icons.attach_file_rounded,
                color: Color(0xFF0E6E68).withValues(alpha: busy ? 0.35 : 1),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                enabled: !busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(2000),
                ],
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF152422),
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  hintStyle: TextStyle(
                    color: Color(0xFF6A7C79),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: const Color(0xFF0E6E68),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: busy ? null : onSend,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
