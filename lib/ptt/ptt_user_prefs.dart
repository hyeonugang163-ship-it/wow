import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-tunable PTT UX preferences (beep/vibration).
///
/// These are purely client-side options and do not require any
/// backend or external services.
final pttBeepOnStartProvider = StateProvider<bool>(
  (ref) => true,
);

final pttBeepOnEndProvider = StateProvider<bool>(
  (ref) => false,
);

final pttVibrateInWalkieProvider = StateProvider<bool>(
  (ref) => false,
);

/// Whether to play a short beep before auto-playing an incoming Walkie PTT.
///
/// Helps the receiver avoid being startled by sudden voice playback.
final pttBeepOnReceiveProvider = StateProvider<bool>(
  (ref) => true,
);

/// Whether to show the on-screen PTT debug overlay.
final pttDebugOverlayEnabledProvider = StateProvider<bool>(
  (ref) => false,
);

/// Whether to log verbose PTT debug lines to the console.
final pttVerboseLoggingEnabledProvider = StateProvider<bool>(
  (ref) => true,
);
