import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:yf_code/cipher/Ed25519Key.dart';
import 'package:yf_code/cipher/PublicKeyChangeLog.dart';
import 'package:yf_code/enum/RawMessageType.dart';
import 'package:yf_code/bean/CmdBeatBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/model/ConversationModel.dart';
import 'package:yf_code/model/OnlineDeviceModel.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/utils/MulticastLock.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/log.dart';

class OnlineDeviceManager {
  OnlineDeviceManager._();
  static const int _LISTENER_PORT = 54832;
  static const String _MULTICAST_GROUP = '239.255.255.1';

  static Timer? _beatTimer;
  static RawDatagramSocket? _beatSocket;
  static RawDatagramSocket? _listenerSocket;
  static bool _beatRunning = false;
  static int _beatEpoch = 0;
  static String? _myIP;
  static String? _deviceInfoDir;
  static Map<String,DeviceBean> _onlineDeviceMap={};
  static bool _isChange=false;
  static const int _HEART_INTERVAL=5000;

  static void _onBeat(CmdBeatBean b,String ip){
    final deviceId=b.deviceId;
    if(deviceId==null){
      iLog("${ip}:设备id为空");
      return;
    }
    PublicKeyChangeLog.observe(deviceId, b.publicKey, b.timestampUtc?.toInt());
    final d=_onlineDeviceMap[deviceId];
    final device=d==null
      ? DeviceBean(
          name: b.name,
          ipAddress: ip,
          updateTimestampUtc: b.timestampUtc,
          deviceId: b.deviceId,
          publicKey: b.publicKey,
        )
      : d.copyWith(
          name: b.name,
          ipAddress: ip,
          updateTimestampUtc: b.timestampUtc,
          deviceId: b.deviceId,
          publicKey: b.publicKey,
        );
    _onlineDeviceMap[deviceId]=device;
    _isChange=true;
    updateDeviceInfo(device);
  }

  static void updateList(){
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    final before = _onlineDeviceMap.length;
    _onlineDeviceMap.removeWhere((_, d) {
      final ts = d.updateTimestampUtc?.toInt();
      return ts == null || nowUtc - ts > _HEART_INTERVAL * 2;
    });
    if (_isChange || _onlineDeviceMap.length != before) {
      OnlineDeviceModel.instance.setDeviceList(_onlineDeviceMap.values.toList());
    }
  }

  static void startBeat() async {
    final epoch = ++_beatEpoch;
    _beatRunning = true;
    _beatTimer?.cancel();
    _beatTimer = null;
    _closeBeatSocket();
    _myIP=await NetworkUtils.getWifiIP();
    if (epoch != _beatEpoch) return;
    iLog("启动心跳,ip地址=$_myIP,组播地址=$_MULTICAST_GROUP");

    await _openBeatSocket(epoch);
    if (epoch != _beatEpoch || !_beatRunning) return;

    _sendBeat();
    _beatTimer = Timer.periodic(const Duration(milliseconds: _HEART_INTERVAL), (_) => _sendBeat());
  }

  static void stopBeat() {
    iLog("停止心跳");
    _beatEpoch++;
    _beatRunning = false;
    _beatTimer?.cancel();
    _beatTimer = null;
    _closeBeatSocket();
  }

