import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/bean/AckFileBean.dart';
import 'package:yf_code/bean/FileTransferRecord.dart';
import 'package:yf_code/bean/ReplySendFileBean.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/channel/FileByteChannel.dart';
import 'package:yf_code/session/FileTransferSession.dart';
import 'package:yf_code/manager/AppFileStore.dart';
import 'package:yf_code/manager/MessageManager.dart';
import 'package:yf_code/manager/SendMessageManager.dart';
import 'package:yf_code/ui/ReceiveFileDialog.dart';
import 'package:yf_code/utils/FileUtils.dart';
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
    final server = await tcp.startSendFile(
      file,
      onProgress: (current, total) {
        MessageManager.updateFile(
          transferId,
          current: current,
          total: total,
        );
      },
      onSendFailed: (errorMsg) {
        MessageManager.updateFile(transferId, state: FileTransferState.failed, errorMsg: errorMsg);
      },
    );
    final name = FileUtils.fileNameOf(file);
    final mimeType = FileUtils.mimeTypeOf(file);
    final totalSize = await file.length();
    final port = server.port;
    final localPath = file.path;

    final bean = SendFileBean(
      transferId: transferId,
      mimeType: mimeType,
      name: name,
      totalSize: totalSize,
      port: port,
    );

    final session = FileTransferSession(
      transferId: transferId,
      isSender: true,
      peerIp: ip,
      peerDeviceId: deviceId,
      state: FileTransferState.send,
      name: name,
      mimeType: mimeType,
      totalSize: totalSize,
      port: port,
      localPath: localPath,
      offerMessage: bean,
      server: server,
    );
    _sessions[transferId] = session;

    session.replyTimeout = Timer(replyTimeout, () {
      iLog("等待接收方回复超时 transferId=$transferId");
      cancel(transferId);
    });

    await SendMessageManager.sendMessage(bean, ip, deviceId);
    MessageManager.updateFile(transferId, state: FileTransferState.send, localPath: localPath);
    iLog("已发送文件 offer transferId=$transferId port=$port");
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
      state: FileTransferState.send,
      name: offer.name,
      mimeType: offer.mimeType,
      totalSize: offer.totalSize,
      sha256: offer.sha256,
      port: offer.port,
      offerMessage: offer,
    );
    _sessions[transferId] = session;
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

    final state = FileTransferState.fromCode(reply.state ?? '');
    session.replyTimeout?.cancel();
    session.replyTimeout = null;
    if(reply.transferId!=null){
      MessageManager.updateFile(reply.transferId!, state: state);
    }

    if (state == FileTransferState.rejected) {
      iLog("对方拒绝接收 transferId=$transferId");
      session.state = FileTransferState.rejected;
      await session.closeServer();
      _sessions.remove(transferId);
      return;
    }

    if (state == FileTransferState.transferring) {
      iLog("对方同意接收，等待 TCP 连接 transferId=$transferId");
      session.state = FileTransferState.transferring;
      // TCP 继续等待对方 connect
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

    final state = FileTransferState.fromCode(ack.state ?? '');
    if(state!=null){
      MessageManager.updateFile(transferId, state: state);
    }
    if (state == FileTransferState.success) {
      iLog("文件传输成功 ack transferId=$transferId");
      session.state = FileTransferState.success;
    } else if (state == FileTransferState.failed) {
      iLog("文件传输失败 ack transferId=$transferId");
      session.state = FileTransferState.failed;
    } else {
      iLog("忽略未知文件 ack state=${ack.state}");
      return;
    }

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

    session.state = FileTransferState.transferring;
    MessageManager.updateFile(transferId, state: FileTransferState.transferring);
    final reply = ReplySendFileBean.buildAccept(offer);
    await SendMessageManager.sendMessage(
      reply,
      session.peerIp,
      session.peerDeviceId,
    );

    final path = savePath ??
        await AppFileStore.pathForIncoming(
          transferId: transferId,
          name: session.name,
        );
    session.localPath = path;

    final tcp = FileByteChannel(session.peerIp, session.peerDeviceId);
    try {
      await tcp.startReceiveFile(
        port: port,
        localPath: path,
        totalSize: session.totalSize ?? 0,
        name: session.name,
        onProgress: (current, total) {
          MessageManager.updateFile(
            transferId,
            current: current,
            total: total,
          );
        },
        onReceiveFailed: (errorMsg) {
          MessageManager.updateFile(transferId, state: FileTransferState.failed, errorMsg: errorMsg);
        },
      );
      session.state = FileTransferState.success;
      offer.receiverTransfer ??= FileTransferRecord(transferId: transferId, isSender: false);
      offer.receiverTransfer!.localPath = path;
      final ack = AckFileBean.buildSuccess(offer, receiverLocalPath: path);
      await SendMessageManager.sendMessage(
        ack,
        session.peerIp,
        session.peerDeviceId,
      );
      MessageManager.updateFile(
        transferId,
        state: FileTransferState.success,
        receiverLocalPath: path,
      );
      iLog("接收完成并已发送 ack transferId=$transferId path=$path");
    } catch (e) {
      iLog("接收失败 transferId=$transferId: $e");
      session.state = FileTransferState.failed;
      final ack = AckFileBean.buildFailed(offer);
      await SendMessageManager.sendMessage(
        ack,
        session.peerIp,
        session.peerDeviceId,
      );
      MessageManager.updateFile(transferId, state: FileTransferState.failed);
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

    session.state = FileTransferState.rejected;
    MessageManager.updateFile(transferId, state: FileTransferState.rejected);
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
    MessageManager.updateFile(transferId, state: FileTransferState.failed);
    await session.closeServer();
    iLog("已取消文件传输 transferId=$transferId");
  }
}
