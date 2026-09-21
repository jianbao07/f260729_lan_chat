import 'package:flutter/material.dart';
import 'package:yf_code/l10n/l10n.dart';
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
    final badge = (size * 0.3).clamp(12.0, 18.0);
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
          if (showStatus && online)
            Positioned(
              right: -2,
              bottom: -2,
              child: PresenceDot(size: badge, pulse: pulse, borderColor: c.bg),
            ),
        ],
      ),
    );
  }
}

class PresenceDot extends StatefulWidget {
  const PresenceDot({super.key, this.size = 12, this.pulse = false, this.borderColor});

  final double size;
  final bool pulse;
  final Color? borderColor;

  @override
  State<PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<PresenceDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(covariant PresenceDot oldWidget) {
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
    final ring = widget.borderColor == null ? 0.0 : (widget.size * 0.18).clamp(2.0, 2.6);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: c.online,
        shape: BoxShape.circle,
        border: ring > 0 ? Border.all(color: widget.borderColor!, width: ring) : null,
      ),
    );
    final controller = _controller;
    if (controller == null) return dot;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final spread = (widget.size * 0.55) * (t < 0.7 ? t / 0.7 : 1);
        final alpha = t < 0.7 ? 0.5 * (1 - t / 0.7) : 0.0;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.online.withValues(alpha: alpha), spreadRadius: spread)],
          ),
          child: child,
        );
      },
      child: dot,
    );
  }
}

class PresenceChip extends StatelessWidget {
  const PresenceChip({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = online ? c.online : c.textTertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: BoxDecoration(
        color: online ? c.onlineDim : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: online ? fg.withValues(alpha: 0.5) : c.border),
      ),
      child: Text(
        online ? context.l10n.online : context.l10n.offline,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg, height: 1.2, letterSpacing: 0.15),
      ),
    );
  }
}
