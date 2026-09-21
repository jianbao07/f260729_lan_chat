import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/cipher/Ed25519Key.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  String? _ip;
  String? _publicKey;

  String get _deviceId => InitManager.deviceId ?? '—';
  String get _deviceName => InitManager.rawDeviceName ?? InitManager.deviceName ?? context.l10n.thisDevice;

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onChanged);
    _loadIp();
    _loadPublicKey();
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

  Future<void> _loadPublicKey() async {
    final publicKey = (await Ed25519Key.getLongTermKey()).publicKeyHex;
    if (mounted) setState(() => _publicKey = publicKey);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final nickname = settings.nickname;
    final displayName = nickname.isNotEmpty ? nickname : _deviceName;
    final c = context.colors;
    final l10n = context.l10n;

    final content = ListView(
      children: [
        ProfileHero(
          id: _deviceId,
          displayName: displayName,
          originalName: nickname.isNotEmpty ? l10n.deviceNameLabel(_deviceName) : null,
          showStatus: false,
        ),
        SectionLabel(text: l10n.sectionDeviceInfo),
        SettingsCard(
          children: [
            EditableRow(
              label: l10n.nickname,
              value: nickname,
              inputPlaceholder: _deviceName,
              emptyLabel: l10n.tapToSetNickname,
              onSave: (val) {
                settings.setNickname(val);
                InitManager.deviceName = val.isEmpty ? InitManager.rawDeviceName : val;
                showAppToast(context, val.isEmpty ? l10n.nicknameCleared : l10n.nicknameSaved);
              },
            ),
            InfoRow(label: l10n.ipAddress, value: _ip ?? '—', mono: true),
            InfoRow(label: l10n.deviceId, value: _deviceId, mono: true, detail: true),
            InfoRow(label: l10n.publicKey, value: _publicKey ?? '—', mono: true, detail: true, showDivider: false),
          ],
        ),
        SectionLabel(text: l10n.sectionGeneral),
        SettingsCard(
          children: [
            InfoRow(
              label: l10n.theme,
              child: _ThemePicker(value: settings.theme, onChanged: settings.setTheme),
            ),
            InfoRow(
              label: l10n.language,
              child: _LocalePicker(value: settings.localeMode, onChanged: settings.setLocaleMode),
            ),
            InfoRow(
              label: l10n.notifications,
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
              label: l10n.discoverable,
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
            InfoRow(
              label: l10n.encryptTransfer,
              showDivider: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: c.textTertiary),
                  const SizedBox(width: 8),
                  AppToggle(on: settings.encryptOn, onChanged: settings.setEncryptOn),
                ],
              ),
            ),
          ],
        ),
        SectionLabel(text: l10n.sectionAbout),
        SettingsCard(
          children: [
            InfoRow(label: l10n.version, value: InitManager.version, mono: true),
            _ActionRow(label: l10n.privacyPolicy, onTap: () => gotoProtocolText(ProtocolEnum.pp, context)),
            _ActionRow(label: l10n.userAgreement, onTap: () => gotoProtocolText(ProtocolEnum.ua, context)),
            _ActionRow(
              label: l10n.helpFeedback,
              onTap: () => gotoH5(
                'https://docs.google.com/forms/d/e/1FAIpQLScAC2DcIqJI_Fg1WDSeg_XsjvFwPquD6vJK-bqIhZBfvfzXEw/viewform?usp=publish-editor',
                context: context,
              ),
              showDivider: false,
            ),
          ],
        ),
      ],
    );

    if (!widget.standalone) return content;

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
                  Text(l10n.tabMe, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
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
        _chip(context, 'system', context.l10n.themeSystem),
        const SizedBox(width: 6),
        _chip(context, 'dark', context.l10n.themeDark),
        const SizedBox(width: 6),
        _chip(context, 'light', context.l10n.themeLight),
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

class _LocalePicker extends StatelessWidget {
  const _LocalePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(context, 'system', context.l10n.localeSystem),
          const SizedBox(width: 6),
          _chip(context, 'zh', context.l10n.localeZh),
          const SizedBox(width: 6),
          _chip(context, 'en', context.l10n.localeEn),
        ],
      ),
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
