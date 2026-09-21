
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';

PageRoute<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondary) => page,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

void startPageReplace(BuildContext context, Widget page) {
  Navigator.pushReplacement(context, _slideRoute(page));
}

Future<T?> startPage<T extends Object?>(BuildContext context, Widget page) {
  return Navigator.push(context, _slideRoute<T>(page));
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

enum ProtocolEnum {
  pp('pp'),
  ua('ua');

  final String code;
  const ProtocolEnum(this.code);
}

void gotoProtocolText(ProtocolEnum type, BuildContext context) {
  final packName = InitManager.packageName.isEmpty ? 'com.ljb.lanchat' : InitManager.packageName;
  final uri = Uri.https('jianbao07.github.io', '/Privacy-Policy-and-User-Agreement/index.html', {
    'content_type': type.code,
    'language': Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'zh',
    'pack_name': packName,
  });
  gotoH5(uri.toString(), context: context);
}

Future<void> gotoH5(String url, {bool inApp = false, required BuildContext context}) async {
  final uri = Uri.parse(url);
  final mode = inApp ? LaunchMode.inAppWebView : LaunchMode.externalApplication;
  try {
    final ok = await launchUrl(uri, mode: mode);
    if (!ok && context.mounted) showAppToast(context, context.l10n.cannotOpenPage);
  } catch (_) {
    if (context.mounted) showAppToast(context, context.l10n.cannotOpenPage);
  }
}