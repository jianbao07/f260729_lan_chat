import 'package:flutter/material.dart';
import 'package:yf_code/ui/HomePage.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/manager/FileTransferManager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FileTransferManager.navigatorKey = appNavigatorKey;
  InitManager.initApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'LAN Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E6E68),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFE4F0ED),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomePage(),
    );
  }
}
