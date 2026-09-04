import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/ui/ConversationPage.dart';
import 'package:yf_code/ui/OnlineDevicePage.dart';
import 'package:yf_code/utils/NetworkUtils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String? _localIp;
  String? _deviceName;
  late final AnimationController _pulseController;
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onNavSelected(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AtmosphereBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  deviceName: _deviceName,
                  localIp: _localIp,
                  pulse: _pulseController,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    children: const [
                      ConversationPage(),
                      OnlineDevicePage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: const Color(0xF2FFFFFF),
        indicatorColor: const Color(0xFF0E6E68).withValues(alpha: 0.12),
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: Color(0xFF0E6E68)),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices_rounded, color: Color(0xFF0E6E68)),
            label: '在线',
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
  const _Header({required this.deviceName, required this.localIp, required this.pulse});

  final String? deviceName;
  final String? localIp;
  final AnimationController pulse;

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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAN Chat',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: Color(0xFF152422),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
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
                                color: const Color(0xFF2A9B6A).withValues(alpha: 0.45),
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
  const _LocalIdentityCard({required this.deviceName, required this.localIp, required this.connected});

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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final letter = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';
    final bg = accent ? const Color(0xFF0E6E68) : const Color(0xFF1A9B90);

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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
