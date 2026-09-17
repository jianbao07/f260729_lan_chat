//
// import 'package:shared_preferences/shared_preferences.dart';
//
// class SPHelper {
//   static final SPHelper _instance = SPHelper._();
//   SPHelper._();
//   static SPHelper get instance => _instance;
//   static SharedPreferences? _prefsInstance;
//
//   Future<void> init() async{
//     _prefsInstance = await SharedPreferences.getInstance();
//   }
//
//   Future<bool> putString(String key, String value) async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.setString(key, value)??false;
//   }
//
//   String? getString(String key,[String? def]) {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.getString(key)??def;
//   }
//
//   Future<bool> putInt(String key, int value) async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.setInt(key, value)??false;
//   }
//
//   int getInt(String key,[int def=0]) {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.getInt(key)??def;
//   }
//
//   Future<bool> putBool(String key, bool value) async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.setBool(key, value)??false;
//   }
//
//   bool getBool(String key,[bool def=false]) {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.getBool(key)??def;
//   }
//
//   Future<bool> putDouble(String key, double value) async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.setDouble(key, value)??false;
//   }
//
//   double getDouble(String key,[double def=0]) {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.getDouble(key)??def;
//   }
//
//   Future<bool> remove(String key) async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.remove(key)??false;
//   }
//
//   Future<bool> clear() async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.clear()??false;
//   }
//
//   bool isAgreement(){
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.getBool("app_agreement")??false;
//   }
//
//   Future<bool> agreement() async {
//     if(_prefsInstance==null){
//       throw "SPHelper 未初始化";
//     }
//     return _prefsInstance?.setBool("app_agreement", true)??false;
//   }
//
//   /// 与 Android `SplashActivity` 的 `first_k` 一致：未进入引导前为 true，进入引导后置 false。
//   static const String splashFirstLaunchKey = 'first_k';
//
//   bool isSplashFirstLaunch() {
//     return getBool(splashFirstLaunchKey, true);
//   }
//
//   Future<void> markSplashGuideOpened() async {
//     await putBool(splashFirstLaunchKey, false);
//   }
//
//   Set<String>? getKeys(){
//     return _prefsInstance?.getKeys();
//   }
// }