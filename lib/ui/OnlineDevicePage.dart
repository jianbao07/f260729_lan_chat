import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/utils/page.dart';

class OnlineDevicePage extends StatefulWidget {
  const OnlineDevicePage({super.key});

  @override
  State<OnlineDevicePage> createState() => _OnlineDevicePageState();
}

class _OnlineDevicePageState extends State<OnlineDevicePage> with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OnlineDeviceModel.instance,
      builder: (context, _) {
        final devices = OnlineDeviceModel.instance.deviceList;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(onlineCount: devices.length),
            Expanded(
              child: devices.isEmpty
                  ? _EmptyDiscovery(scan: _scanController)
                  : _DeviceList(devices: devices),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onlineCount});

  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          const Text(
            '在线设备',
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
              '$onlineCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E6E68),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            '自动发现中',
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

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery({required this.scan});

  final AnimationController scan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: scan,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(120, 120),
                  painter: _RadarPainter(progress: scan.value),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              '正在搜寻附近设备',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF152422),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '确保对方已打开 LAN Chat，并连接到同一 Wi‑Fi',
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

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    for (var i = 1; i <= 3; i++) {
      final paint = Paint()
        ..color = const Color(0xFF0E6E68).withValues(alpha: 0.12 + i * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, maxR * i / 3, paint);
    }

    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2 - math.pi / 2),
        colors: [
          const Color(0xFF1A9B90).withValues(alpha: 0.0),
          const Color(0xFF1A9B90).withValues(alpha: 0.28),
          const Color(0xFF0E6E68).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.12, 0.35],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, sweep);

    final core = Paint()..color = const Color(0xFF0E6E68);
    canvas.drawCircle(center, 5, core);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<DeviceBean> devices;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final device = devices[index];
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
          child: _DeviceTile(device: device),
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final DeviceBean device;

  bool get _isStale {
    final ts = device.updateTimestampUtc?.toInt();
    if (ts == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    return DateTime.now().toUtc().difference(last) > const Duration(seconds: 15);
  }

  String get _lastSeenLabel {
    final ts = device.updateTimestampUtc?.toInt();
    if (ts == null) return '未知';
    final last = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    final diff = DateTime.now().toUtc().difference(last);
    if (diff.inSeconds < 8) return '刚刚活跃';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s 前';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    return '${diff.inHours} 小时前';
  }

  @override
  Widget build(BuildContext context) {
    final name = device.name?.isNotEmpty == true ? device.name! : '未知设备';
    final stale = _isStale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          startPage(context, ChatPage(device: device));
        },
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
              _Avatar(label: name, dimmed: stale),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: stale
                            ? const Color(0xFF3D4F4C)
                            : const Color(0xFF152422),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.ipAddress ?? '—'}  ·  $_lastSeenLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6A7C79),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stale
                          ? const Color(0xFFB8860B)
                          : const Color(0xFF2A9B6A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFF6A7C79).withValues(alpha: 0.7),
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
