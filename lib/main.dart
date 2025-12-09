import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/app_router.dart';
import 'package:voyage/debug/ptt_log_buffer.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_lifecycle.dart';
import 'package:voyage/ptt_push_handler.dart';
import 'package:voyage/ptt_ui_event.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS A안(APNs → 탭 → 포그라운드 → 재생) PTT Push 핸들러 초기화.
  PttPushHandler.init();
  runApp(const ProviderScope(child: VoyageApp()));
}

class VoyageApp extends ConsumerStatefulWidget {
  const VoyageApp({super.key});

  @override
  ConsumerState<VoyageApp> createState() => _VoyageAppState();
}

class _VoyageAppState extends ConsumerState<VoyageApp> {
  PttLifecycleObserver? _pttLifecycleObserver;

  @override
  void initState() {
    super.initState();
    final observer = PttLifecycleObserver(ref);
    _pttLifecycleObserver = observer;
    final binding = WidgetsBinding.instance;
    binding.addObserver(observer);
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
    final debugLogNotifier = ref.read(pttDebugLogProvider.notifier);
    final logBufferNotifier =
        ref.read(pttLogBufferProvider.notifier);
    PttLogger.attachSink((entry) {
      debugLogNotifier.add(entry);
      logBufferNotifier.addFromDebugEntry(entry);
    });

    final uiEventNotifier = ref.read(pttUiEventProvider.notifier);
    PttUiEventBus.attach(uiEventNotifier.emit);

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
