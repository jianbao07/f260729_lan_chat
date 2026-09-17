/// name : "yf"
/// type : "beat"
/// timestamp_utc : 1785173158277
/// device_id : "xxx"
/// public_key : "hex"

class CmdBeatBean {
  CmdBeatBean({
    this.name,
    this.type,
    this.timestampUtc,
    this.deviceId,
    this.publicKey,
  });

  CmdBeatBean.fromJson(dynamic json) {
    name = json['name'];
    type = json['type'];
    timestampUtc = json['timestamp_utc'];
    deviceId = json['device_id'];
    publicKey = json['public_key'];
  }

  String? name;
  String? type;
  num? timestampUtc;
  String? deviceId;
  String? publicKey;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['type'] = type;
    map['timestamp_utc'] = timestampUtc;
    map['device_id'] = deviceId;
    map['public_key'] = publicKey;
    return map;
  }
}
