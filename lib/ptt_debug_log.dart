import 'dart:async';

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

/// 순수 Dart 기반 PTT 디버그 로그 버퍼 v2.
///
/// - PttLogger / ProviderObserver는 이 버퍼에만 쓰기(write) 하고,
/// - UI 쪽은 snapshot/stream을 통해 읽기(read)만 수행한다.
class PttDebugLogBufferV2 {
  PttDebugLogBufferV2({this.maxEntries = 500});

  final int maxEntries;
  final List<PttDebugLogEntry> _entries =
      <PttDebugLogEntry>[];
  final StreamController<List<PttDebugLogEntry>> _controller =
      StreamController<List<PttDebugLogEntry>>.broadcast();

  void add(PttDebugLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    if (!_controller.isClosed) {
      _controller.add(
        List<PttDebugLogEntry>.unmodifiable(_entries),
      );
    }
  }

  void clear() {
    _entries.clear();
    if (!_controller.isClosed) {
      _controller.add(const <PttDebugLogEntry>[]);
    }
  }

  List<PttDebugLogEntry> snapshot() {
    return List<PttDebugLogEntry>.unmodifiable(_entries);
  }

  Stream<List<PttDebugLogEntry>> get stream => _controller.stream;
}

/// 앱 전체에서 공유하는 v2 디버그 로그 버퍼 인스턴스.
final PttDebugLogBufferV2 pttDebugLogBufferV2 =
    PttDebugLogBufferV2(maxEntries: 500);

/// v1 시절의 StateNotifier 기반 구현은 더 이상 사용하지 않는다.
/// (이 클래스를 남겨두는 이유는, 향후 필요 시 래퍼로 재사용할 수 있게 하기 위함이다.)
class PttDebugLogNotifier
    extends StateNotifier<List<PttDebugLogEntry>> {
  PttDebugLogNotifier({this.maxEntries = 100}) : super(const []);

  final int maxEntries;
}

/// v2 버퍼의 스트림을 노출하는 StreamProvider.
final pttDebugLogStreamProvider =
    StreamProvider<List<PttDebugLogEntry>>((ref) {
  return pttDebugLogBufferV2.stream;
});

/// 기존 pttDebugLogProvider 이름을 유지하면서,
/// v2 버퍼의 최신 스냅샷을 읽어오는 read-only Provider.
final pttDebugLogProvider =
    Provider<List<PttDebugLogEntry>>((ref) {
  final asyncLogs = ref.watch(pttDebugLogStreamProvider);
  return asyncLogs.maybeWhen(
    data: (value) => value,
    orElse: () => pttDebugLogBufferV2.snapshot(),
  );
});

typedef PttLogSink = void Function(PttDebugLogEntry entry);

class PttLogger {
  static const int _maxEntries = 500;
  static final List<PttDebugLogEntry> _entries =
      <PttDebugLogEntry>[];
  static final StreamController<PttDebugLogEntry> _controller =
      StreamController<PttDebugLogEntry>.broadcast();

  static PttLogSink? _sink;

  static void attachSink(PttLogSink sink) {
    _sink = sink;
  }

  /// 현재까지 수집된 로그의 스냅샷을 반환한다.
  static List<PttDebugLogEntry> recentEntries() {
    return List<PttDebugLogEntry>.unmodifiable(_entries);
  }

  /// 새 로그 엔트리를 스트림으로 방출한다.
  ///
  /// add 시점에는 microtask 로 지연해, provider 초기화 중
  /// 다른 provider 의 state 가 즉시 변경되는 것을 피한다.
  static Stream<PttDebugLogEntry> get stream =>
      _controller.stream;

  static void clear() {
    _entries.clear();
    // v2 버퍼도 함께 비운다.
    pttDebugLogBufferV2.clear();
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

  static void _addToBufferAndStream(PttDebugLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    if (!_controller.hasListener) {
      return;
    }

    // provider 초기화 중에 바로 다른 provider 의 state 를
    // 건드리지 않도록, 이벤트 전달을 microtask 로 지연한다.
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(entry);
      }
    });
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
    _addToBufferAndStream(entry);
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
    // NOTE: ProviderObserver / backend provider 초기화 등에서
    // 호출되므로, 여기서는 sink나 버퍼를 건드리지 않고
    // 콘솔 출력만 수행한다.
    _logToConsole(entry);
  }
}
