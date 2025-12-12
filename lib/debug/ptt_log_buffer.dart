import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/ptt_debug_log.dart';

class PttLogEntry {
  const PttLogEntry({
    required this.at,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime at;
  final String level;
  final String tag;
  final String message;
}

PttLogEntry _fromDebugEntry(PttDebugLogEntry entry) {
  return PttLogEntry(
    at: entry.at,
    level: 'I',
    tag: entry.tag,
    // 메타데이터는 이미 PttLogger 수준에서 프라이버시를 고려한 값만 담고 있다.
    message: entry.meta.isEmpty
        ? entry.message
        : '${entry.message} ${entry.meta.toString()}',
  );
}

List<PttLogEntry> _fromDebugEntries(
  List<PttDebugLogEntry> entries,
) {
  return entries.map(_fromDebugEntry).toList();
}

/// v2 디버그 버퍼를 PttLogEntry 리스트로 노출하는 StreamProvider.
final pttLogBufferStreamProvider =
    StreamProvider<List<PttLogEntry>>((ref) {
  final initial =
      _fromDebugEntries(pttDebugLogBufferV2.snapshot());
  final updates =
      pttDebugLogBufferV2.stream.map(_fromDebugEntries);
  // StreamProvider는 첫 이벤트가 오기 전까지 loading 상태가 되므로,
  // 스냅샷(빈 리스트 포함)을 먼저 한 번 내보내 무한 로딩을 방지한다.
  Stream<List<PttLogEntry>> stream() async* {
    yield initial;
    yield* updates;
  }

  return stream();
});

/// 기존 pttLogBufferProvider 이름을 유지하면서,
/// 최신 로그 스냅샷을 읽어오는 read-only Provider.
final pttLogBufferProvider =
    Provider<List<PttLogEntry>>((ref) {
  final asyncLogs = ref.watch(pttLogBufferStreamProvider);
  return asyncLogs.maybeWhen(
    data: (value) => value,
    orElse: () =>
        _fromDebugEntries(pttDebugLogBufferV2.snapshot()),
  );
});

/// 디버그 로그 버퍼와 PttLogger 내부 버퍼를 모두 비운다.
void clearPttLogBuffer() {
  PttLogger.clear();
}
