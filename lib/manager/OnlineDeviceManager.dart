import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
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
  static String? _myIP;
  static String? _deviceInfoDir;
  static Map<String,DeviceBean> _deviceMap={};
  static bool _isChange=false;
  static const int _HEART_INTERVAL=5000;

  static void _onBeat(CmdBeatBean b,String ip){
    final deviceId=b.deviceId;
    if(deviceId==null){
      iLog("${ip}:设备id为空");
      return;
    }
    final d=_deviceMap[deviceId];
    final device=d==null
      ? DeviceBean(
          name: b.name,
          ipAddress: ip,
          updateTimestampUtc: b.timestampUtc,
          deviceId: b.deviceId,
        )
      : d.copyWith(
          name: b.name,
          ipAddress: ip,
          updateTimestampUtc: b.timestampUtc,
          deviceId: b.deviceId,
        );
    _deviceMap[deviceId]=device;
    _isChange=true;
    updateDeviceInfo(device);
  }

  static void updateList(){
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    final before = _deviceMap.length;
    _deviceMap.removeWhere((_, d) {
      final ts = d.updateTimestampUtc?.toInt();
      return ts == null || nowUtc - ts > _HEART_INTERVAL * 2;
    });
    if (_isChange || _deviceMap.length != before) {
      OnlineDeviceModel.instance.setDeviceList(_deviceMap.values.toList());
    }
  }

  static void startBeat() async {
    _myIP=await NetworkUtils.getWifiIP();
    // final broadcastAddress = await NetworkUtils.getBroadcastAddress();
    // iLog("启动心跳,ip地址=$_myIP,广播地址=$broadcastAddress");
    // if (broadcastAddress == null) return;
    iLog("启动心跳,ip地址=$_myIP,组播地址=$_MULTICAST_GROUP");

    _beatTimer?.cancel();
    _beatSocket?.close();

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    // socket.broadcastEnabled = true;
    _beatSocket = socket;

    void sendBeat() async{
      updateList();
      _isChange=false;
      final now=DateTime.now();
      dLog("自心跳-${_myIP}-${now.toLocal()}");
      final b=CmdBeatBean(name: InitManager.deviceName??_myIP,type: RawMessageType.beat.code,timestampUtc: now.toUtc().millisecondsSinceEpoch,deviceId: InitManager.deviceId);
      final payload = jsonEncode(b.toJson());
      // socket.send(
      //   utf8.encode(payload),
      //   InternetAddress(broadcastAddress),
      //   _LISTENER_PORT,
      // );
      socket.send(
        utf8.encode(payload),
        InternetAddress(_MULTICAST_GROUP),
        _LISTENER_PORT,
      );
    }

    sendBeat();
    _beatTimer = Timer.periodic(const Duration(milliseconds: _HEART_INTERVAL), (_) => sendBeat());
  }

  static void stopBeat() {
    _beatTimer?.cancel();
    _beatTimer = null;
    _beatSocket?.close();
    _beatSocket = null;
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
    final onlineDevice=_deviceMap[deviceId];
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
