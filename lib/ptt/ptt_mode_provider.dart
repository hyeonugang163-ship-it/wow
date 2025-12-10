import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt/ptt_prefs.dart';

class PttModeNotifier extends StateNotifier<PttMode> {
  PttModeNotifier(this._prefs) : super(_prefs.loadMode());

  final PttPrefs _prefs;

  void setMode(PttMode mode) {
    state = mode;
    _prefs.saveMode(mode);
  }

  void toggle() {
    final next =
        state == PttMode.walkie ? PttMode.manner : PttMode.walkie;
    state = next;
    _prefs.saveMode(next);
  }
}

final pttModeProvider =
    StateNotifierProvider<PttModeNotifier, PttMode>(
  (ref) {
    final prefs = ref.read(pttPrefsProvider);
    return PttModeNotifier(prefs);
  },
);
