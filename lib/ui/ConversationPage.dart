import 'package:flutter/material.dart';
import 'package:yf_code/bean/ConversationBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/model/ConversationModel.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/utils/page.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final Map<String, DeviceBean> _deviceCache = {};
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    ConversationModel.instance.addListener(_onChanged);
    OnlineDeviceModel.instance.addListener(_onChanged);
    _hydrateDevices();
  }

  @override
  void dispose() {
    ConversationModel.instance.removeListener(_onChanged);
    OnlineDeviceModel.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _hydrateDevices();
  }

  Future<void> _hydrateDevices() async {
    var changed = false;
    for (final c in ConversationModel.instance.deviceList) {
      final id = c.conversationDeviceId;
      if (id == null || id.isEmpty) continue;
      if (_deviceCache.containsKey(id) || _loadingIds.contains(id)) continue;
      _loadingIds.add(id);
      final device = await OnlineDeviceManager.getDeviceInfo(id);
      if (!mounted) return;
      if (device != null) {
        _deviceCache[id] = device;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  DeviceBean? _deviceOf(ConversationBean conversation) {
    final id = conversation.conversationDeviceId;
    if (id == null || id.isEmpty) return null;
    for (final d in OnlineDeviceModel.instance.deviceList) {
      if (d.deviceId == id) return d;
    }
    return _deviceCache[id];
  }

  String _peerName(ConversationBean conversation) {
    final device = _deviceOf(conversation);
    final name = device?.name;
    if (name != null && name.isNotEmpty) return name;
    final id = conversation.conversationDeviceId;
    if (id != null && id.isNotEmpty) return id;
    return '未知设备';
  }

  Future<void> _openConversation(ConversationBean conversation) async {
    final id = conversation.conversationDeviceId;
    if (id == null || id.isEmpty) return;
    var device = _deviceOf(conversation);
    device ??= await OnlineDeviceManager.getDeviceInfo(id);
    if (!mounted) return;
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到该设备信息')),
      );
      return;
    }
    startPage(context, ChatPage(device: device));
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ConversationModel.instance.deviceList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(count: conversations.length),
        Expanded(
          child: conversations.isEmpty
              ? const _EmptyConversations()
              : _ConversationList(
                  conversations: conversations,
                  peerNameOf: _peerName,
                  onTap: _openConversation,
                ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          const Text(
            '会话',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFF3D4F4C),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0E6E68).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E6E68),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            '按最近消息排序',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6A7C79),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: Color(0xFF0E6E68),
            ),
            SizedBox(height: 28),
            Text(
              '还没有会话',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF152422),
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '在「在线」页选择设备开始聊天，会话会出现在这里',
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

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.peerNameOf,
    required this.onTap,
  });

  final List<ConversationBean> conversations;
  final String Function(ConversationBean) peerNameOf;
  final ValueChanged<ConversationBean> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + index * 60),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _ConversationTile(
            conversation: conversation,
            peerName: peerNameOf(conversation),
            onTap: () => onTap(conversation),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.peerName, required this.onTap});

  final ConversationBean conversation;
  final String peerName;
  final VoidCallback onTap;

  String get _timeLabel {
    final ts = conversation.lastMessagesTimestampUtc;
    if (ts == null) return '';
    final last = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    final diff = DateTime.now().toUtc().difference(last);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    final local = last.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = conversation.lastMessagesPreview;
    final subtitle = (preview != null && preview.isNotEmpty) ? preview : '暂无消息';
    final online = conversation.isOnline();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1A0E6E68)),
          ),
          child: Row(
            children: [
              _Avatar(label: peerName, dimmed: !online),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: online
                            ? const Color(0xFF152422)
                            : const Color(0xFF3D4F4C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6A7C79),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6A7C79),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? const Color(0xFF2A9B6A)
                          : const Color(0xFFB8860B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.dimmed = false});

  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final letter = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';
    final bg = Color.lerp(
      const Color(0xFF1A9B90),
      const Color(0xFF3D4F4C),
      dimmed ? 0.45 : 0.15,
    )!;

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bg,
            Color.lerp(bg, Colors.black, 0.18)!,
          ],
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: dimmed ? 0.75 : 1),
        ),
      ),
    );
  }
}
