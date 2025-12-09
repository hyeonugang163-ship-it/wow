import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/auth/auth_state_notifier.dart';

class ProfileOnboardingPage extends ConsumerStatefulWidget {
  const ProfileOnboardingPage({super.key});

  @override
  ConsumerState<ProfileOnboardingPage> createState() =>
      _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState
    extends ConsumerState<ProfileOnboardingPage> {
  final TextEditingController _nameController =
      TextEditingController();
  String _selectedEmoji = '😄';
  bool _agreed = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier =
        ref.read(authStateNotifierProvider.notifier);
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty || !_agreed) {
      return;
    }
    await notifier.completeOnboarding(
      displayName,
      _selectedEmoji,
    );
    final state = ref.read(authStateNotifierProvider);
    if (state.status == AuthStatus.signedIn) {
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final bool isLoading = authState.isLoading;

    final emojis = <String>['😄', '🤩', '😎', '🐻', '🐰', '🚀', '🔥'];

    final bool canSubmit =
        _nameController.text.trim().isNotEmpty &&
            _agreed &&
            !isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MJTalk에 오신 것을 환영합니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '친구랑 즉시 말 걸 수 있는 무전 메신저입니다.\n'
                '먼저 닉네임과 아바타를 정해 주세요.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  hintText: '예: MJ, 라디오맨',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                '아바타 이모지 선택',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: emojis
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e),
                        selected: _selectedEmoji == e,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedEmoji = e;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (value) {
                      setState(() {
                        _agreed = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      '무전 기록/메시지는 설계도 v1.1에서 정의한 '
                      '프라이버시 정책에 따라 처리됩니다.',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('시작하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

