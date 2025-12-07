import 'package:go_router/go_router.dart';
import 'package:voyage/chat_list_page.dart';
import 'package:voyage/chat_page.dart';
import 'package:voyage/friends_page.dart';
import 'package:voyage/ptt_home_page.dart';
import 'package:voyage/settings_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const PttHomePage(),
    ),
    GoRoute(
      path: '/friends',
      name: 'friends',
      builder: (context, state) => const FriendsPage(),
    ),
    GoRoute(
      path: '/chats',
      name: 'chats',
      builder: (context, state) => const ChatListPage(),
    ),
    GoRoute(
      path: '/chat/:id',
      name: 'chat',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'unknown';
        return ChatPage(chatId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
