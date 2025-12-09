import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_list_page.dart';
import 'package:voyage/friends_page.dart';
import 'package:voyage/settings_page.dart';

/// Bottom navigation 기반 홈 탭 구조.
///
/// - 탭1: 채팅 목록
/// - 탭2: 친구 목록
/// - 탭3: 설정
class HomeTabsPage extends ConsumerStatefulWidget {
  const HomeTabsPage({super.key});

  @override
  ConsumerState<HomeTabsPage> createState() => _HomeTabsPageState();
}

class _HomeTabsPageState extends ConsumerState<HomeTabsPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ChatListPage(),
          FriendsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: '친구',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

