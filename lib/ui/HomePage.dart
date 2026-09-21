import 'package:flutter/material.dart';
import 'package:yf_code/l10n/l10n.dart';
import 'package:yf_code/theme/AppColors.dart';
import 'package:yf_code/ui/ConversationPage.dart';
import 'package:yf_code/ui/MePage.dart';
import 'package:yf_code/ui/OnlineDevicePage.dart';
import 'package:yf_code/ui/widgets/AppChrome.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentIndex != 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  _currentIndex == 0 ? l10n.tabChats : l10n.lanDevices,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: const [
                  ConversationPage(),
                  OnlineDevicePage(),
                  MePage(),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: Row(
                children: [
                  AppTabButton(
                    label: l10n.tabChats,
                    icon: Icons.chat_bubble_outline_rounded,
                    active: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  AppTabButton(
                    label: l10n.tabDevices,
                    icon: Icons.radar,
                    active: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  AppTabButton(
                    label: l10n.tabMe,
                    icon: Icons.person_outline_rounded,
                    active: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
