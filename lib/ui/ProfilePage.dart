import 'package:flutter/material.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/l10n/l10n.dart';
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
    return widget.device.deviceId ?? context.l10n.unknownDevice;
  }

  String get _publicKey {
    final key = widget.device.publicKey;
    if (key == null || key.isEmpty) return '—';
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final id = widget.device.deviceId ?? '';
    final remark = AppSettings.instance.remarkOf(id);
    final displayName = remark.isNotEmpty ? remark : _peerName;

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
                  Text(l10n.profileTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ProfileHero(
                    id: id.isEmpty ? _peerName : id,
                    displayName: displayName,
                    originalName: remark.isNotEmpty ? l10n.originalName(_peerName) : null,
                    online: _online,
                    lastSeen: lastSeenLabel(context, widget.device.updateTimestampUtc?.toInt()),
                  ),
                  SettingsCard(
                    children: [
                      EditableRow(
                        label: l10n.remark,
                        value: remark,
                        inputPlaceholder: _peerName,
                        emptyLabel: l10n.tapToSetRemark,
                        onSave: (val) {
                          if (id.isEmpty) return;
                          AppSettings.instance.setRemark(id, val);
                          showAppToast(context, val.isEmpty ? l10n.remarkCleared : l10n.remarkSaved);
                        },
                      ),
                      InfoRow(label: l10n.ipAddress, value: widget.device.ipAddress ?? '—', mono: true),
                      InfoRow(label: l10n.deviceId, value: id.isEmpty ? '—' : id, mono: true, detail: true),
                      InfoRow(label: l10n.publicKey, value: _publicKey, mono: true, detail: true, showDivider: false),
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
                  label: Text(l10n.sendMessage, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
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
