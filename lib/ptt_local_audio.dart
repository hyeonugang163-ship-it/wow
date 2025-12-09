// NOTE: 설계도 v1.1 기준 로컬 오디오 엔진 역할을 하며, 녹음/재생을 PTT/Manner 공통으로 제공한다.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:voyage/ptt_ui_event.dart';

class PttLocalAudioEngine {
  PttLocalAudioEngine()
      : _recorder = AudioRecorder(),
        _player = AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;

  bool _initialized = false;
  bool _hasEmittedMicPermissionMissing = false;

  /// Absolute path for the current recording file, if any.
  String? _currentFilePath;

  /// Duration of the last successfully prepared playback, if any.
  Duration? _lastPlaybackDuration;

  int? get lastPlaybackDurationMillis =>
      _lastPlaybackDuration?.inMilliseconds;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!_isSupportedPlatform) {
      debugPrint(
        '[PTT][LocalAudio] init skipped: unsupported platform',
      );
      return;
    }
    if (_initialized) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint(
          '[PTT][LocalAudio] no microphone permission on init',
        );
        if (!_hasEmittedMicPermissionMissing) {
          _hasEmittedMicPermissionMissing = true;
          PttUiEventBus.emit(PttUiEvents.micPermissionMissing());
        }
      }
    } catch (e) {
      debugPrint('[PTT][LocalAudio] init error: $e');
    }

    _initialized = true;
  }

  Future<void> startRecording() async {
    if (!_isSupportedPlatform) {
      debugPrint(
        '[PTT][LocalAudio] startRecording skipped: unsupported platform',
      );
      return;
    }

    try {
      if (!_initialized) {
        await init();
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint(
          '[PTT][Permission] microphone not granted on startRecording',
        );
        if (!_hasEmittedMicPermissionMissing) {
          _hasEmittedMicPermissionMissing = true;
          PttUiEventBus.emit(PttUiEvents.micPermissionMissing());
        }
        _currentFilePath = null;
        return;
      }

      final isRecording = await _recorder.isRecording();
      if (isRecording) {
        await _recorder.stop();
      }

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 16000,
      );

	      // Use an app-internal writable directory for recordings.
	      final baseDir = await getTemporaryDirectory();
	      final recordingsDir = Directory('${baseDir.path}/ptt');
	      try {
	        if (!recordingsDir.existsSync()) {
	          await recordingsDir.create(recursive: true);
	        }
	      } catch (e) {
	        debugPrint(
	          '[PTT][LocalAudio] failed to create recordingsDir: $e',
	        );
	        _currentFilePath = null;
	        return;
	      }

      final fileName =
          'ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final fullPath = '${recordingsDir.path}/$fileName';

      _currentFilePath = fullPath;

      // Log file name only, avoiding full path in logs.
      debugPrint(
        '[PTT][LocalAudio] startRecording file=$fileName',
      );

      await _recorder.start(config, path: fullPath);
    } catch (e) {
      debugPrint('[PTT][LocalAudio] startRecording error: $e');
      _currentFilePath = null;
    }
  }

  Future<String?> stopRecordingAndGetPath() async {
    if (!_isSupportedPlatform) {
      debugPrint(
        '[PTT][LocalAudio] stopRecording skipped: unsupported platform',
      );
      return null;
    }

    if (_currentFilePath == null) {
      // Nothing to stop / no known file path.
      try {
        await _recorder.stop();
      } catch (_) {
        // ignore
      }
      debugPrint(
        '[PTT][LocalAudio] stopRecording: no current file path',
      );
      return null;
    }

    try {
      // Stop the recorder; we ignore the returned path and use our own.
      await _recorder.stop();

      final path = _currentFilePath;
      _currentFilePath = null;

	      if (path == null || path.isEmpty) {
	        debugPrint(
	          '[PTT][LocalAudio] stopRecording: no path '
	          '(maybe permission denied or encoder error)',
	        );
	        return null;
	      }
      debugPrint(
        '[PTT][LocalAudio] stopRecordingAndGetPath hasPath=true',
      );
      return path;
    } catch (e) {
      debugPrint('[PTT][LocalAudio] stopRecording error: $e');
      _currentFilePath = null;
      return null;
    }
  }

  Future<void> playFromPath(
    String path, {
    bool rethrowOnError = false,
  }) async {
    if (!_isSupportedPlatform) {
      debugPrint(
        '[PTT][LocalAudio] playFromPath skipped: unsupported platform',
      );
      return;
    }

    _lastPlaybackDuration = null;

    try {
      await _player.stop();
      await _player.setFilePath(path);
      _lastPlaybackDuration = _player.duration;
      await _player.play();
    } catch (e) {
      debugPrint('[PTT][LocalAudio] playFromPath error: $e');
      if (rethrowOnError) {
        rethrow;
      }
    }
  }

  Future<void> stopPlayback() async {
    if (!_isSupportedPlatform) {
      debugPrint(
        '[PTT][LocalAudio] stopPlayback skipped: unsupported platform',
      );
      return;
    }

    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[PTT][LocalAudio] stopPlayback error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('[PTT][LocalAudio] dispose error: $e');
    }
  }
}
