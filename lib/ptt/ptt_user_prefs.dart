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

