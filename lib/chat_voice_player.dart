import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/ptt_local_audio.dart';

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
      await _localAudio.playFromPath(path);
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
}

final chatVoicePlayerProvider = Provider<ChatVoicePlayer>((ref) {
  final engine = ref.read(pttLocalAudioEngineProvider);
  return ChatVoicePlayer(ref, engine);
});

