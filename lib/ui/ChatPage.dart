import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/bean/message/BaseMessageBean.dart';
import 'package:yf_code/bean/message/TextMessageBean.dart';
import 'package:yf_code/enum/MessageStateType.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/SendTextManager.dart';
import 'package:yf_code/model/MessageModel.dart';
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

  late final String _sessionId;
  late final MessageModel _messageModel;

  String get _peerName =>
      widget.device.name?.isNotEmpty == true ? widget.device.name! : '未知设备';

  String get _peerIp => widget.device.ipAddress ?? '';
  String? get _peerDeviceId => widget.device.deviceId;

  @override
  void initState() {
    super.initState();
    _sessionId = _buildSessionId(
      InitManager.deviceId,
      widget.device.deviceId,
    );
    _messageModel = MessageManager.createMessageModel(_sessionId);
    _messageModel.addListener(_onMessagesChanged);
  }

  static String _buildSessionId(String? myDeviceId, String? peerDeviceId) {
    final myId = myDeviceId ?? '';
    final peerId = peerDeviceId ?? '';
    return myId.compareTo(peerId) <= 0 ? '$myId:$peerId' : '$peerId:$myId';
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageModel.removeListener(_onMessagesChanged);
    MessageManager.destroyMessageModel(_sessionId);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (_peerIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对方地址无效，无法发送')),
      );
      return;
    }
    if (_peerDeviceId == null || InitManager.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备信息未就绪，无法发送')),
      );
      return;
    }

    final msg = TextMessageBean(text: text);
    setState(() {
      _sending = true;
      _controller.clear();
    });

    await SendTextManager.sendMessage(msg, _peerIp, _peerDeviceId);

    if (!mounted) return;
    setState(() {
      _sending = false;
    });
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
                            return _MessageBubble(
                              message: messages[index],
                              myDeviceId: InitManager.deviceId,
                            );
                          },
                        ),
                ),
                _Composer(
                  controller: _controller,
                  focusNode: _focusNode,
                  sending: _sending,
                  onSend: _send,
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
              '消息经局域网直连送达，无需外网',
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
  });

  final Message message;
  final String? myDeviceId;

  bool get _isMine => message.base?.fromDeviceId == myDeviceId;

  String get _text {
    if (message is TextMessageBean) {
      return (message as TextMessageBean).text ?? '';
    }
    return '';
  }

  MessageStateType get _state =>
      MessageStateType.fromCode(message.base?.state ?? '') ??
      MessageStateType.sending;

  DateTime get _timestamp {
    final utc = message.base?.sendTimestampUtc;
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
                    maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  child: Text(
                    _text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: mine
                          ? Colors.white
                          : const Color(0xFF152422),
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
                      _StatusIcon(state: _state),
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
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1A0E6E68)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
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
            const SizedBox(width: 6),
            Material(
              color: const Color(0xFF0E6E68),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: sending ? 0.5 : 1),
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
