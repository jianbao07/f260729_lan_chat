import 'package:flutter/foundation.dart';
import 'package:yf_code/bean/DeviceBean.dart';

class OnlineDeviceModel with ChangeNotifier {
  OnlineDeviceModel._();
  static final OnlineDeviceModel instance = OnlineDeviceModel._();

  List<DeviceBean> _deviceList = [];

  List<DeviceBean> get deviceList => List.unmodifiable(_deviceList);

  int get onlineCount => _deviceList.length;

  void setDeviceList(List<DeviceBean> list) {
    _deviceList = List.from(list);
    notifyListeners();
  }

  void clear() {
    _deviceList.clear();
    notifyListeners();
  }
}

