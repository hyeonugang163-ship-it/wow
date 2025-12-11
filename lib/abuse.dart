// NOTE: 설계도 v1.1 기준 신고(Abuse) 레이어 구현 파일로,
// 메타데이터만 로그/저장하며 실제 콘텐츠는 다루지 않는다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/ptt_debug_log.dart';

enum AbuseReason {
  spam,
  harassment,
  inappropriate,
  other,
}

class AbuseReport {
  AbuseReport({
    required this.id,
    required this.friendId,
    this.messageId,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String friendId;
  final String? messageId;
  final AbuseReason reason;
  final String? note;
  final DateTime createdAt;
}

class AbuseApiClient {
  Future<void> submitReport(AbuseReport report) async {
    PttLogger.log(
      '[Safety][ReportApi]',
      'submitReport',
      meta: <String, Object?>{
        'friendId': report.friendId,
        'messageId': report.messageId ?? '(none)',
        'reason': report.reason.name,
      },
    );
    // TODO(ASK_SUPERVISOR): 실제 신고 수집용 서버 URL/계약이 결정되면
    // 여기에 HTTP API 연동을 추가한다.
  }
}

class AbuseReportsNotifier extends StateNotifier<List<AbuseReport>> {
  AbuseReportsNotifier(this._api) : super(const []);

  final AbuseApiClient _api;

  Future<void> addReport({
    required String friendId,
    String? messageId,
    required AbuseReason reason,
    String? note,
  }) async {
    final now = DateTime.now();
    final report = AbuseReport(
      id: now.millisecondsSinceEpoch.toString(),
      friendId: friendId,
      messageId: messageId,
      reason: reason,
      note: note,
      createdAt: now,
    );
    state = [...state, report];

    PttLogger.log(
      '[Safety][Report]',
      'addReport',
      meta: <String, Object?>{
        'friendId': friendId,
        'messageId': messageId ?? '(none)',
        'reason': reason.name,
        'timestamp': now.toIso8601String(),
      },
    );

    await _api.submitReport(report);
  }
}

final abuseReportsProvider =
    StateNotifierProvider<AbuseReportsNotifier, List<AbuseReport>>(
  (ref) => AbuseReportsNotifier(AbuseApiClient()),
);
