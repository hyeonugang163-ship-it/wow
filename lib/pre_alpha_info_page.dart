import 'package:flutter/material.dart';
import 'package:voyage/app_env.dart';
import 'package:voyage/feature_flags.dart';

class PreAlphaInfoPage extends StatelessWidget {
  const PreAlphaInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final env = AppEnv.current;
    final envName = AppEnv.currentName;
    final isFakeBackend = FF.useFakeBackend;
    final isFakeTransport = FF.useFakeVoiceTransport;

    final backendLabel = isFakeBackend ? 'FakeBackend (로컬 데이터)' : 'RealBackend (실서버)';
    final transportLabel =
        isFakeTransport ? 'FakeVoiceTransport (로컬 오디오, LiveKit 미연동)' : 'RealVoiceTransport (LiveKit/실서버 기반)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('프리알파 안내'),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '빌드 / 환경 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '이 빌드는 Android용 Pre-Alpha 테스트 빌드입니다.\n'
                      'PTT 코어 및 FakeBackend/FakeVoiceTransport 기반으로, 주로 내부 테스트와 지인 테스트를 위해 사용됩니다.',
                    ),
                    const SizedBox(height: 12),
                    Text('환경(AppEnvironment): $envName'),
                    Text('Backend: $backendLabel'),
                    Text('VoiceTransport: $transportLabel'),
                    const SizedBox(height: 8),
                    if (env != AppEnvironment.prod)
                      const Text(
                        '※ 이 빌드는 아직 실제 서버/푸시/LiveKit 없이, 로컬 데이터 기준으로 동작하는 Pre-Alpha 단계입니다.',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        '※ 이 빌드는 프로덕션 환경에서도 사용할 수 있는 구성을 목표로 하지만, 일부 안내 문구는 Pre-Alpha 기준으로 작성되어 있습니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '현재 단계에서의 주요 제약사항',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• 아직 실제 서버/LiveKit SFU에 연결되어 있지 않으며, 대부분의 데이터는 이 기기 안에서만 유지됩니다.\n'
                      '• iOS는 아직 본격적으로 테스트되지 않았고, 현재는 Android 단일 디바이스 테스트에 초점을 맞추고 있습니다.\n'
                      '• Firebase/FCM 기반 푸시 알림은 아직 연동되지 않았습니다.\n'
                      '• 향후 Real Backend / LiveKit / 푸시가 붙으면, 동작 방식과 품질이 달라질 수 있습니다.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '버그 리포트 보내는 방법',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1) 문제가 발생한 직후, Settings → 디버그 로그 화면으로 이동합니다.\n'
                      '2) 상단 또는 화면 내의 "리포트 복사" 버튼을 눌러 Debug Issue Report 텍스트를 클립보드에 복사합니다.\n'
                      '3) 카카오톡/노션/이메일 등 원하는 채널에 붙여넣고, 어떤 화면에서 어떤 행동을 했을 때 문제가 발생했는지 간단히 적어 주세요.\n'
                      '4) 가능하다면 스크린샷이나 화면 녹화를 함께 보내 주시면 문제 파악에 큰 도움이 됩니다.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '테스트 체크리스트 / 로드맵 참고',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '앱 내부 테스트는 docs/pre_alpha_checklist.md 에 정의된 시나리오를 기준으로 진행됩니다.\n'
                      'Firebase/푸시/실서버/LiveKit 도입 계획은 docs/backend_and_push_roadmap.md 문서에 정리되어 있습니다.\n'
                      '이 화면은 해당 문서들의 핵심을 간단히 요약해서 보여주는 안내용 페이지입니다.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

