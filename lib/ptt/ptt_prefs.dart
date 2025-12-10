import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voyage/feature_flags.dart';

class PttPrefs {
  PttPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _modeKey = 'ptt.mode';
  static const String _friendAllowKey = 'ptt.friendAllow';
  static const String _friendBlockKey = 'ptt.friendBlock';

  PttMode loadMode() {
    final value = _prefs.getString(_modeKey);
    if (value == PttMode.walkie.name) {
      return PttMode.walkie;
    }
    return PttMode.manner;
  }

  Future<void> saveMode(PttMode mode) {
    return _prefs.setString(_modeKey, mode.name);
  }

  Map<String, bool> loadFriendAllowMap() {
    final raw = _prefs.getString(_friendAllowKey);
    if (raw == null || raw.isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value == true),
      );
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> saveFriendAllowMap(Map<String, bool> map) {
    final jsonString = jsonEncode(map);
    return _prefs.setString(_friendAllowKey, jsonString);
  }

  Map<String, bool> loadFriendBlockMap() {
    final raw = _prefs.getString(_friendBlockKey);
    if (raw == null || raw.isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value == true),
      );
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> saveFriendBlockMap(Map<String, bool> map) {
    final jsonString = jsonEncode(map);
    return _prefs.setString(_friendBlockKey, jsonString);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider must be overridden in main.dart',
  );
});

final pttPrefsProvider = Provider<PttPrefs>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return PttPrefs(prefs);
});

