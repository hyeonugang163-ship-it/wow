import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/ptt_debug_log.dart';
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

/// Current playback position for the active voice message.
final voicePlaybackPositionProvider =
    StateProvider<Duration>((ref) => Duration.zero);

/// Current playback duration for the active voice message, if known.
final voicePlaybackDurationProvider =
    StateProvider<Duration?>((ref) => null);

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
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  void _resetProgress() {
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _ref.read(voicePlaybackPositionProvider.notifier).state =
        Duration.zero;
    _ref.read(voicePlaybackDurationProvider.notifier).state =
        null;
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
  }

  Future<void> play({
    required String path,
    String? messageId,
  }) async {
    final hasPath = path.isNotEmpty;
    final pathLen = path.length;
    PttLogger.log(
      '[ChatVoicePlayer]',
      'play requested',
      meta: <String, Object?>{
        'hasPath': hasPath,
        'pathLen': pathLen,
        'messageId': messageId ?? '(none)',
      },
    );

    if (!hasPath) {
      return;
    }

    _resetProgress();

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
        PttLogger.log(
          '[ChatVoicePlayer]',
          'global playing id changed',
          meta: <String, Object?>{
            'oldId': oldId ?? '(none)',
            'newId': messageId ?? '(none)',
          },
        );
      }
      PttLogger.log(
        '[ChatVoicePlayer]',
        'play start',
        meta: <String, Object?>{
          'hasPath': hasPath,
          'pathLen': pathLen,
          'messageId': messageId ?? '(none)',
        },
      );
      final startedAt = DateTime.now();

      _durationSub =
          _localAudio.playbackDurationStream.listen(
        (d) {
          _ref
              .read(
                voicePlaybackDurationProvider.notifier,
              )
              .state = d;
        },
      );
      _positionSub =
          _localAudio.playbackPositionStream.listen(
        (pos) {
          _ref
              .read(
                voicePlaybackPositionProvider.notifier,
              )
              .state = pos;
        },
      );

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

      PttLogger.log(
        '[ChatVoicePlayer]',
        'play completed',
        meta: <String, Object?>{
          'hasPath': hasPath,
          'pathLen': pathLen,
          'messageId': messageId ?? '(none)',
          'durationMillis': effectiveDurationMillis,
        },
      );
    } catch (e) {
      PttLogger.log(
        '[ChatVoicePlayer]',
        'play error',
        meta: <String, Object?>{
          'hasPath': hasPath,
          'pathLen': pathLen,
          'messageId': messageId ?? '(none)',
          'error': e.toString(),
        },
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
        _resetProgress();
        final globalNotifier =
            _ref.read(currentPlayingVoiceMessageIdProvider.notifier);
        final oldId = globalNotifier.state;
        if (oldId != null) {
          globalNotifier.state = null;
          PttLogger.log(
            '[ChatVoicePlayer]',
            'global playing id changed',
            meta: <String, Object?>{
              'oldId': oldId,
              'newId': '(none)',
            },
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
    final pathLen = path.length;

    final stateBefore = !hasPath
        ? VoicePlayState.error
        : (currentId == messageId
            ? VoicePlayState.playing
            : VoicePlayState.idle);
    final isPlayingBefore = stateBefore == VoicePlayState.playing;

    PttLogger.log(
      '[ChatVoicePlayer]',
      'tap',
      meta: <String, Object?>{
        'messageId': messageId,
        'isPlayingBefore': isPlayingBefore,
        'hasPath': hasPath,
        'pathLen': pathLen,
      },
    );

    if (!hasPath) {
      // TODO: handle VoicePlayState.error tap (e.g. surface retry UI).
      return;
    }

    if (currentId == messageId) {
      try {
        await _localAudio.stopPlayback();
        PttLogger.log(
          '[ChatVoicePlayer]',
          'stop requested',
          meta: <String, Object?>{
            'messageId': messageId,
          },
        );
      } catch (e) {
        PttLogger.log(
          '[ChatVoicePlayer]',
          'stop error',
          meta: <String, Object?>{
            'messageId': messageId,
            'error': e.toString(),
          },
        );
      } finally {
        final globalNotifier =
            _ref.read(currentPlayingVoiceMessageIdProvider.notifier);
        final oldId = globalNotifier.state;
        if (oldId != null) {
          globalNotifier.state = null;
          PttLogger.log(
            '[ChatVoicePlayer]',
            'global playing id changed',
            meta: <String, Object?>{
              'oldId': oldId,
              'newId': '(none)',
            },
          );
        }
      }
      _resetProgress();
      return;
    }

    await play(path: path, messageId: messageId);
  }
}

final chatVoicePlayerProvider = Provider<ChatVoicePlayer>((ref) {
  final engine = ref.read(pttLocalAudioEngineProvider);
  final player = ChatVoicePlayer(ref, engine);
  ref.onDispose(player.dispose);
  return player;
});
