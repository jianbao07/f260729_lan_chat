import 'package:flutter/material.dart';
import 'package:yf_code/InitManager.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/HomePage.dart';
import 'package:yf_code/utils/log.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {

  @override
  void initState() {
    super.initState();
    _gotoHome();
  }

  Future<void> _gotoHome() async {
    iLog("xxxx");
    final started = DateTime.now();
    try {
      await InitManager.initApp();
    } catch (_) {}
    if (mounted) setState(() {});
    final left = Duration(milliseconds: 1000) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future.delayed(left);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondary) => const HomePage(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondary, child) {
          return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final version = InitManager.version;
    final versionLabel = (version.isEmpty || version == '—') ? '' : 'v$version';
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 5),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/app_icon.png', width: 88, height: 88, filterQuality: FilterQuality.high),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.appName,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.appTagline, style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
                ],
              ),
            ),
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                  ),
                  if (versionLabel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(versionLabel, style: TextStyle(fontSize: 12, color: c.textTertiary, fontFamily: kMonoFont)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
