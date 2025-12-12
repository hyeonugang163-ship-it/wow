import 'package:voyage/core/feature_flags.dart';

enum PolicyBlockReason {
  friendBlocked,
  cooldown,
}

enum PolicyDowngradeReason {
  notMutualConsent,
}

class PolicyDecision {
  const PolicyDecision({
    required this.requestedMode,
    required this.effectiveMode,
    this.blockReason,
    this.downgradeReason,
    this.sinceLastMs,
    this.minIntervalMs,
  });

  final PttMode requestedMode;
  final PttMode effectiveMode;
  final PolicyBlockReason? blockReason;
  final PolicyDowngradeReason? downgradeReason;

  /// For cooldown blocks, how many ms since last PTT start.
  final int? sinceLastMs;

  /// For cooldown blocks, the policy min interval.
  final int? minIntervalMs;

  bool get canStart => blockReason == null;

  bool get downgradedToManner =>
      requestedMode == PttMode.walkie &&
      effectiveMode == PttMode.manner;
}

class PolicyEvaluator {
  const PolicyEvaluator();

  PolicyDecision evaluateStartTalk({
    required PolicyConfig policy,
    required PttMode requestedMode,
    required bool allowEffective,
    required bool friendBlocked,
    required DateTime now,
    required DateTime? lastPttStartedAt,
  }) {
    if (friendBlocked) {
      return PolicyDecision(
        requestedMode: requestedMode,
        effectiveMode: requestedMode,
        blockReason: PolicyBlockReason.friendBlocked,
      );
    }

    final minIntervalMs = policy.pttMinIntervalMillis;
    if (lastPttStartedAt != null && minIntervalMs > 0) {
      final sinceLastMs =
          now.millisecondsSinceEpoch -
          lastPttStartedAt.millisecondsSinceEpoch;
      if (sinceLastMs < minIntervalMs) {
        return PolicyDecision(
          requestedMode: requestedMode,
          effectiveMode: requestedMode,
          blockReason: PolicyBlockReason.cooldown,
          sinceLastMs: sinceLastMs,
          minIntervalMs: minIntervalMs,
        );
      }
    }

    if (requestedMode == PttMode.walkie && !allowEffective) {
      return PolicyDecision(
        requestedMode: requestedMode,
        effectiveMode: PttMode.manner,
        downgradeReason: PolicyDowngradeReason.notMutualConsent,
      );
    }

    return PolicyDecision(
      requestedMode: requestedMode,
      effectiveMode: requestedMode,
    );
  }
}

