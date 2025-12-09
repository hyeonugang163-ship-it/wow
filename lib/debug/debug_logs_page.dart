import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/app_env.dart';
import 'package:voyage/auth/auth_state_notifier.dart';
import 'package:voyage/debug/issue_report_builder.dart';
import 'package:voyage/debug/ptt_log_buffer.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';

class DebugLogsPage extends ConsumerStatefulWidget {
  const DebugLogsPage({super.key});

  @override
  ConsumerState<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends ConsumerState<DebugLogsPage> {
  String _levelFilter = 'all';
  String _tagFilter = '';
  final TextEditingController _tagController =
      TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  List<PttLogEntry> _applyFilters(List<PttLogEntry> logs) {
    Iterable<PttLogEntry> current = logs;

    if (_levelFilter == 'we') {
      current = current.where(
        (e) => e.level == 'W' || e.level == 'E',
      );
    }

    final q = _tagFilter.trim().toLowerCase();
    if (q.isNotEmpty) {
      current = current.where(
        (e) => e.tag.toLowerCase().contains(q),
      );
    }

    return current.toList().reversed.toList();
  }

  String _formatEntry(PttLogEntry entry) {
    final t = entry.at;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
    return '[$time][${entry.level}][${entry.tag}] ${entry.message}';
  }

  Future<void> _copyLogs(List<PttLogEntry> logs) async {
    final lines = logs.map(_formatEntry).join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로그가 클립보드에 복사되었습니다.'),
      ),
    );
  }

  Future<void> _copyIssueReport(List<PttLogEntry> logs) async {
    final auth = ref.read(authStateNotifierProvider);
    final currentMode = ref.read(pttModeProvider);
    final settings = DebugAppSettings(
      platform: Theme.of(context).platform.name,
      env: AppEnv.current.name,
      useFakeBackend: FF.useFakeBackend,
      useFakeVoiceTransport: FF.useFakeVoiceTransport,
    );
    final text = IssueReportBuilder.build(
      settings: settings,
      auth: auth,
      currentMode: currentMode,
      logs: logs,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '버그 리포트 텍스트가 복사되었습니다. '
          '카톡/노션 등에 붙여 넣어 공유해 주세요.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(pttLogBufferStreamProvider);

    return logsAsync.when(
      data: (logs) {
        final filtered = _applyFilters(logs);

        return Scaffold(
          appBar: AppBar(
            title: const Text('디버그 로그'),
            actions: [
              IconButton(
                tooltip: '버그 리포트 복사',
                icon: const Icon(Icons.description_outlined),
                onPressed: filtered.isEmpty
                    ? null
                    : () => _copyIssueReport(logs),
              ),
              IconButton(
                tooltip: '로그 복사',
                icon: const Icon(Icons.copy),
                onPressed: filtered.isEmpty
                    ? null
                    : () => _copyLogs(filtered),
              ),
              IconButton(
                tooltip: '지우기',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  clearPttLogBuffer();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _levelFilter,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _levelFilter = value;
                        });
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('모든 로그'),
                        ),
                        DropdownMenuItem(
                          value: 'we',
                          child: Text('경고/에러만'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          labelText: '태그 필터 (예: PTT, Backend)',
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _tagFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('아직 수집된 로그가 없습니다.'),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final text = _formatEntry(entry);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          title: const Text('디버그 로그'),
        ),
        body: const Center(
          child: Text(
            '로그를 불러오는 중 문제가 발생했습니다.',
          ),
        ),
      ),
    );
  }
}
