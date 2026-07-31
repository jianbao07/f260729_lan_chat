import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pigeon/multicast_lock_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/yf/f260729_lan_chat/pigeon/MulticastLockApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.yf.f260729_lan_chat.pigeon'),
    dartPackageName: 'yf_code',
  ),
)
@HostApi()
abstract class MulticastLockApi {
  bool acquire();

  void release();

  bool isHeld();
}
