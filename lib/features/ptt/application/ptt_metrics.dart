import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/core/feature_flags.dart';

class PttMetrics {
  const PttMetrics({
    required this.totalCount,
    required this.successCount,
    required this.errorCount,
    required this.lastTtpMillis,
    required this.p50TtpMillis,
    required this.p95TtpMillis,
    required this.lastTtpSamples,
  });

  final int totalCount;
  final int successCount;
  final int errorCount;
  final int lastTtpMillis;
  final int p50TtpMillis;
  final int p95TtpMillis;
  final List<int> lastTtpSamples;

  factory PttMetrics.initial() {
    return const PttMetrics(
      totalCount: 0,
      successCount: 0,
      errorCount: 0,
      lastTtpMillis: 0,
      p50TtpMillis: 0,
      p95TtpMillis: 0,
      lastTtpSamples: <int>[],
    );
  }

  PttMetrics copyWith({
    int? totalCount,
    int? successCount,
    int? errorCount,
    int? lastTtpMillis,
    int? p50TtpMillis,
    int? p95TtpMillis,
    List<int>? lastTtpSamples,
  }) {
    return PttMetrics(
      totalCount: totalCount ?? this.totalCount,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      lastTtpMillis: lastTtpMillis ?? this.lastTtpMillis,
      p50TtpMillis: p50TtpMillis ?? this.p50TtpMillis,
      p95TtpMillis: p95TtpMillis ?? this.p95TtpMillis,
      lastTtpSamples: lastTtpSamples ?? this.lastTtpSamples,
    );
  }
}

class PttMetricsNotifier extends StateNotifier<PttMetrics> {
  PttMetricsNotifier() : super(PttMetrics.initial());

  static const int _maxSamples = 50;

  void recordStartRequest({
    required String? friendId,
    required PttMode mode,
    required DateTime at,
  }) {
    state = state.copyWith(
      totalCount: state.totalCount + 1,
    );
  }

  void recordSuccess({
    required String? friendId,
    required PttMode mode,
    required int ttpMillis,
  }) {
    final List<int> samples = <int>[
      ...state.lastTtpSamples,
      ttpMillis,
    ];
    final List<int> trimmed = samples.length > _maxSamples
        ? samples.sublist(samples.length - _maxSamples)
        : samples;

    final List<int> sorted = <int>[...trimmed]..sort();
    int p50 = 0;
    int p95 = 0;
    if (sorted.isNotEmpty) {
      final int lastIndex = sorted.length - 1;
      final int p50Index = (lastIndex * 0.5).round();
      final int p95Index = (lastIndex * 0.95).round();
      p50 = sorted[p50Index];
      p95 = sorted[p95Index];
    }

    state = state.copyWith(
      successCount: state.successCount + 1,
      lastTtpMillis: ttpMillis,
      p50TtpMillis: p50,
      p95TtpMillis: p95,
      lastTtpSamples: trimmed,
    );
  }

  void recordError({
    required String? friendId,
    required PttMode mode,
    required String reason,
  }) {
    state = state.copyWith(
      errorCount: state.errorCount + 1,
    );
  }
}

final pttMetricsProvider =
    StateNotifierProvider<PttMetricsNotifier, PttMetrics>(
  (ref) => PttMetricsNotifier(),
);
