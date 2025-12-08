import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/ptt_local_audio.dart';

/// Manual test – voice bubble UX
///
/// 1) Manner 모드에서 친구1(u1)에게 음성 메시지 2개를 전송한다.
/// 2) 친구1 채팅방으로 들어가면 음성 버블 2개가 보인다.
/// 3) 첫 번째 버블을 탭하면:
///    - 아이콘이 ▶ 에서 ⏸ 로 바뀌고,
///    - [ChatVoicePlayer] onTap / play requested 로그가 찍힌다.
/// 4) 다시 탭하면 재생이 멈추고 아이콘이 ▶ 로 돌아온다.
/// 5) 두 번째 버블도 동일하게 동작하는지 확인한다.
/// 6) 파일이 없는 path를 가진 메시지를 만들면,
///    탭 시 재생 시도 대신 에러 로그만 찍히는지 확인한다.
///
/// Shared local audio engine for PTT record/playback and chat playback.
///
/// The same instance is reused from both [PttController] and [ChatVoicePlayer]
/// to avoid duplicated audio engine initialization.
final pttLocalAudioEngineProvider = Provider<PttLocalAudioEngine>((ref) {
  final engine = PttLocalAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Currently playing voice message id in chat, if any.
///
/// Used only for lightweight UI hints (e.g. different icon while playing).
final currentPlayingVoiceMessageIdProvider = StateProvider<String?>(
  (ref) => null,
);

class ChatVoicePlayer {
  ChatVoicePlayer(this._ref, this._localAudio);

  final Ref _ref;
  final PttLocalAudioEngine _localAudio;

  int _playRequestId = 0;

  Future<void> play({
    required String path,
    String? messageId,
  }) async {
    final hasPath = path.isNotEmpty;
    debugPrint(
      '[ChatVoicePlayer] play requested '
      '(hasPath=$hasPath messageId=$messageId)',
    );

    if (!hasPath) {
      return;
    }

    final requestId = ++_playRequestId;

    try {
      await _localAudio.init();
      _ref.read(currentPlayingVoiceMessageIdProvider.notifier).state =
          messageId;
      debugPrint(
        '[ChatVoicePlayer] play start '
        '(messageId=$messageId)',
      );
      await _localAudio.playFromPath(path);
      debugPrint(
        '[ChatVoicePlayer] play completed '
        '(messageId=$messageId)',
      );
    } catch (e) {
      debugPrint(
        '[ChatVoicePlayer] play error '
        '(hasPath=$hasPath messageId=$messageId error=$e)',
      );
    } finally {
      // Only clear if this is the latest play request.
      if (_playRequestId == requestId) {
        _ref.read(currentPlayingVoiceMessageIdProvider.notifier).state = null;
      }
    }
  }

  Future<void> togglePlay({
    required String path,
    required String messageId,
  }) async {
    final currentId =
        _ref.read(currentPlayingVoiceMessageIdProvider);
    final hasPath = path.isNotEmpty;

    debugPrint(
      '[ChatVoicePlayer] onTap messageId=$messageId '
      'stateBefore=${currentId == messageId ? 'playing' : 'idle'} '
      'hasPath=$hasPath',
    );

    if (!hasPath) {
      return;
    }

    if (currentId == messageId) {
      try {
        await _localAudio.stopPlayback();
        debugPrint(
          '[ChatVoicePlayer] stop requested messageId=$messageId',
        );
      } catch (e) {
        debugPrint(
          '[ChatVoicePlayer] stop error messageId=$messageId error=$e',
        );
      } finally {
        _ref.read(currentPlayingVoiceMessageIdProvider.notifier).state =
            null;
      }
      return;
    }

    await play(path: path, messageId: messageId);
  }
}

final chatVoicePlayerProvider = Provider<ChatVoicePlayer>((ref) {
  final engine = ref.read(pttLocalAudioEngineProvider);
  return ChatVoicePlayer(ref, engine);
});
