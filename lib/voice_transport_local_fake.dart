import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import 'voice_transport.dart';

/// 네트워크 없이 로컬에서만 녹음/재생을 테스트하기 위한
/// Local Fake 구현.
class LocalFakeVoiceTransport implements VoiceTransport {
  LocalFakeVoiceTransport()
      : _recorder = FlutterSoundRecorder(),
        _player = FlutterSoundPlayer();

  final FlutterSoundRecorder _recorder;
  final FlutterSoundPlayer _player;

  bool _isOpened = false;
  bool _isConnected = false;
  String? _filePath;

  @override
  Stream<List<int>> get incomingOpus => const Stream.empty();

  @override
  Future<void> warmUp() async {
    print('[PTT][LocalFakeVoiceTransport] warmUp() called');
    if (_isOpened) {
      return;
    }
    await _recorder.openRecorder();
    await _player.openPlayer();
    _isOpened = true;
  }

  @override
  Future<void> connect({required String url, required String token}) async {
    print('[PTT][LocalFakeVoiceTransport] connect() called');
    _isConnected = true;
  }

  @override
  Future<void> startPublishing(Stream<List<int>> opus) async {
    print('[PTT][LocalFakeVoiceTransport] startPublishing() called');
    if (!_isOpened) {
      await warmUp();
    }
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/local_ptt.aac');
    _filePath = file.path;

    await _recorder.startRecorder(
      toFile: _filePath,
      codec: Codec.aacADTS,
    );
  }

  @override
  Future<void> stopPublishing() async {
    print('[PTT][LocalFakeVoiceTransport] stopPublishing() called');
    if (!_isOpened) {
      return;
    }
    await _recorder.stopRecorder();

    final path = _filePath;
    if (path != null) {
      await _player.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    print('[PTT][LocalFakeVoiceTransport] disconnect() called');
    _isConnected = false;
  }

  @override
  Future<void> coolDown() async {
    print('[PTT][LocalFakeVoiceTransport] coolDown() called');
    if (!_isOpened) {
      return;
    }
    await _recorder.closeRecorder();
    await _player.closePlayer();
    _isOpened = false;
  }
}

