
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {

  static Future<String?> getWifiIP() async{
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    return ip;
  }

  /// 获取当前局域网广播地址。
  /// 已连接局域网时根据 IP 与子网掩码计算；未连接则返回 null。
  static Future<String?> getBroadcastAddress() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    final subnet = await info.getWifiSubmask();
    if (ip == null ||
        subnet == null ||
        ip.isEmpty ||
        subnet.isEmpty ||
        !_isLanIpv4(ip)) {
      return null;
    }
    return _calculateBroadcast(ip, subnet);
  }

  /// 判断是否为常见局域网私有 IPv4（排除回环、链路本地等）
  static bool _isLanIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }
    // 10.0.0.0/8
    if (octets[0] == 10) return true;
    // 172.16.0.0/12
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
    // 192.168.0.0/16
    if (octets[0] == 192 && octets[1] == 168) return true;
    return false;
  }

  /// broadcast = ip | (~subnet)
  static String? _calculateBroadcast(String ip, String subnet) {
    final ipParts = ip.split('.');
    final maskParts = subnet.split('.');
    if (ipParts.length != 4 || maskParts.length != 4) return null;
    try {
      final result = <String>[];
      for (var i = 0; i < 4; i++) {
        final ipOctet = int.parse(ipParts[i]);
        final maskOctet = int.parse(maskParts[i]);
        if (ipOctet < 0 ||
            ipOctet > 255 ||
            maskOctet < 0 ||
            maskOctet > 255) {
          return null;
        }
        result.add((ipOctet | (~maskOctet & 0xff)).toString());
      }
      return result.join('.');
    } catch (_) {
      return null;
    }
  }
}