/// name : "yf"
/// ip_address : "192.168.1.4"
/// update_timestamp_utc : 1785173158277
/// device_id : "xxx"

class DeviceBean {
  DeviceBean({
    this.name,
    this.ipAddress,
    this.updateTimestampUtc,
    this.deviceId,
  });

  DeviceBean.fromJson(dynamic json) {
    name = json['name'];
    ipAddress = json['ip_address'];
    updateTimestampUtc = json['update_timestamp_utc'];
    deviceId = json['device_id'];
  }

  String? name;
  String? ipAddress;
  num? updateTimestampUtc;
  String? deviceId;

  DeviceBean copyWith({
    String? name,
    String? ipAddress,
    num? updateTimestampUtc,
    String? deviceId,
  }) =>
      DeviceBean(
        name: name ?? this.name,
        ipAddress: ipAddress ?? this.ipAddress,
        updateTimestampUtc: updateTimestampUtc ?? this.updateTimestampUtc,
        deviceId: deviceId ?? this.deviceId,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['ip_address'] = ipAddress;
    map['update_timestamp_utc'] = updateTimestampUtc;
    map['device_id'] = deviceId;
    return map;
  }
}
