import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/app_env.dart';
import 'package:voyage/auth/auth_state_notifier.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt/ptt_user_prefs.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';
import 'package:voyage/ptt_debug_log.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beepOnStart = ref.watch(pttBeepOnStartProvider);
    final beepOnEnd = ref.watch(pttBeepOnEndProvider);
    final vibrateInWalkie = ref.watch(pttVibrateInWalkieProvider);
    final beepOnReceive = ref.watch(pttBeepOnReceiveProvider);
    final debugOverlayEnabled =
        ref.watch(pttDebugOverlayEnabledProvider);
    final verboseLoggingEnabled =
        ref.watch(pttVerboseLoggingEnabledProvider);
    final mode = ref.watch(pttModeProvider);
    final env = AppEnv.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PTT 모드 설명',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '무전모드 (Walkie)\n'
                      '• 서로 친구이고, 서로 "무전 허용"에 동의한 유저끼리만 사용 가능합니다.\n'
                      '• 폰이 진동/무음이어도 (OS가 허용하는 범위에서) 바로 목소리가 재생되는 무전기 느낌의 모드입니다.\n'
                      '• 상호동의 + 화이트리스트 기반의 "특권 모드"로 설계되어 있습니다.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '매너모드 (Manner)\n'
                      '• 즉시 재생 대신 녹음본(음성 메시지)으로만 수신하는 안전한 모드입니다.\n'
                      '• 나중에 "시간대" / "앞으로 N시간" 설정으로 자동 매너모드 유지 기능을 제공할 예정입니다.\n'
                      '• 기본값은 매너모드로 시작하는 것을 권장합니다.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('무전 모드 (Walkie)'),
                subtitle: Text(
                  mode == PttMode.walkie
                      ? '상호 무전 허용 친구에게만 즉시 재생 무전을 보낼 수 있어요.'
                      : '지금은 매너모드입니다. 모든 친구와 음성 노트만 주고받아요.',
                ),
                value: mode == PttMode.walkie,
                onChanged: (value) {
                  ref
                      .read(pttModeProvider.notifier)
                      .setMode(
                        value
                            ? PttMode.walkie
                            : PttMode.manner,
                      );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('프리알파 안내'),
                subtitle: const Text(
                  '이 빌드의 목적과 제한사항, 버그 제보 방법을 확인합니다.',
                ),
                trailing: const Icon(Icons.info_outline),
                onTap: () {
                  if (context.mounted) {
                    context.push('/pre-alpha-info');
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            if (env != AppEnvironment.prod) ...[
              Card(
                child: ListTile(
                  title: const Text('디버그 로그 보기'),
                  subtitle: const Text(
                    '최근 PTT/Backend/Auth 로그를 확인하고 복사합니다.',
                  ),
                  trailing: const Icon(Icons.bug_report_outlined),
                  onTap: () {
                    if (context.mounted) {
                      context.push('/debug/logs');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text(
                      '현재 정책 상태 (Feature Flags)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      'Android 즉시 재생 (androidInstantPlay)',
                    ),
                    trailing: Text(
                      FF.androidInstantPlay ? 'ON' : 'OFF',
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'iOS A안 (APNs → 탭 → 재생) (iosModeA_PushTapPlay)',
                    ),
                    trailing: Text(
                      FF.iosModeA_PushTapPlay ? 'ON' : 'OFF',
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'iOS B안 (PushToTalk Framework) (iosModeB_PTTFramework)',
                    ),
                    trailing: Text(
                      FF.iosModeB_PTTFramework ? 'ON' : 'OFF',
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'iOS VoIP + CallKit (callKitVoip)',
                    ),
                    trailing: Text(
                      FF.callKitVoip ? 'ON' : 'OFF',
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'TURN 443 강제 (forceTurnTcpTls443)',
                    ),
                    trailing: Text(
                      FF.forceTurnTcpTls443 ? 'ON' : 'OFF',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (env != AppEnvironment.prod) ...[
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text(
                        '실험적 옵션 (일부 동작)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '향후 PTT UX를 튜닝할 때 사용할 수 있는 옵션들입니다. '
                        '비프음/진동 설정은 무전 버튼 동작에 바로 반영됩니다.',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('PTT 디버그 오버레이 표시'),
                      subtitle: const Text(
                        '현재 PTT 모드/친구/최근 로그를 화면 우측 하단에 표시합니다.',
                      ),
                      value: debugOverlayEnabled,
                      onChanged: (value) {
                        ref
                            .read(
                              pttDebugOverlayEnabledProvider.notifier,
                            )
                            .state = value;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('콘솔 PTT 로그 상세 출력'),
                      subtitle: const Text(
                        '끄면 내부 버퍼/디버그 화면에는 남기되, 터미널 콘솔 출력은 최소화합니다.',
                      ),
                      value: verboseLoggingEnabled,
                      onChanged: (value) {
                        ref
                            .read(
                              pttVerboseLoggingEnabledProvider.notifier,
                            )
                            .state = value;
                        PttLogger.setConsoleVerbose(value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('PTT 시작 전 짧은 비프음 재생'),
                      value: beepOnStart,
                      onChanged: (value) {
                        ref
                            .read(pttBeepOnStartProvider.notifier)
                            .state = value;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Walkie 수신 시 알림음'),
                      subtitle: const Text(
                        '무전모드에서 상대가 보낸 음성이 자동 재생되기 전에 짧은 알림음을 재생합니다.',
                      ),
                      value: beepOnReceive,
                      onChanged: (value) {
                        ref
                            .read(
                              pttBeepOnReceiveProvider.notifier,
                            )
                            .state = value;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('PTT 종료 후 짧은 비프음 재생'),
                      value: beepOnEnd,
                      onChanged: (value) {
                        ref
                            .read(pttBeepOnEndProvider.notifier)
                            .state = value;
                      },
                    ),
                    SwitchListTile(
                      title: const Text('무전모드에서만 진동 허용'),
                      value: vibrateInWalkie,
                      onChanged: (value) {
                        ref
                            .read(
                              pttVibrateInWalkieProvider.notifier,
                            )
                            .state = value;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: ListTile(
                title: const Text('로그아웃'),
                subtitle: const Text(
                  '현재 프로필을 초기화하고 온보딩 화면으로 돌아갑니다.',
                ),
                trailing: const Icon(Icons.logout),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text(
                          '로그아웃하면 다시 프로필을 설정해야 합니다. '
                          '계속할까요?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('로그아웃'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed != true) {
                    return;
                  }

                  await ref
                      .read(authStateNotifierProvider.notifier)
                      .signOut();

                  if (context.mounted) {
                    context.go('/onboarding/profile');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
