import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yf_code/model/AppSettings.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/ui/SplashPage.dart';
import 'package:yf_code/manager/FileTransferManager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FileTransferManager.navigatorKey = appNavigatorKey;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppSettings.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final dark = settings.isDark;
    final colors = dark ? AppColors.dark : AppColors.light;
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: colors.surface),
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        onGenerateTitle: (context) => context.l10n.appName,
        debugShowCheckedModeBanner: false,
        theme: AppColors.theme(AppColors.light, Brightness.light),
        darkTheme: AppColors.theme(AppColors.dark, Brightness.dark),
        themeMode: settings.themeMode,
        locale: settings.materialLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SplashPage(),
      ),
    );
  }
}
