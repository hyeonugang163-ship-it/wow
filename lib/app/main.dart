import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voyage/app/app_env.dart';
import 'package:voyage/app/app_router.dart';
import 'package:voyage/core/app_provider_observer.dart';
import 'package:voyage/core/theme/app_theme.dart';
import 'package:voyage/services/backend/policy_config_api.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/services/notifications/fcm_push_handler.dart';
import 'package:voyage/services/notifications/local_notification_service.dart';
import 'package:voyage/features/ptt/data/ptt_prefs.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';
import 'package:voyage/features/ptt/application/ptt_lifecycle.dart';
import 'package:voyage/features/ptt/application/ptt_push_handler.dart';
import 'package:voyage/features/ptt/application/ptt_ui_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();
  try {
    await Firebase.initializeApp();
    final envName = AppEnv.currentName;
    debugPrint('[Firebase] initialized for env: $envName');
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      try {
        final credential = await auth.signInAnonymously();
        final uid = credential.user?.uid;
        debugPrint(
          '[Firebase Auth] signed in anonymously {uid: $uid}',
        );
      } catch (e, st) {
        debugPrint('[Firebase Auth] signIn error: $e');
        debugPrint(st.toString());
      }
    } else {
      debugPrint(
        '[Firebase Auth] already signed in {uid: ${currentUser.uid}}',
      );
    }
  } catch (e, st) {
    debugPrint('[Firebase] initialization error: $e');
    debugPrint(st.toString());
  }
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  FF.initForEnv();
  await _maybeFetchRemotePolicyConfig();
  PttPushHandler.init();
  await LocalNotificationService.initialize();
  await FcmPushHandler.init();
  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPrefsProvider.overrideWithValue(sharedPrefs),
      ],
      observers: const <ProviderObserver>[
        AppProviderObserver(),
      ],
      child: const VoyageApp(),
    ),
  );
}

Future<void> _maybeFetchRemotePolicyConfig() async {
  const String enabledRaw = String.fromEnvironment(
    'ENABLE_REMOTE_POLICY',
    defaultValue: 'false',
  );
  if (enabledRaw.toLowerCase() != 'true') {
    return;
  }

  try {
    final api = PolicyConfigApi();
    final result = await api.fetchPolicy(AppEnv.current);
    final error = result.error;
    if (error != null) {
      debugPrint(
        '[PolicyConfig] fetch error: '
        'type=${error.type.name} code=${error.code ?? 'null'} '
        'status=${error.statusCode?.toString() ?? 'null'}',
      );
      return;
    }
    final config = result.data;
    if (config == null) {
      debugPrint('[PolicyConfig] empty config from backend');
      return;
    }
    FF.applyPolicy(config);
    debugPrint(
      '[PolicyConfig] applied remote policy for env=${AppEnv.currentName}',
    );
  } catch (e, st) {
    debugPrint(
      '[PolicyConfig] unexpected error: $e',
    );
    debugPrint(st.toString());
  }
}

class VoyageApp extends ConsumerStatefulWidget {
  const VoyageApp({super.key});

  @override
  ConsumerState<VoyageApp> createState() => _VoyageAppState();
}

class _VoyageAppState extends ConsumerState<VoyageApp> {
  PttLifecycleObserver? _pttLifecycleObserver;
  bool _loggerAttached = false;

  @override
  void initState() {
    super.initState();
    final observer = PttLifecycleObserver(ref);
    _pttLifecycleObserver = observer;
    final binding = WidgetsBinding.instance;
    binding.addObserver(observer);

    // NOTE: 로그/이벤트 버스 연결은 build()가 아니라
    // initState()에서 한 번만 설정해,
    // 빌드 중 provider state가 수정되는 일을 피한다.
    _attachLoggersOnce();
  }

  void _attachLoggersOnce() {
    if (_loggerAttached) {
      return;
    }
    _loggerAttached = true;

    // PttLogger의 sink를 v2 디버그 로그 버퍼에 연결한다.
    // sink는 순수 Dart 버퍼에만 쓰기(write)하며,
    // 어떤 provider state도 변경하지 않는다.
    PttLogger.attachSink(pttDebugLogBufferV2.add);

    final uiEventNotifier = ref.read(pttUiEventProvider.notifier);
    PttUiEventBus.attach(uiEventNotifier.emit);

    final env = AppEnv.current;
    // 앱 시작 시점 로그는 콘솔에만 남긴다.
    PttLogger.logConsoleOnly(
      '[App]',
      'starting',
      meta: <String, Object?>{
        'env': env.name,
      },
    );
  }

  @override
  void dispose() {
    final binding = WidgetsBinding.instance;
    final observer = _pttLifecycleObserver;
    if (observer != null) {
      binding.removeObserver(observer);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MJTalk',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
