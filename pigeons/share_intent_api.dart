import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pigeon/share_intent_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/yf/f260729_lan_chat/pigeon/ShareIntentApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.yf.f260729_lan_chat.pigeon',
      includeErrorClass: false,
    ),
    dartPackageName: 'yf_code',
  ),
)
class SharedFileItem {
  String? path;
  String? name;
  String? mimeType;
}

class SharedPayload {
  String? text;
  List<SharedFileItem>? files;
}

@HostApi()
abstract class ShareIntentHostApi {
  SharedPayload? takePendingShare();
}

@FlutterApi()
abstract class ShareIntentFlutterApi {
  void onShareReceived(SharedPayload payload);
}
