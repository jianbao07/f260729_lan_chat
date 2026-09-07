import 'package:flutter/material.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/utils/page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.device});

  final DeviceBean device;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onChanged);
    OnlineDeviceModel.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onChanged);
    OnlineDeviceModel.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _online {
    final id = widget.device.deviceId;
    return OnlineDeviceModel.instance.deviceList.any((d) => d.deviceId == id);
  }

  String get _peerName {
    final name = widget.device.name;
    if (name != null && name.isNotEmpty) return name;
    return widget.device.deviceId ?? '未知设备';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final id = widget.device.deviceId ?? '';
    final remark = AppSettings.instance.remarkOf(id);
    final displayName = remark.isNotEmpty ? remark : _peerName;
    final type = inferDeviceType(_peerName);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => gotoBack(context),
                    icon: Icon(Icons.arrow_back, size: 19, color: c.textPrimary),
                  ),
                  Text('详细资料', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ProfileHero(
                    id: id.isEmpty ? _peerName : id,
                    displayName: displayName,
                    originalName: remark.isNotEmpty ? '原名 $_peerName' : null,
                    online: _online,
                    lastSeen: lastSeenLabel(widget.device.updateTimestampUtc?.toInt()),
                  ),
                  SettingsCard(
                    children: [
                      EditableRow(
                        label: '备注',
                        value: remark,
                        inputPlaceholder: _peerName,
                        emptyLabel: '点击设置备注',
                        onSave: (val) {
                          if (id.isEmpty) return;
                          AppSettings.instance.setRemark(id, val);
                          showAppToast(context, val.isEmpty ? '已清除备注' : '备注已保存');
                        },
                      ),
                      InfoRow(label: 'IP 地址', value: widget.device.ipAddress ?? '—', mono: true),
                      InfoRow(label: '设备 ID', value: id.isEmpty ? '—' : id, mono: true),
                      InfoRow(
                        label: '设备类型',
                        showDivider: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 14, color: c.textSecondary),
                            const SizedBox(width: 6),
                            Text(type.label, style: TextStyle(fontSize: 13.5, color: c.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => startPageReplace(context, ChatPage(device: widget.device)),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('发送消息', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class DeviceTypeInfo {
  const DeviceTypeInfo(this.label, this.icon);
  final String label;
  final IconData icon;
}

DeviceTypeInfo inferDeviceType(String name) {
  final n = name.toLowerCase();
  if (n.contains('打印') || n.contains('printer')) return const DeviceTypeInfo('打印机', Icons.print_outlined);
  if (n.contains('服务器') || n.contains('server')) return const DeviceTypeInfo('服务器', Icons.dns_outlined);
  if (n.contains('phone') || n.contains('iphone') || n.contains('android') || n.contains('手机')) {
    return const DeviceTypeInfo('手机', Icons.smartphone_outlined);
  }
  if (n.contains('tv') || n.contains('monitor') || n.contains('大屏') || n.contains('显示')) {
    return const DeviceTypeInfo('显示屏', Icons.tv_outlined);
  }
  if (n.contains('desktop') || n.contains('台式')) return const DeviceTypeInfo('台式电脑', Icons.desktop_windows_outlined);
  return const DeviceTypeInfo('笔记本电脑', Icons.laptop_outlined);
}
