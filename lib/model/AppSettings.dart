import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  String theme = 'system';
  String localeMode = 'system';
  String nickname = '';
  bool notifOn = true;
  bool discoverable = true;
  bool encryptOn = false;
  Map<String, String> remarks = {};

  ThemeMode get themeMode {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  bool get isDark {
    switch (theme) {
      case 'light':
        return false;
      case 'dark':
        return true;
      default:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }

  Locale? get materialLocale {
    switch (localeMode) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }

  String displayNameOf(String? deviceId, String fallback) {
    if (deviceId == null || deviceId.isEmpty) return fallback;
    final remark = remarks[deviceId];
    if (remark != null && remark.isNotEmpty) return remark;
    return fallback;
  }

  String remarkOf(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return '';
    return remarks[deviceId] ?? '';
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final savedTheme = json['theme'] as String?;
      theme = (savedTheme == 'light' || savedTheme == 'dark' || savedTheme == 'system') ? savedTheme! : 'system';
      final savedLocale = json['localeMode'] as String?;
      localeMode = (savedLocale == 'zh' || savedLocale == 'en' || savedLocale == 'system') ? savedLocale! : 'system';
      nickname = (json['nickname'] as String?) ?? '';
      notifOn = json['notifOn'] != false;
      discoverable = json['discoverable'] != false;
      encryptOn = json['encryptOn'] == true;
      final raw = json['remarks'];
      if (raw is Map) {
        remarks = raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      notifyListeners();
    } catch (_) {
      /* keep defaults */
    }
  }

  Future<void> setTheme(String value) async {
    theme = (value == 'light' || value == 'dark') ? value : 'system';
    notifyListeners();
    await _save();
  }

  Future<void> setLocaleMode(String value) async {
    localeMode = (value == 'zh' || value == 'en') ? value : 'system';
    notifyListeners();
    await _save();
  }

  Future<void> setNickname(String value) async {
    nickname = value.trim();
    notifyListeners();
    await _save();
  }

  Future<void> setNotifOn(bool value) async {
    notifOn = value;
    notifyListeners();
    await _save();
  }

  Future<void> setDiscoverable(bool value) async {
    discoverable = value;
    notifyListeners();
    await _save();
  }

  Future<void> setEncryptOn(bool value) async {
    encryptOn = value;
    notifyListeners();
    await _save();
  }

  Future<void> setRemark(String deviceId, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      remarks.remove(deviceId);
    } else {
      remarks[deviceId] = trimmed;
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({
        'theme': theme,
        'localeMode': localeMode,
        'nickname': nickname,
        'notifOn': notifOn,
        'discoverable': discoverable,
        'encryptOn': encryptOn,
        'remarks': remarks,
      }));
    } catch (_) {
      /* ignore persist failure */
    }
  }

  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}settings.json');
  }
}
