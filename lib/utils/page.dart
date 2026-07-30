
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void startPageReplace(BuildContext context,Widget page){
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>page));
}

Future<T?> startPage<T extends Object?>(BuildContext context,Widget page){
  return Navigator.push(context, MaterialPageRoute(builder: (context)=>page));
}

void gotoBack<T extends Object?>(BuildContext context, [T? result]){
  Navigator.pop(context,result);
}

void exitApp(){
  if(Platform.isAndroid){
    SystemNavigator.pop();
  }else{
    exit(0);
  }
}

// enum ProtocolEnum{
//   pp("pp"),ua("ua"),sdk("sdk"),collectInfo("collectInfo"),pay_protocol("pay_protocol"),permissions("permissions");
//
//   final String code;
//   const ProtocolEnum(this.code);
// }
//
// void gotoProtocolText(ProtocolEnum type, BuildContext context) {
//   var platform;
//   if (Platform.isAndroid) {
//     platform = "android";
//   } else if (Platform.isIOS) {
//     platform = "ios";
//   } else {
//     platform = Platform.operatingSystem;
//   }
//   var url = "https://test.aisou.club/privacy_policy/aaa_flutter/main_entrance.html?platform=$platform&content_type=${type.code.toString()}" +
//       "&language=${BaseConstant.languageCode}${BaseConstant.scriptCode != null ? "&scriptCode=${BaseConstant.scriptCode}" : ""}" +
//       "&pack_name=${BaseConstant.packageName}&channel=${BaseConstant.channel}&email=${BaseConstant.email}" +
//       "&app_name=${BaseConstant.appName}&companyName=${BaseConstant.companyName}";
//
//   gotoH5(url, inApp: true, context: context);
// }
//
// Future<void> gotoH5(String url, {bool inApp = false, required BuildContext context}) async {
//   iLog("前往地址:${url}");
//   final Uri uri = Uri.parse(url);
//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri);
//   } else {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => WebViewPage(initialUrl: url),
//       ),
//     );
//   }
// }