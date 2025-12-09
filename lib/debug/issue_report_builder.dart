import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/debug/ptt_log_buffer.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt_debug_log.dart';

class IssueReportBuilder {
  static String build({
    required DebugAppSettings settings,
    required AuthState auth,
    required PttMode currentMode,
    required List<PttLogEntry> logs,
    int maxLogs = 200,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== MJTalk Pre-Alpha Issue Report ===');
    buffer.writeln('');
    buffer.writeln('--- Environment / User ---');
    buffer.writeln('platform: ${settings.platform}');
    buffer.writeln('env: ${settings.env}');
    buffer.writeln('useFakeBackend: ${settings.useFakeBackend}');
    buffer.writeln(
      'useFakeVoiceTransport: ${settings.useFakeVoiceTransport}',
    );
    buffer.writeln(
      'androidInstantPlay: ${FF.androidInstantPlay} '
      'iosModeA: ${FF.iosModeA_PushTapPlay} '
      'iosModeB: ${FF.iosModeB_PTTFramework}',
    );
    buffer.writeln('pttMode: ${currentMode.name}');

    final user = auth.user;
    if (user != null) {
      buffer.writeln('userId: ${user.id}');
      buffer.writeln('displayName: ${user.displayName}');
      buffer.writeln('avatarEmoji: ${user.avatarEmoji}');
    } else {
      buffer.writeln('user: <none>');
    }

    buffer.writeln('');
    buffer.writeln('--- Repro Steps (fill in) ---');
    buffer.writeln('- 어떤 상황에서 문제가 발생했는지 여기에 적어주세요.');
    buffer.writeln('- 버튼을 어디서 어떻게 눌렀는지, 예상한 동작과 실제 동작.');
    buffer.writeln('');

    buffer.writeln('--- Recent Logs ---');
    final total = logs.length;
    final toTake = total > maxLogs ? maxLogs : total;
    buffer.writeln('showing $toTake of $total entries (newest first)');

    final recent = logs.reversed.take(toTake);
    for (final entry in recent) {
      final time = _formatTime(entry.at);
      buffer.writeln(
        '[$time][${entry.level}][${entry.tag}] ${entry.message}',
      );
    }

    final result = buffer.toString();
    PttLogger.log(
      '[Debug][IssueReport]',
      'built',
      meta: <String, Object?>{
        'length': result.length,
        'logCount': toTake,
      },
    );

    return result;
  }

  static String _formatTime(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

class DebugAppSettings {
  const DebugAppSettings({
    required this.platform,
    required this.env,
    required this.useFakeBackend,
    required this.useFakeVoiceTransport,
  });

  final String platform;
  final String env;
  final bool useFakeBackend;
  final bool useFakeVoiceTransport;
}
