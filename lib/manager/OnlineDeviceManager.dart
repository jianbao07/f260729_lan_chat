import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yf_code/enum/RawMessageType.dart';
import 'package:yf_code/bean/CmdBeatBean.dart';
import 'package:yf_code/bean/DeviceBean.dart';
import 'package:yf_code/model/DeviceModel.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/utils/MulticastLock.dart';
import 'package:yf_code/utils/NetworkUtils.dart';
import 'package:yf_code/utils/log.dart';

class OnlineDeviceManager {
  OnlineDeviceManager._();
  static const int _LISTENER_PORT = 54832;

  static Timer? _beatTimer;
  static RawDatagramSocket? _beatSocket;
  static RawDatagramSocket? _listenerSocket;
  static String? _myIP;
  static Map<String,DeviceBean> _deviceList={};

  static void onBeat(CmdBeatBean b,String ip,int port){
    final key=b.deviceId??ip;
    final d=_deviceList[key];
    if(d==null){
      _deviceList[key]=DeviceBean(
        name: b.name,
        ipAddress: ip,
        port: port,
        updateTimestampUtc: b.timestampUtc,
        deviceId: b.deviceId,
      );
    }else{
      _deviceList[key]=d.copyWith(
        name: b.name,
        ipAddress: ip,
        port: port,
        updateTimestampUtc: b.timestampUtc,
        deviceId: b.deviceId,
      );
    }
    updateList();
  }

  static void updateList(){
    DeviceModel.instance.setDeviceList(_deviceList.values.toList());
  }

  static void startBeat() async {
    _myIP=await NetworkUtils.getWifiIP();
    final broadcastAddress = await NetworkUtils.getBroadcastAddress();
    iLog("启动心跳,ip地址=$_myIP,广播地址=$broadcastAddress");
    if (broadcastAddress == null) return;

    _beatTimer?.cancel();
    _beatSocket?.close();

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _beatSocket = socket;

    void sendBeat() async{
      final now=DateTime.now();
      dLog("自心跳-${_myIP}-${now.toLocal()}");
      final b=CmdBeatBean(name: InitManager.deviceName??_myIP,type: RawMessageType.beat.code,timestampUtc: now.toUtc().millisecondsSinceEpoch,deviceId: InitManager.deviceId);
      final payload = jsonEncode(b.toJson());
      socket.send(
        utf8.encode(payload),
        InternetAddress(broadcastAddress),
        _LISTENER_PORT,
      );
    }

    sendBeat();
    _beatTimer = Timer.periodic(const Duration(seconds: 5), (_) => sendBeat());
  }

  static void listenerBeat() async {
    _listenerSocket?.close();

    final locked = await MulticastLock.acquire();
    if (!locked) {
      iLog("MulticastLock 获取失败，UDP广播可能无法接收");
    }

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _LISTENER_PORT,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    _listenerSocket = socket;
    iLog("开始监听心跳端口=$_LISTENER_PORT");

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
        onBeat(b,ip,port);
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
}
