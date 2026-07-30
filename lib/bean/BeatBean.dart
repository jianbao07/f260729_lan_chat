/// name : "yf"
/// type : "beat"
/// timestamp_utc : 1785173158277
/// device_id : "xxx"

class BeatBean {
  BeatBean({
    this.name,
    this.type,
    this.timestampUtc,
    this.deviceId,
  });

  BeatBean.fromJson(dynamic json) {
    name = json['name'];
    type = json['type'];
    timestampUtc = json['timestamp_utc'];
    deviceId = json['device_id'];
  }

  String? name;
  String? type;
  num? timestampUtc;
  String? deviceId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['type'] = type;
    map['timestamp_utc'] = timestampUtc;
    map['device_id'] = deviceId;
    return map;
  }
}
