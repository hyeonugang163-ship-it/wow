import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/feature_flags.dart';

/// 앱 전체 PTT 모드 (기본: 매너모드).
///
/// - PttMode.manner: 매너모드 (녹음본 수신만 허용)
/// - PttMode.walkie: 무전모드 (상호 무전 허용 친구에게만 즉시 재생 PTT 허용)
///
/// TODO: SharedPreferences 등 로컬 스토리지에 저장해
///       앱 재실행 시에도 마지막 선택 모드를 복원한다.
class PttModeNotifier extends StateNotifier<PttMode> {
  PttModeNotifier() : super(PttMode.manner);

  void setMode(PttMode mode) {
    state = mode;
  }

  void toggle() {
    state =
        state == PttMode.walkie ? PttMode.manner : PttMode.walkie;
  }
}

final pttModeProvider =
    StateNotifierProvider<PttModeNotifier, PttMode>(
  (ref) {
    // NOTE: 현재 단계에서는 로컬 전역 상태만 사용한다.
    // 향후 FF/PolicyConfig와 연동해 Walkie 사용 가능 여부를 제한할 수 있다.
    return PttModeNotifier();
  },
);

