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

class PttLogBufferNotifier extends StateNotifier<List<PttLogEntry>> {
  PttLogBufferNotifier({this.maxEntries = 500}) : super(const []);

  final int maxEntries;

  void add(PttLogEntry entry) {
    final List<PttLogEntry> next = <PttLogEntry>[
      ...state,
      entry,
    ];
    if (next.length > maxEntries) {
      state = next.sublist(next.length - maxEntries);
    } else {
      state = next;
    }
  }

  void addFromDebugEntry(PttDebugLogEntry entry) {
    // 현재는 별도의 레벨 정보를 쓰지 않으므로 "I"로 고정한다.
    add(
      PttLogEntry(
        at: entry.at,
        level: 'I',
        tag: entry.tag,
        // 메타데이터는 이미 PttLogger 수준에서 프라이버시를 고려한 값만 담고 있다.
        message: entry.meta.isEmpty
            ? entry.message
            : '${entry.message} ${entry.meta.toString()}',
      ),
    );
  }

  void clear() {
    state = const [];
  }
}

final pttLogBufferProvider =
    StateNotifierProvider<PttLogBufferNotifier, List<PttLogEntry>>(
  (ref) => PttLogBufferNotifier(),
);

