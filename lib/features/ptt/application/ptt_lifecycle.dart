import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/features/ptt/application/ptt_controller.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

class PttLifecycleController {
  const PttLifecycleController(this._ref);

  final Ref _ref;

  Future<void> onAppLifecycleChanged(AppLifecycleState state) async {
    final String stateName = state.name;
    PttLogger.log(
      '[PTT][Lifecycle]',
      'app lifecycle changed',
      meta: <String, Object?>{
        'state': stateName,
      },
    );

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final notifier =
          _ref.read(pttControllerProvider.notifier);
      if (notifier.isTalking) {
        PttLogger.log(
          '[PTT][Lifecycle]',
          'stopping PTT due to app background',
          meta: <String, Object?>{
            'state': stateName,
          },
        );
        await notifier.stopTalk(
          reason: 'app_$stateName',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      PttLogger.log(
        '[PTT][Lifecycle]',
        'app resumed',
        meta: const <String, Object?>{
          'state': 'resumed',
        },
      );
    }
  }
}

final pttLifecycleControllerProvider =
    Provider<PttLifecycleController>(
  (ref) => PttLifecycleController(ref),
);

class PttLifecycleObserver extends WidgetsBindingObserver {
  PttLifecycleObserver(this._ref);

  final WidgetRef _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fire-and-forget; 내부에서 자체적으로 로그를 남기고 정리한다.
    _ref
        .read(pttLifecycleControllerProvider)
        .onAppLifecycleChanged(state);
  }
}
