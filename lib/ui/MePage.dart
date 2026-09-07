import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  String? _ip;

  String get _deviceId => InitManager.deviceId ?? '—';
  String get _deviceName => InitManager.rawDeviceName ?? InitManager.deviceName ?? '本机';

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onChanged);
    _loadIp();
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadIp() async {
    final ip = await NetworkUtils.getWifiIP();
    if (mounted) setState(() => _ip = ip);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final nickname = settings.nickname;
    final displayName = nickname.isNotEmpty ? nickname : _deviceName;
    final c = context.colors;

    return ListView(
      children: [
        ProfileHero(
          id: _deviceId,
          displayName: displayName,
          originalName: nickname.isNotEmpty ? '设备名 $_deviceName' : null,
          showStatus: false,
        ),
        const SectionLabel(text: '本机信息'),
        SettingsCard(
          children: [
            EditableRow(
              label: '昵称',
              value: nickname,
              inputPlaceholder: _deviceName,
              emptyLabel: '点击设置昵称',
              onSave: (val) {
                settings.setNickname(val);
                InitManager.deviceName = val.isEmpty ? InitManager.rawDeviceName : val;
                showAppToast(context, val.isEmpty ? '已清除昵称' : '昵称已保存');
              },
            ),
            InfoRow(label: 'IP 地址', value: _ip ?? '—', mono: true),
            InfoRow(label: '设备 ID', value: _deviceId, mono: true, showDivider: false),
          ],
        ),
        const SectionLabel(text: '通用设置'),
        SettingsCard(
          children: [
            InfoRow(
              label: '主题',
              child: _ThemePicker(value: settings.theme, onChanged: settings.setTheme),
            ),
            InfoRow(
              label: '消息通知',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 14, color: c.textTertiary),
                  const SizedBox(width: 8),
                  AppToggle(on: settings.notifOn, onChanged: settings.setNotifOn),
                ],
              ),
            ),
            InfoRow(
              label: '允许被局域网发现',
              showDivider: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: c.textTertiary),
                  const SizedBox(width: 8),
                  AppToggle(
                    on: settings.discoverable,
                    onChanged: (on) {
                      settings.setDiscoverable(on);
                      if (on) {
                        OnlineDeviceManager.startBeat();
                      } else {
                        OnlineDeviceManager.stopBeat();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SectionLabel(text: '关于'),
        SettingsCard(
          children: [
            InfoRow(label: '版本号', value: InitManager.version, mono: true),
            _ActionRow(label: '隐私政策', onTap: () => gotoProtocolText(ProtocolEnum.pp, context)),
            _ActionRow(label: '用户协议', onTap: () => gotoProtocolText(ProtocolEnum.ua, context)),
            _ActionRow(label: '帮助与反馈', onTap: () => showAppToast(context, '帮助与反馈'), showDivider: false),
          ],
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(context, 'system', '系统'),
        const SizedBox(width: 6),
        _chip(context, 'dark', '深色'),
        const SizedBox(width: 6),
        _chip(context, 'light', '浅色'),
      ],
    );
  }

  Widget _chip(BuildContext context, String id, String label) {
    final c = context.colors;
    final active = value == id;
    return GestureDetector(
      onTap: () => onChanged(id),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent : c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? c.onAccent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, this.onTap, this.showDivider = true});

  final String label;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: c.hairline)) : null,
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
            const Spacer(),
            Text('›', style: TextStyle(fontSize: 13.5, color: c.textTertiary)),
          ],
        ),
      ),
    );
  }
}
