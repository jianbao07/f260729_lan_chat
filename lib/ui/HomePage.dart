import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/manager/SendTextManager.dart';
import 'package:yf_code/model/DeviceModel.dart';
import 'package:yf_code/ui/ChatPage.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String? _localIp;
  String? _deviceName;
  late final AnimationController _pulseController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _loadLocalInfo();
  }

  Future<void> _loadLocalInfo() async {
    final ip = await NetworkUtils.getWifiIP();
    if (!mounted) return;
    setState(() {
      _localIp = ip;
      _deviceName = InitManager.deviceName;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: DeviceModel.instance,
        builder: (context, _) {
          final devices = DeviceModel.instance.deviceList;
          return Stack(
            children: [
              const _AtmosphereBackground(),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      deviceName: _deviceName,
                      localIp: _localIp,
                      pulse: _pulseController,
                      onlineCount: devices.length,
                    ),
                    Expanded(
                      child: devices.isEmpty
                          ? _EmptyDiscovery(scan: _scanController)
                          : _DeviceList(devices: devices),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MeshPainter(),
      child: Container(
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
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0E6E68).withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final step = size.width / 8;
    for (var i = 0; i < 10; i++) {
      final y = size.height * 0.08 + i * step * 0.7;
      final path = Path();
      path.moveTo(0, y);
      path.quadraticBezierTo(
        size.width * 0.35,
        y - 18 + (i % 3) * 8,
        size.width * 0.7,
        y + 6,
      );
      path.quadraticBezierTo(
        size.width * 0.9,
        y + 14,
        size.width,
        y - 4,
      );
      canvas.drawPath(path, paint);
    }

    final nodePaint = Paint()
      ..color = const Color(0xFF1A9B90).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final nodes = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.16),
      Offset(size.width * 0.88, size.height * 0.38),
      Offset(size.width * 0.28, size.height * 0.55),
    ];
    for (final n in nodes) {
      canvas.drawCircle(n, 4, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.deviceName,
    required this.localIp,
    required this.pulse,
    required this.onlineCount,
  });

  final String? deviceName;
  final String? localIp;
  final AnimationController pulse;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    final connected = localIp != null && localIp!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAN Chat',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: Color(0xFF152422),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '同一网络，即刻连通',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: Color(0xFF6A7C79),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              _OnlineBadge(pulse: pulse, connected: connected),
            ],
          ),
          const SizedBox(height: 22),
          _LocalIdentityCard(
            deviceName: deviceName ?? '本机',
            localIp: localIp,
            connected: connected,
          ),
          const SizedBox(height: 28),
          Row(
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
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.pulse, required this.connected});

  final AnimationController pulse;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        final scale = 1.0 + 0.35 * math.sin(t * math.pi * 2).abs();
        final alpha = 0.35 * (1 - t);
        return Column(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (connected)
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A9B6A).withValues(alpha: alpha),
                        ),
                      ),
                    ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? const Color(0xFF2A9B6A)
                          : const Color(0xFF6A7C79),
                      boxShadow: connected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2A9B6A)
                                    .withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              connected ? '已入网' : '未连接',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: connected
                    ? const Color(0xFF2A9B6A)
                    : const Color(0xFF6A7C79),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocalIdentityCard extends StatelessWidget {
  const _LocalIdentityCard({
    required this.deviceName,
    required this.localIp,
    required this.connected,
  });

  final String deviceName;
  final String? localIp;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A0E6E68)),
      ),
      child: Row(
        children: [
          _Avatar(label: deviceName, accent: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF152422),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? (localIp ?? '—') : '等待局域网连接…',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6A7C79),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0E6E68).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '本机',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0E6E68),
              ),
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
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
              _Avatar(label: name, accent: false, dimmed: stale),
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
  const _Avatar({
    required this.label,
    required this.accent,
    this.dimmed = false,
  });

  final String label;
  final bool accent;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final letter = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';
    final bg = accent
        ? const Color(0xFF0E6E68)
        : Color.lerp(
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
