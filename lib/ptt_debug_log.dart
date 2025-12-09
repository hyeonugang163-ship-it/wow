import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PttDebugLogEntry {
  const PttDebugLogEntry({
    required this.at,
    required this.tag,
    required this.message,
    this.meta = const <String, Object?>{},
  });

  final DateTime at;
  final String tag;
  final String message;
  final Map<String, Object?> meta;
}

class PttDebugLogNotifier extends StateNotifier<List<PttDebugLogEntry>> {
  PttDebugLogNotifier({this.maxEntries = 100}) : super(const []);

  final int maxEntries;

  void add(PttDebugLogEntry entry) {
    // TODO: Riverpod 초기화 중 provider 변경 이슈 때문에,
    // 디버그 로그 provider는 임시로 no-op 처리한다.
    // 나중에 ProviderObserver/별도 로그 버퍼를 사용하는 방식으로 리팩터링 예정.
  }

  void clear() {
    state = const [];
  }
}

final pttDebugLogProvider =
    StateNotifierProvider<PttDebugLogNotifier, List<PttDebugLogEntry>>(
  (ref) => PttDebugLogNotifier(),
);

typedef PttLogSink = void Function(PttDebugLogEntry entry);

class PttLogger {
  static PttLogSink? _sink;

  static void attachSink(PttLogSink sink) {
    _sink = sink;
  }

  // NOTE: 콘솔 출력 / provider 반영을 분리하기 위해
  // 내부 헬퍼 메서드를 사용한다.
  static void _logToSink(PttDebugLogEntry entry) {
    _sink?.call(entry);
  }

  static void _logToConsole(PttDebugLogEntry entry) {
    if (!kDebugMode) {
      return;
    }
    if (entry.meta.isEmpty) {
      debugPrint('${entry.tag} ${entry.message}');
    } else {
      debugPrint('${entry.tag} ${entry.message} ${entry.meta.toString()}');
    }
  }

  static void log(
    String tag,
    String message, {
    Map<String, Object?> meta = const <String, Object?>{},
  }) {
    final entry = PttDebugLogEntry(
      at: DateTime.now(),
      tag: tag,
      message: message,
      meta: meta,
    );
    _logToSink(entry);
    _logToConsole(entry);
  }

  /// 빌드 타이밍 등에서 provider를 건드리지 않고
  /// 콘솔 로그만 남기고 싶은 경우에 사용한다.
  static void logConsoleOnly(
    String tag,
    String message, {
    Map<String, Object?> meta = const <String, Object?>{},
  }) {
    final entry = PttDebugLogEntry(
      at: DateTime.now(),
      tag: tag,
      message: message,
      meta: meta,
    );
    _logToConsole(entry);
  }
}
