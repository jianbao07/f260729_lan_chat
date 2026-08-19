import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileStateType.dart';
import 'package:yf_code/channel/FileByteChannel.dart';
import 'package:yf_code/session/FileTransferSession.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/ui/ReceiveFileDialog.dart';
import 'package:yf_code/utils/log.dart';

/// 文件传输信令编排：Send / Reply / Ack ↔ TCP。
class FileTransferManager {
  FileTransferManager._();

  static final Map<String, FileTransferSession> _sessions = {};

  /// 用于在无 BuildContext 的信令回调里弹接收对话框。
  static GlobalKey<NavigatorState>? navigatorKey;

  static const Duration replyTimeout = Duration(seconds: 60);

  static FileTransferSession? get(String transferId) => _sessions[transferId];

  static String _newTransferId() {
    return '${InitManager.deviceId ?? "dev"}-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// 发送方：起 TCP 监听并发送 [SendFileBean]。
  static Future<void> offer(File file, String ip, String? deviceId) async {
    final transferId = _newTransferId();
    final tcp = FileByteChannel(ip, deviceId);
    final handle = await tcp.startSendFile(file);
    final params = handle.params;

    final bean = SendFileBean(
      transferId: transferId,
      mimeType: params.mimeType,
      name: params.name,
      totalSize: params.totalSize,
      port: params.port,
    );

    final session = FileTransferSession(
      transferId: transferId,
      isSender: true,
      peerIp: ip,
      peerDeviceId: deviceId,
      state: FileStateType.send,
      name: params.name,
      mimeType: params.mimeType,
      totalSize: params.totalSize,
      port: params.port,
      localPath: params.localPath,
      offerMessage: bean,
      sendHandle: handle,
    );
    _sessions[transferId] = session;

    session.replyTimeout = Timer(replyTimeout, () {
      iLog("等待接收方回复超时 transferId=$transferId");
      cancel(transferId);
    });

    await SendMessageManager.sendMessage(bean, ip, deviceId);
    // 发送后再写本地路径，保证上线 toJson 时字段为空
    bean.senderLocalPath = params.localPath;
    iLog("已发送文件 offer transferId=$transferId port=${params.port}");
  }

  /// 接收方：收到 [SendFileBean]。
  static void onOffer(SendFileBean offer, String ip) {
    final transferId = offer.transferId;
    if (transferId == null || transferId.isEmpty) {
      iLog("忽略无效文件 offer：缺少 transfer_id");
      return;
    }
    if (_sessions.containsKey(transferId)) {
      iLog("忽略重复文件 offer transferId=$transferId");
      return;
    }

    final session = FileTransferSession(
      transferId: transferId,
      isSender: false,
      peerIp: ip,
      peerDeviceId: offer.base?.fromDeviceId,
      state: FileStateType.send,
      name: offer.name,
      mimeType: offer.mimeType,
      totalSize: offer.totalSize,
      sha256: offer.sha256,
      port: offer.port,
      offerMessage: offer,
    );
    _sessions[transferId] = session;

    MessageManager.onMessageReceived(offer);
    _showReceiveDialog(transferId);
  }

  static void _showReceiveDialog(String transferId) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) {
      iLog("无法弹出接收对话框：navigatorKey 未就绪 transferId=$transferId");
      return;
    }
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => ReceiveFileDialog(transferId: transferId),
    );
  }

  /// 发送方：收到同意/拒绝。
  static Future<void> onReply(ReplySendFileBean reply, String ip) async {
    final transferId = reply.transferId;
    if (transferId == null) return;

    final session = _sessions[transferId];
    if (session == null || !session.isSender) {
      iLog("收到未知 transfer 的 reply transferId=$transferId");
      return;
    }

    final state = FileStateType.fromCode(reply.state ?? '');
    session.replyTimeout?.cancel();
    session.replyTimeout = null;

    if (state == FileStateType.rejected) {
      iLog("对方拒绝接收 transferId=$transferId");
      session.state = FileStateType.rejected;
      MessageManager.applyFileReply(reply);
      await session.closeServer();
      _sessions.remove(transferId);
      return;
    }

    if (state == FileStateType.transferring) {
      iLog("对方同意接收，等待 TCP 连接 transferId=$transferId");
      session.state = FileStateType.transferring;
      MessageManager.applyFileReply(reply);
      // TCP 由 FileSendHandle 继续等待对方 connect
      return;
    }

    iLog("忽略未知 reply state=${reply.state} transferId=$transferId");
  }

  /// 发送方：收到接收完成 Ack。
  static Future<void> onAck(AckFileBean ack) async {
    final transferId = ack.transferId;
    if (transferId == null) return;

    final session = _sessions[transferId];
    if (session == null || !session.isSender) {
      iLog("收到未知 transfer 的 ack transferId=$transferId");
      return;
    }

    final state = FileStateType.fromCode(ack.state ?? '');
    if (state != FileStateType.success) {
      iLog("忽略非 success 的文件 ack state=${ack.state}");
      return;
    }

    iLog("文件传输成功 ack transferId=$transferId");
    session.state = FileStateType.success;
    MessageManager.applyFileAck(ack);
    session.replyTimeout?.cancel();
    await session.closeServer();
    _sessions.remove(transferId);
  }

  /// 接收方：同意接收。先发 Reply，再 connect。
  static Future<void> accept(String transferId, {String? savePath}) async {
    final session = _sessions[transferId];
    if (session == null || session.isSender) {
      iLog("accept 失败：会话不存在或非接收方 transferId=$transferId");
      return;
    }
    final offer = session.offerMessage;
    final port = session.port;
    if (offer == null || port == null) {
      iLog("accept 失败：缺少 offer/port transferId=$transferId");
      return;
    }

    session.state = FileStateType.transferring;
    MessageManager.updateFileState(transferId, FileStateType.transferring);
    final reply = ReplySendFileBean.buildAccept(offer);
    await SendMessageManager.sendMessage(
      reply,
      session.peerIp,
      session.peerDeviceId,
    );

    final path = savePath ??
        FileByteChannel.defaultSavePath(
          name: session.name,
          fromMessageId: transferId,
        );
    session.localPath = path;

    final tcp = FileByteChannel(session.peerIp, session.peerDeviceId);
    try {
      await tcp.startReceiveFile(
        port: port,
        localPath: path,
        totalSize: session.totalSize ?? 0,
        name: session.name,
      );
      session.state = FileStateType.success;
      final ack = AckFileBean.buildSuccess(offer, receiverLocalPath: path);
      await SendMessageManager.sendMessage(
        ack,
        session.peerIp,
        session.peerDeviceId,
      );
      MessageManager.updateFileState(
        transferId,
        FileStateType.success,
        receiverLocalPath: path,
      );
      iLog("接收完成并已发送 ack transferId=$transferId path=$path");
    } catch (e) {
      iLog("接收失败 transferId=$transferId: $e");
      MessageManager.updateFileState(transferId, FileStateType.rejected);
    } finally {
      _sessions.remove(transferId);
    }
  }

  /// 接收方：拒绝接收。
  static Future<void> reject(String transferId) async {
    final session = _sessions[transferId];
    if (session == null || session.isSender) {
      iLog("reject 失败：会话不存在或非接收方 transferId=$transferId");
      return;
    }
    final offer = session.offerMessage;
    if (offer == null) {
      _sessions.remove(transferId);
      return;
    }

    session.state = FileStateType.rejected;
    MessageManager.updateFileState(transferId, FileStateType.rejected);
    final reply = ReplySendFileBean.buildRejected(offer);
    await SendMessageManager.sendMessage(
      reply,
      session.peerIp,
      session.peerDeviceId,
    );
    _sessions.remove(transferId);
    iLog("已拒绝接收 transferId=$transferId");
  }

  /// 取消会话（超时 / 主动取消）。
  static Future<void> cancel(String transferId) async {
    final session = _sessions.remove(transferId);
    if (session == null) return;
    MessageManager.updateFileState(transferId, FileStateType.rejected);
    await session.closeServer();
    iLog("已取消文件传输 transferId=$transferId");
  }
}
