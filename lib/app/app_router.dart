import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/app/app_env.dart';
import 'package:voyage/features/auth/application/auth_state.dart';
import 'package:voyage/features/auth/application/auth_state_notifier.dart';
import 'package:voyage/features/chat/presentation/chat_list_page.dart';
import 'package:voyage/features/chat/presentation/chat_page.dart';
import 'package:voyage/features/debug/presentation/debug_logs_page.dart';
import 'package:voyage/features/debug/presentation/debug_screen.dart';
import 'package:voyage/features/friends/presentation/friends_page.dart';
import 'package:voyage/app/home_tabs_page.dart';
import 'package:voyage/features/onboarding/presentation/profile_onboarding_page.dart';
import 'package:voyage/features/ptt/presentation/ptt_home_page.dart';
import 'package:voyage/features/settings/presentation/pre_alpha_info_page.dart';
import 'package:voyage/features/settings/presentation/settings_page.dart';

GoRouter? _globalRouter;

GoRouter? tryGetAppRouter() => _globalRouter;

GoRouter get appRouter => _globalRouter!;

final appRouterProvider = Provider<GoRouter>(
  (ref) {
    final List<RouteBase> routes = <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeTabsPage(),
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
          final extra = state.extra;
          PttChatRouteArgs? args;
          if (extra is PttChatRouteArgs) {
            args = extra;
          }
          return ChatPage(
            chatId: id,
            pttArgs: args,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/ptt',
        name: 'ptt_home',
        builder: (context, state) => const PttHomePage(),
      ),
      GoRoute(
        path: '/pre-alpha-info',
        name: 'pre_alpha_info',
        builder: (context, state) => const PreAlphaInfoPage(),
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
    ];

    // DebugScreen은 prod 환경이 아닐 때만 라우트로 추가한다.
    if (AppEnv.current != AppEnvironment.prod) {
      routes.add(
        GoRoute(
          path: '/debug',
          name: 'debug_screen',
          builder: (context, state) =>
              const DebugScreen(),
        ),
      );
    }

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
      routes: routes,
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
