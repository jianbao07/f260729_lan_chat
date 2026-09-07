import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/widgets/PeerAvatar.dart';

void showAppToast(BuildContext context, String message) {
  final c = context.colors;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: c.textPrimary, fontSize: 13)),
      backgroundColor: c.raised,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      duration: const Duration(milliseconds: 1600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
    ),
  );
}

String relativeTimeLabel(int? utcMs) {
  if (utcMs == null) return '';
  final last = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  final diff = DateTime.now().toUtc().difference(last);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  final local = last.toLocal();
  final now = DateTime.now();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (local.year == now.year) return '${local.month}/${local.day}';
  return '${local.year}/${local.month}/${local.day}';
}

String lastSeenLabel(int? utcMs) {
  if (utcMs == null) return '未知';
  final last = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  final diff = DateTime.now().toUtc().difference(last);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return relativeTimeLabel(utcMs);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, required this.sub, this.icon = Icons.radar});

  final String text;
  final String sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: c.textTertiary),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(color: c.textTertiary, fontSize: 12.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.textTertiary)),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    this.value,
    this.mono = false,
    this.showDivider = true,
    this.child,
  });

  final String label;
  final String? value;
  final bool mono;
  final bool showDivider;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: c.hairline)) : null,
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: child ?? _CopyableValue(value: value ?? '', mono: mono),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableValue extends StatefulWidget {
  const _CopyableValue({required this.value, required this.mono});

  final String value;
  final bool mono;

  @override
  State<_CopyableValue> createState() => _CopyableValueState();
}

class _CopyableValueState extends State<_CopyableValue> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textPrimary,
              fontFamily: widget.mono ? kMonoFont : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _copy,
          child: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 14, color: _copied ? c.online : c.textTertiary),
        ),
      ],
    );
  }
}

class EditableRow extends StatefulWidget {
  const EditableRow({
    super.key,
    required this.label,
    required this.value,
    required this.emptyLabel,
    required this.onSave,
    this.inputPlaceholder,
    this.maxLength = 20,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final String emptyLabel;
  final String? inputPlaceholder;
  final ValueChanged<String> onSave;
  final int maxLength;
  final bool showDivider;

  @override
  State<EditableRow> createState() => _EditableRowState();
}

class _EditableRowState extends State<EditableRow> {
  var _editing = false;
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant EditableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() => _editing = true);
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _save() {
    widget.onSave(_controller.text.trim());
    setState(() => _editing = false);
  }

  void _cancel() {
    _controller.text = widget.value;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: widget.showDivider ? Border(bottom: BorderSide(color: c.hairline)) : null,
      ),
      child: Row(
        children: [
          Text(widget.label, style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: _editing
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          maxLength: widget.maxLength,
                          onSubmitted: (_) => _save(),
                          style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            counterText: '',
                            hintText: widget.inputPlaceholder,
                            hintStyle: TextStyle(color: c.textTertiary, fontSize: 13.5),
                            filled: true,
                            fillColor: c.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: c.accent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: c.accent),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _save,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.check, size: 17, color: c.online),
                      ),
                      IconButton(
                        onPressed: _cancel,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close, size: 17, color: c.textTertiary),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _startEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.value.isEmpty ? widget.emptyLabel : widget.value,
                            style: TextStyle(fontSize: 13.5, color: widget.value.isEmpty ? c.textTertiary : c.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_outlined, size: 13, color: c.textTertiary),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: on ? c.accent : c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: on ? c.onAccent : c.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class AppTabButton extends StatelessWidget {
  const AppTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.accent : c.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 9, 0, 11),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: color),
                  ),
                ],
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: 0,
                  right: 18,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(999)),
                    alignment: Alignment.center,
                    child: Text(
                      '$badge',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.onAccent, fontFamily: kMonoFont),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.id,
    required this.displayName,
    this.originalName,
    this.online,
    this.lastSeen,
    this.showStatus = true,
  });

  final String id;
  final String displayName;
  final String? originalName;
  final bool? online;
  final String? lastSeen;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isOnline = online ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
      child: Column(
        children: [
          PeerAvatar(id: id, name: displayName, size: 76, radius: 20, online: isOnline, showStatus: showStatus, pulse: showStatus && isOnline),
          const SizedBox(height: 14),
          Text(displayName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.textPrimary)),
          if (originalName != null && originalName!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(originalName!, style: TextStyle(fontSize: 12.5, color: c.textTertiary)),
          ],
          if (online != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: isOnline ? c.online : c.textTertiary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? '在线' : '离线 · 最后在线 ${lastSeen ?? '未知'}',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
