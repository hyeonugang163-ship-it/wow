import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/app_env.dart';
import 'package:voyage/app_router.dart';
import 'package:voyage/core/app_provider_observer.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_lifecycle.dart';
import 'package:voyage/ptt_push_handler.dart';
import 'package:voyage/ptt_ui_event.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // env별 기본 PolicyConfig 초기화.
  FF.initForEnv();
  // iOS A안(APNs → 탭 → 포그라운드 → 재생) PTT Push 핸들러 초기화.
  PttPushHandler.init();
  runApp(
    ProviderScope(
      observers: const <ProviderObserver>[
        AppProviderObserver(),
      ],
      child: const VoyageApp(),
    ),
  );
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
