import 'package:flutter/material.dart';

import '../features/ai/ai_chat_page.dart';
import '../features/favorite/favorite_page.dart';
import '../features/home/home_page.dart';
import '../features/my/my_page.dart';
import '../features/nearby/nearby_page.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({Key? key}) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    NearbyPage(),
    AiChatPage(),
    FavoritePage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Image(
              image: AssetImage('assets/icon_menu_home_inactive.png'),
              width: 24,
              height: 24,
            ),
            activeIcon: Image(
              image: AssetImage('assets/icon_menu_home_active.png'),
              width: 24,
              height: 24,
            ),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Image(
              image: AssetImage('assets/icon_menu_map_inactive.png'),
              width: 24,
              height: 24,
            ),
            activeIcon: Image(
              image: AssetImage('assets/icon_menu_map_active.png'),
              width: 24,
              height: 24,
            ),
            label: '내주변',
          ),
          BottomNavigationBarItem(
            icon: Image(
              image: AssetImage('assets/icon_menu_ai_inactive.png'),
              width: 24,
              height: 24,
            ),
            activeIcon: Image(
              image: AssetImage('assets/icon_menu_ai_active.png'),
              width: 24,
              height: 24,
            ),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Image(
              image: AssetImage('assets/icon_menu_favorites_inactive.png'),
              width: 24,
              height: 24,
            ),
            activeIcon: Image(
              image: AssetImage('assets/icon_menu_favorites_active.png'),
              width: 24,
              height: 24,
            ),
            label: '찜',
          ),
          BottomNavigationBarItem(
            icon: Image(
              image: AssetImage('assets/icon_menu_my_inactive.png'),
              width: 24,
              height: 24,
            ),
            activeIcon: Image(
              image: AssetImage('assets/icon_menu_my_active.png'),
              width: 24,
              height: 24,
            ),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
