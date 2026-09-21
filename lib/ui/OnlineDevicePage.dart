import 'package:flutter/material.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/manager/OnlineDeviceManager.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ProfilePage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/page.dart';

class OnlineDevicePage extends StatefulWidget {
  const OnlineDevicePage({super.key});

  @override
  State<OnlineDevicePage> createState() => _OnlineDevicePageState();
}

class _OnlineDevicePageState extends State<OnlineDevicePage> {
  var _scanning = false;
  String? _cidr;

  @override
  void initState() {
    super.initState();
    OnlineDeviceModel.instance.addListener(_onChanged);
    AppSettings.instance.addListener(_onChanged);
    _loadCidr();
  }

  @override
  void dispose() {
    OnlineDeviceModel.instance.removeListener(_onChanged);
    AppSettings.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCidr() async {
    final cidr = await NetworkUtils.getLanCidr();
    if (mounted) setState(() => _cidr = cidr);
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    OnlineDeviceManager.refreshNow();
    await _loadCidr();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _scanning = false);
    final count = OnlineDeviceModel.instance.deviceList.length;
    showAppToast(context, context.l10n.scanDone(count));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final devices = OnlineDeviceModel.instance.deviceList;
    final subnet = _cidr != null ? l10n.subnetSuffix(_cidr!) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.onlineCount(devices.length)}$subnet',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontFamily: kMonoFont),
                ),
              ),
              InkWell(
                onTap: _scan,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: _scanning
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: c.textSecondary),
                        )
                      : Icon(Icons.refresh, size: 15, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: devices.isEmpty
              ? EmptyState(text: l10n.noOnlineDevices, sub: l10n.noOnlineDevicesHint)
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) => _DeviceRow(device: devices[index]),
                ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final DeviceBean device;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rawName = device.name?.isNotEmpty == true ? device.name! : context.l10n.unknownDevice;
    final displayName = AppSettings.instance.displayNameOf(device.deviceId, rawName);
    final id = device.deviceId ?? displayName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => startPage(context, ProfilePage(device: device)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              PeerAvatar(id: id, name: displayName, size: 42, online: true, pulse: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.ipAddress ?? '—',
                      style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: kMonoFont),
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
