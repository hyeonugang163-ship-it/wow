import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/app_env.dart';
import 'package:voyage/auth/auth_state_notifier.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  String? _fcmToken;
  bool _loadingToken = false;

  @override
  void initState() {
    super.initState();
    _loadFcmToken();
  }

  Future<void> _loadFcmToken() async {
    setState(() {
      _loadingToken = true;
    });
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (!mounted) return;
      setState(() {
        _fcmToken = token ?? '(null)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fcmToken = '(error)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingToken = false;
        });
      }
    }
  }

  String _formatFcmToken(String? raw) {
    const fallbackNone = '(none)';
    if (raw == null || raw.isEmpty) {
      return fallbackNone;
    }
    // 에러/널 표시용 토큰은 그대로 노출한다.
    if (raw.startsWith('(') && raw.endsWith(')')) {
      return raw;
    }
    if (raw.length <= 40) {
      return raw;
    }
    final String start = raw.substring(0, 16);
    final String end = raw.substring(raw.length - 8);
    return '$start...$end';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateNotifierProvider);
    final mode = ref.watch(pttModeProvider);
    final env = AppEnv.current;
    final envName = AppEnv.currentName;

    final firebaseApp = Firebase.apps.isNotEmpty
        ? Firebase.app()
        : null;
    final options = firebaseApp?.options;

    final uid = auth.user?.id ?? '(none)';
    final firebaseProjectId =
        options?.projectId ?? '(unknown)';
    final storageBucket =
        options?.storageBucket ?? '(unknown)';

    final isProd = env == AppEnvironment.prod;

    const appName = 'MJTalk';
    const packageName = 'com.example.voyage';
    const appVersion = '1.0.0+1';
    final buildMode = kReleaseMode ? 'release' : 'debug';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('App'),
            subtitle: Text(appName),
          ),
          ListTile(
            title: const Text('Package'),
            subtitle: const Text(packageName),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text(appVersion),
          ),
          ListTile(
            title: const Text('Build mode'),
            subtitle: Text(buildMode),
          ),
          ListTile(
            title: const Text('APP_ENV'),
            subtitle: Text(envName),
          ),
          ListTile(
            title: const Text('Auth user id'),
            subtitle: Text(uid),
          ),
          ListTile(
            title: const Text('PTT mode'),
            subtitle: Text(mode.name),
          ),
          ListTile(
            title: const Text('Firebase project'),
            subtitle: Text(firebaseProjectId),
          ),
          ListTile(
            title: const Text('Storage bucket'),
            subtitle: Text(storageBucket),
          ),
          ListTile(
            title: const Text('FCM token'),
            subtitle: Text(
              _loadingToken
                  ? '불러오는 중...'
                  : _formatFcmToken(_fcmToken),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('PTT 모드 전환'),
            subtitle: const Text(
              '테스트를 위해 walkie / manner를 빠르게 변경합니다.',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(pttModeProvider.notifier)
                        .setMode(PttMode.manner);
                  },
                  child: const Text('Manner'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(pttModeProvider.notifier)
                        .setMode(PttMode.walkie);
                  },
                  child: const Text('Walkie'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isProd
                ? null
                : () {
                    context.push('/debug/logs');
                  },
            child: const Text('디버그 로그 화면 열기'),
          ),
          const SizedBox(height: 24),
          if (isProd)
            const Text(
              '주의: prod 환경에서는 이 화면을 일반 사용자에게 '
              '노출하지 않는 것을 권장합니다.',
              style: TextStyle(color: Colors.redAccent),
            ),
        ],
      ),
    );
  }
}
