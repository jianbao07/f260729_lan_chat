import 'package:flutter/material.dart';
import 'package:yf_code/manager/FileTransferManager.dart';
import 'package:yf_code/session/FileTransferSession.dart';

class ReceiveFileDialog extends StatefulWidget {
  const ReceiveFileDialog({super.key, required this.transferId});

  final String transferId;

  @override
  State<ReceiveFileDialog> createState() => _ReceiveFileDialogState();
}

class _ReceiveFileDialogState extends State<ReceiveFileDialog> {
  bool _busy = false;

  FileTransferSession? get _session =>
      FileTransferManager.get(widget.transferId);

  String _formatSize(int? bytes) {
    if (bytes == null || bytes < 0) return '未知大小';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _onReject() async {
    if (_busy) return;
    setState(() => _busy = true);
    await FileTransferManager.reject(widget.transferId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onAccept() async {
    if (_busy) return;
    setState(() => _busy = true);
    Navigator.of(context).pop();
    await FileTransferManager.accept(widget.transferId);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final name = session?.name ?? '未知文件';
    final sizeLabel = _formatSize(session?.totalSize);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '收到文件',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF152422),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF152422),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sizeLabel,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6A7C79),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              color: Color(0xFF0E6E68),
              backgroundColor: Color(0x1A0E6E68),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _onReject,
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: _busy ? null : _onAccept,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0E6E68),
          ),
          child: const Text('接收'),
        ),
      ],
    );
  }
}
