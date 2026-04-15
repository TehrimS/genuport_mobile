import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genuport/themes/gp_colors.dart';
import '../screens/home_page.dart';
import '../screens/downloads_page.dart';
import '../screens/profile_page.dart';

class BottomNav extends StatefulWidget {
  final int initialIndex;
  const BottomNav({this.initialIndex = 0, super.key});

  @override
  State<BottomNav> createState() => BottomNavState();
}

class BottomNavState extends State<BottomNav> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void goToTab(int index) => setState(() => _currentIndex = index);

  // Pages kept alive with IndexedStack
  final _pages = [
    HomePage(),
    DownloadsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surfacePage,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: const BoxDecoration(
        color: GPColors.surface,
        border: Border(top: BorderSide(color: GPColors.border, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _item(0, Icons.home_rounded,    Icons.home_outlined,          'Home'),
            _item(1, Icons.folder_rounded,  Icons.folder_outlined,        'Downloads'),
            _item(2, Icons.person_rounded,  Icons.person_outline_rounded, 'Profile'),
          ]),
        ),
      ),
    );
  }

  Widget _item(int idx, IconData activeIcon, IconData inactiveIcon, String label) {
    final active = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => goToTab(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: active ? GPColors.primaryLight.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                active ? activeIcon : inactiveIcon,
                size: 22,
                color: active ? GPColors.primary : GPColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? GPColors.primary : GPColors.textMuted,
              )),
          ],
        ),
      ),
    );
  }
}