import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/feature_flags.dart';

enum PttUiEventType {
  holdTooShort,
  cooldownBlocked,
  rateLimitSoft,
  friendBlocked,
  friendNotAllowWalkie,
  mannerModeNoInstantPtt,
  micPermissionMissing,
  fgsError,
  genericError,
  abuseReported,
  info,
}

class PttUiEvent {
  const PttUiEvent({
    required this.type,
    required this.messageKey,
    required this.meta,
    required this.at,
  });

  final PttUiEventType type;
  final String messageKey;
  final Map<String, Object?> meta;
  final DateTime at;
}

class PttUiEventNotifier extends StateNotifier<PttUiEvent?> {
  PttUiEventNotifier() : super(null);

  void emit(PttUiEvent event) {
    state = event;
  }

  void clear() {
    state = null;
  }
}

final pttUiEventProvider =
    StateNotifierProvider<PttUiEventNotifier, PttUiEvent?>(
  (ref) => PttUiEventNotifier(),
);

typedef PttUiEventSink = void Function(PttUiEvent event);

class PttUiEventBus {
  static PttUiEventSink? _sink;

  static void attach(PttUiEventSink sink) {
    _sink = sink;
  }

  static void emit(PttUiEvent event) {
    final sink = _sink;
    if (sink != null) {
      sink(event);
    }
  }
}

class PttUiMessageKeys {
  static const String holdTooShort = 'ptt.holdTooShort';
  static const String cooldownBlocked = 'ptt.cooldownBlocked';
  static const String rateLimitSoft = 'ptt.rateLimitSoft';
  static const String friendBlocked = 'ptt.friendBlocked';
  static const String friendNotAllowWalkie = 'ptt.friendNotAllowWalkie';
   static const String mannerModeNoInstantPtt =
       'ptt.mannerModeNoInstantPtt';
  static const String noFriendSelected = 'ptt.noFriendSelected';
  static const String micPermissionMissing = 'ptt.micPermissionMissing';
  static const String fgsError = 'ptt.fgsError';
  static const String genericError = 'ptt.genericError';
  static const String abuseReported = 'ptt.abuseReported';
  static const String info = 'ptt.info';
}

class PttUiEvents {
  static PttUiEvent holdTooShort({
    String? friendId,
    PttMode? mode,
  }) {
    return PttUiEvent(
      type: PttUiEventType.holdTooShort,
      messageKey: PttUiMessageKeys.holdTooShort,
      meta: <String, Object?>{
        if (friendId != null) 'friendId': friendId,
        if (mode != null) 'mode': mode.name,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent cooldownBlocked({
    String? friendId,
    int? sinceLastMs,
    int? minIntervalMs,
    PttMode? mode,
  }) {
    return PttUiEvent(
      type: PttUiEventType.cooldownBlocked,
      messageKey: PttUiMessageKeys.cooldownBlocked,
      meta: <String, Object?>{
        if (friendId != null) 'friendId': friendId,
        if (sinceLastMs != null) 'sinceLastMs': sinceLastMs,
        if (minIntervalMs != null) 'minIntervalMs': minIntervalMs,
        if (mode != null) 'mode': mode.name,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent rateLimitSoft({
    required String friendId,
    required int count,
    required int windowSeconds,
  }) {
    return PttUiEvent(
      type: PttUiEventType.rateLimitSoft,
      messageKey: PttUiMessageKeys.rateLimitSoft,
      meta: <String, Object?>{
        'friendId': friendId,
        'count': count,
        'windowSeconds': windowSeconds,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent friendBlocked({
    String? friendId,
  }) {
    return PttUiEvent(
      type: PttUiEventType.friendBlocked,
      messageKey: PttUiMessageKeys.friendBlocked,
      meta: <String, Object?>{
        'friendId': friendId ?? '(none)',
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent friendNotAllowWalkie({
    required String friendId,
  }) {
    return PttUiEvent(
      type: PttUiEventType.friendNotAllowWalkie,
      messageKey: PttUiMessageKeys.friendNotAllowWalkie,
      meta: <String, Object?>{
        'friendId': friendId,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent mannerModeNoInstantPtt({
    String? friendId,
  }) {
    return PttUiEvent(
      type: PttUiEventType.mannerModeNoInstantPtt,
      messageKey: PttUiMessageKeys.mannerModeNoInstantPtt,
      meta: <String, Object?>{
        if (friendId != null) 'friendId': friendId,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent noFriendSelected({
    PttMode? mode,
  }) {
    return PttUiEvent(
      type: PttUiEventType.info,
      messageKey: PttUiMessageKeys.noFriendSelected,
      meta: <String, Object?>{
        if (mode != null) 'mode': mode.name,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent micPermissionMissing() {
    return PttUiEvent(
      type: PttUiEventType.micPermissionMissing,
      messageKey: PttUiMessageKeys.micPermissionMissing,
      meta: const <String, Object?>{},
      at: DateTime.now(),
    );
  }

  static PttUiEvent fgsError() {
    return PttUiEvent(
      type: PttUiEventType.fgsError,
      messageKey: PttUiMessageKeys.fgsError,
      meta: const <String, Object?>{},
      at: DateTime.now(),
    );
  }

  static PttUiEvent abuseReported({
    String? friendId,
  }) {
    return PttUiEvent(
      type: PttUiEventType.abuseReported,
      messageKey: PttUiMessageKeys.abuseReported,
      meta: <String, Object?>{
        if (friendId != null) 'friendId': friendId,
      },
      at: DateTime.now(),
    );
  }

  static PttUiEvent genericError({
    String? code,
  }) {
    return PttUiEvent(
      type: PttUiEventType.genericError,
      messageKey: PttUiMessageKeys.genericError,
      meta: <String, Object?>{
        if (code != null) 'code': code,
      },
      at: DateTime.now(),
    );
  }
}
