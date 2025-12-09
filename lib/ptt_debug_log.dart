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
    final List<PttDebugLogEntry> next = <PttDebugLogEntry>[
      ...state,
      entry,
    ];
    if (next.length > maxEntries) {
      state = next.sublist(next.length - maxEntries);
    } else {
      state = next;
    }
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
