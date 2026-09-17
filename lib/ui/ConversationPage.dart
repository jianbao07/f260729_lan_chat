import 'package:flutter/material.dart';
import 'package:yf_code/bean/ConversationBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/ConversationModel.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/ui/ProfilePage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';
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
    AppSettings.instance.addListener(_onChanged);
    _hydrateDevices();
  }

  @override
  void dispose() {
    ConversationModel.instance.removeListener(_onChanged);
    OnlineDeviceModel.instance.removeListener(_onChanged);
    AppSettings.instance.removeListener(_onChanged);
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

  Future<DeviceBean?> _resolveDevice(ConversationBean conversation) async {
    final id = conversation.conversationDeviceId;
    if (id == null || id.isEmpty) return null;
    var device = _deviceOf(conversation);
    device ??= await OnlineDeviceManager.getDeviceInfo(id);
    return device;
  }

  Future<void> _openChat(ConversationBean conversation) async {
    final device = await _resolveDevice(conversation);
    if (!mounted) return;
    if (device == null) {
      showAppToast(context, '找不到该设备信息');
      return;
    }
    startPage(context, ChatPage(device: device));
  }

  Future<void> _openProfile(ConversationBean conversation) async {
    final device = await _resolveDevice(conversation);
    if (!mounted) return;
    if (device == null) {
      showAppToast(context, '找不到该设备信息');
      return;
    }
    startPage(context, ProfilePage(device: device));
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ConversationModel.instance.deviceList;
    if (conversations.isEmpty) {
      return const EmptyState(text: '暂时没有会话', sub: '发现在线设备后，向他打个招呼吧');
    }
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final rawName = _peerName(conversation);
        final displayName = AppSettings.instance.displayNameOf(conversation.conversationDeviceId, rawName);
        return _ConversationTile(
          conversation: conversation,
          displayName: displayName,
          onAvatarTap: () => _openProfile(conversation),
          onRowTap: () => _openChat(conversation),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.displayName,
    required this.onAvatarTap,
    required this.onRowTap,
  });

  final ConversationBean conversation;
  final String displayName;
  final VoidCallback onAvatarTap;
  final VoidCallback onRowTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = conversation.lastMessagesPreview;
    final subtitle = (preview != null && preview.isNotEmpty) ? preview : '暂无消息';
    final online = conversation.isOnline();
    final id = conversation.conversationDeviceId ?? displayName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRowTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
          child: Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: PeerAvatar(id: id, name: displayName, size: 46, online: online),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              PresenceChip(online: online),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTimeLabel(conversation.lastMessagesTimestampUtc),
                          style: TextStyle(fontSize: 12, color: c.textTertiary, fontFamily: kMonoFont),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
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
