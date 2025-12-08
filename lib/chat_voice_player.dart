import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/ptt_local_audio.dart';

/// Manual test – voice bubble playback UX
/// 1) Manner 모드에서 친구 A에게 음성 메시지 2개를 보낸다.
/// 2) 친구 A 채팅방에 음성 버블 2개가 표시되는지 확인한다.
/// 3) 첫 번째 버블을 탭:
///    - 아이콘이 ▶ 에서 ⏸ 로 바뀌고,
///    - 실제 오디오가 재생되며,
///    - 로그에 [ChatVoicePlayer] play start ... 가 찍힌다.
/// 4) 다시 탭하면 재생이 멈추고, 아이콘이 ▶ 로 돌아온다.
/// 5) 두 번째 버블에서도 동일하게 동작하는지 확인한다.
/// 6) (선택) 파일을 삭제하거나 존재하지 않는 path를 가진 메시지를 만들어
///    error 상태 아이콘/텍스트가 잘 표시되는지 확인한다.
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

/// Voice messages that hit a playback error.
///
/// Used to render ⚠ + "재생 실패" 상태 in the UI.
final voicePlaybackErrorMessageIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// Simple playback state for logging and reasoning.
enum VoicePlayState {
  idle,
  playing,
  error,
}

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

    if (messageId != null) {
      final errorNotifier =
          _ref.read(voicePlaybackErrorMessageIdsProvider.notifier);
      if (errorNotifier.state.contains(messageId)) {
        final cleared = <String>{...errorNotifier.state}..remove(messageId);
        errorNotifier.state = cleared;
      }
    }

    final requestId = ++_playRequestId;

    try {
      await _localAudio.init();
      final globalNotifier =
          _ref.read(currentPlayingVoiceMessageIdProvider.notifier);
      final oldId = globalNotifier.state;
      if (oldId != messageId) {
        globalNotifier.state = messageId;
        debugPrint(
          '[ChatVoicePlayer] global playing id changed old=$oldId new=$messageId',
        );
      }
      debugPrint(
        '[ChatVoicePlayer] play start path=$path messageId=$messageId',
      );
      final startedAt = DateTime.now();
      await _localAudio.playFromPath(
        path,
        rethrowOnError: true,
      );

      // Prefer engine-reported duration; fall back to elapsed wall-clock.
      final durationFromEngine =
          _localAudio.lastPlaybackDurationMillis;
      final elapsedMillis =
          DateTime.now().difference(startedAt).inMilliseconds;
      final effectiveDurationMillis =
          durationFromEngine ?? elapsedMillis;

      if (messageId != null && effectiveDurationMillis > 0) {
        _ref
            .read(chatMessagesProvider.notifier)
            .updateVoiceMessageDuration(
              messageId: messageId,
              durationMillis: effectiveDurationMillis,
            );
      }

      debugPrint(
        '[ChatVoicePlayer] play completed path=$path messageId=$messageId',
      );
    } catch (e) {
      debugPrint(
        '[ChatVoicePlayer] play error path=$path '
        'messageId=$messageId error=$e',
      );
      if (messageId != null) {
        final errorNotifier =
            _ref.read(voicePlaybackErrorMessageIdsProvider.notifier);
        final next = <String>{...errorNotifier.state, messageId};
        errorNotifier.state = next;
      }
    } finally {
      // Only clear if this is the latest play request.
      if (_playRequestId == requestId) {
        final globalNotifier =
            _ref.read(currentPlayingVoiceMessageIdProvider.notifier);
        final oldId = globalNotifier.state;
        if (oldId != null) {
          globalNotifier.state = null;
          debugPrint(
            '[ChatVoicePlayer] global playing id changed old=$oldId new=null',
          );
        }
      }
    }
  }

  Future<void> togglePlay({
    required String path,
    required String messageId,
  }) async {
    final currentId = _ref.read(currentPlayingVoiceMessageIdProvider);
    final hasPath = path.isNotEmpty;

    final stateBefore = !hasPath
        ? VoicePlayState.error
        : (currentId == messageId
            ? VoicePlayState.playing
            : VoicePlayState.idle);
    final isPlayingBefore = stateBefore == VoicePlayState.playing;

    debugPrint(
      '[ChatVoicePlayer] tap messageId=$messageId '
      'isPlayingBefore=$isPlayingBefore path=$path',
    );

    if (!hasPath) {
      // TODO: handle VoicePlayState.error tap (e.g. surface retry UI).
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
        final globalNotifier =
            _ref.read(currentPlayingVoiceMessageIdProvider.notifier);
        final oldId = globalNotifier.state;
        if (oldId != null) {
          globalNotifier.state = null;
          debugPrint(
            '[ChatVoicePlayer] global playing id changed old=$oldId new=null',
          );
        }
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
