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
    _sink?.call(entry);

    if (kDebugMode) {
      if (meta.isEmpty) {
        debugPrint('$tag $message');
      } else {
        debugPrint('$tag $message ${meta.toString()}');
      }
    }
  }
}

