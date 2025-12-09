import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/auth/auth_state_notifier.dart';
import 'package:voyage/chat_list_page.dart';
import 'package:voyage/chat_page.dart';
import 'package:voyage/debug/debug_logs_page.dart';
import 'package:voyage/friends_page.dart';
import 'package:voyage/onboarding/profile_onboarding_page.dart';
import 'package:voyage/ptt_home_page.dart';
import 'package:voyage/settings_page.dart';

GoRouter? _globalRouter;

GoRouter? tryGetAppRouter() => _globalRouter;

GoRouter get appRouter => _globalRouter!;

final appRouterProvider = Provider<GoRouter>(
  (ref) {
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(
        ref.read(authStateNotifierProvider.notifier).stream,
      ),
      redirect: (context, state) {
        final auth = ref.read(authStateNotifierProvider);

        final bool isOnboardingRoute =
            state.matchedLocation.startsWith('/onboarding');

        if (auth.status == AuthStatus.unknown) {
          return null;
        }

        if (auth.status == AuthStatus.onboarding ||
            auth.status == AuthStatus.signedOut) {
          if (!isOnboardingRoute) {
            return '/onboarding/profile';
          }
          return null;
        }

        if (auth.status == AuthStatus.signedIn && isOnboardingRoute) {
          return '/';
        }

        return null;
      },
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
        GoRoute(
          path: '/debug/logs',
          name: 'debug_logs',
          builder: (context, state) => const DebugLogsPage(),
        ),
        GoRoute(
          path: '/onboarding/profile',
          name: 'onboarding_profile',
          builder: (context, state) =>
              const ProfileOnboardingPage(),
        ),
      ],
    );
    _globalRouter = router;
    return router;
  },
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListener = notifyListeners;
    _subscription = stream.asBroadcastStream().listen(
      (_) {
        notifyListener();
      },
    );
  }

  late final VoidCallback notifyListener;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