  static Future<void> _openBeatSocket(int epoch) async {
    if (epoch != _beatEpoch || !_beatRunning) return;
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      iLog("心跳 socket 绑定失败: $e");
      _scheduleReopenBeatSocket(epoch);
      return;
    }
    if (epoch != _beatEpoch || !_beatRunning) {
      socket.close();
      return;
    }
    _beatSocket = socket;
    socket.listen((event) {
      if (event == RawSocketEvent.closed) {
        _onBeatSocketLost(socket, epoch, "心跳 socket 已断开");
      }
    }, onError: (e) {
      _onBeatSocketLost(socket, epoch, "心跳 socket 异常: $e");
    }, onDone: () {
      _onBeatSocketLost(socket, epoch, "心跳 socket 已断开");
    });
  }

  static void _onBeatSocketLost(RawDatagramSocket socket, int epoch, String reason) {
    if (!identical(_beatSocket, socket)) return;
    iLog(reason);
    _beatSocket = null;
    socket.close();
    _scheduleReopenBeatSocket(epoch);
  }

  static void _scheduleReopenBeatSocket(int epoch) {
    if (epoch != _beatEpoch || !_beatRunning) return;
    Future<void>.delayed(const Duration(seconds: 1), () async {
      if (epoch != _beatEpoch || !_beatRunning || _beatSocket != null) return;
      await _openBeatSocket(epoch);
    });
  }

  static Future<void> _sendBeat() async {
    if (!_beatRunning) return;
    updateList();
    _isChange=false;
    final socket = _beatSocket;
    if (socket == null) return;
    final b=await getBeatBean();
    if (!_beatRunning || !identical(_beatSocket, socket)) return;
    final payload = jsonEncode(b.toJson());
    iLog("心跳");
    try {
      socket.send(
        utf8.encode(payload),
        InternetAddress(_MULTICAST_GROUP),
        _LISTENER_PORT,
      );
    } catch (e) {
      iLog("心跳发送失败: $e");
      _onBeatSocketLost(socket, _beatEpoch, "心跳 socket 已断开");
    }
  }

  static void _closeBeatSocket() {
    final socket = _beatSocket;
    _beatSocket = null;
    socket?.close();
  }

  static void refreshNow() {
    updateList();
  }

  static void listenerBeat() async {
    _listenerSocket?.close();

    final locked = await MulticastLock.acquire();
    if (!locked) {
      // iLog("MulticastLock 获取失败，UDP广播可能无法接收");
      iLog("MulticastLock 获取失败，UDP组播可能无法接收");
    }

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _LISTENER_PORT,
      reuseAddress: true,
    );
    // socket.broadcastEnabled = true;
    final localIp = await NetworkUtils.getWifiIP();
    if (localIp != null) {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      NetworkInterface? wifiInterface;
      for (final ni in interfaces) {
        if (ni.addresses.any((a) => a.address == localIp)) {
          wifiInterface = ni;
          break;
        }
      }
      if (wifiInterface != null) {
        socket.joinMulticast(InternetAddress(_MULTICAST_GROUP), wifiInterface);
      } else {
        socket.joinMulticast(InternetAddress(_MULTICAST_GROUP));
      }
    } else {
      socket.joinMulticast(InternetAddress(_MULTICAST_GROUP));
    }
    _listenerSocket = socket;
    // iLog("开始监听心跳端口=$_LISTENER_PORT");
    iLog("开始监听心跳端口=$_LISTENER_PORT,组播组=$_MULTICAST_GROUP");

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final ip=datagram.address.address;
      final port=datagram.port;
      if(ip==_myIP){
        dLog("收到自己的心跳");
        return;
      }

      try {
        final text = utf8.decode(datagram.data);
        final json = jsonDecode(text) as Map<String, dynamic>;
        final b=CmdBeatBean.fromJson(json);
        _onBeat(b,ip);
        final time=DateTime.fromMillisecondsSinceEpoch(b.timestampUtc?.toInt()??0,isUtc: true);
        dLog(
          "收到心跳 from=${ip}:${port} "
              "name=${b.name} time=${time.toLocal()}",
        );
      } catch (e) {
        dLog("心跳解析失败 from=${datagram.address.address}: $e");
      }
    });
  }

  static Future<void> updateDeviceInfo(DeviceBean device) async {
    ConversationModel.instance.onDeviceUpdate(device);
    final deviceId = device.deviceId;
    if (deviceId == null || deviceId.isEmpty) return;
    final dir = await _deviceInfoRoot();
    final file = File('${dir.path}${Platform.pathSeparator}${_deviceFileName(deviceId)}');
    await file.writeAsString(jsonEncode(device.toJson()));
  }

  static Future<DeviceBean?> getDeviceInfo(String deviceId) async {
    if (deviceId.isEmpty) return null;
    final onlineDevice=_onlineDeviceMap[deviceId];
    if(onlineDevice!=null){
      return onlineDevice;
    }
    final dir = await _deviceInfoRoot();
    final file = File('${dir.path}${Platform.pathSeparator}${_deviceFileName(deviceId)}');
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return DeviceBean.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<CmdBeatBean> getBeatBean() async {
    final now=DateTime.now();
    final publicKey = (await Ed25519Key.getLongTermKey()).publicKeyHex;
    final b=CmdBeatBean(name: InitManager.deviceName??_myIP,type: RawMessageType.beat.code,timestampUtc: now.toUtc().millisecondsSinceEpoch,deviceId: InitManager.deviceId,publicKey: publicKey);
    return b;
  }

  static Future<Directory> _deviceInfoRoot() async {
    final cached = _deviceInfoDir;
    if (cached != null) return Directory(cached);
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}device');
    await dir.create(recursive: true);
    _deviceInfoDir = dir.path;
    return dir;
  }

  static String _deviceFileName(String deviceId) {
    final safe = deviceId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll('..', '_');
    return '${safe.isEmpty ? 'unknown' : safe}.json';
  }
}
