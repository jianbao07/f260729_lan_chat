import 'package:flutter/material.dart';
import 'package:yf_code/theme/AppColors.dart';

class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 44,
    this.radius = 12,
    this.online = false,
    this.showStatus = true,
    this.pulse = false,
  });

  final String id;
  final String name;
  final double size;
  final double radius;
  final bool online;
  final bool showStatus;
  final bool pulse;

  static Color colorOf(String id) {
    var sum = 0;
    for (var i = 0; i < id.length; i++) {
      sum += id.codeUnitAt(i);
    }
    return AppColors.avatarPalette[sum % AppColors.avatarPalette.length];
  }

  static String initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed)) {
      return trimmed.length <= 2 ? trimmed : trimmed.substring(trimmed.length - 2);
    }
    return trimmed.length <= 2 ? trimmed.toUpperCase() : trimmed.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorOf(id),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Text(
              initialsOf(name),
              style: TextStyle(
                color: AppColors.avatarInk,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.36,
                letterSpacing: -0.2,
                height: 1,
              ),
            ),
          ),
          if (showStatus)
            Positioned(
              right: -2,
              bottom: -2,
              child: _StatusDot(online: online, pulse: pulse && online, borderColor: c.bg),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.online, required this.pulse, required this.borderColor});

  final bool online;
  final bool pulse;
  final Color borderColor;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && _controller == null) {
      _startPulse();
    } else if (!widget.pulse) {
      _controller?.dispose();
      _controller = null;
    }
  }

  void _startPulse() {
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = widget.online ? c.online : c.textTertiary;
    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: widget.borderColor, width: 2.5),
      ),
    );
    final controller = _controller;
    if (controller == null) return dot;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final spread = 7.0 * (t < 0.7 ? t / 0.7 : 1);
        final alpha = t < 0.7 ? 0.55 * (1 - t / 0.7) : 0.0;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFF7FBF6E).withValues(alpha: alpha), spreadRadius: spread)],
          ),
          child: child,
        );
      },
      child: dot,
    );
  }
}
