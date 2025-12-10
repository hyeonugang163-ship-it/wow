import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/backend/api_result.dart';
import 'package:voyage/backend/auth_api.dart';
import 'package:voyage/backend/chat_api.dart';
import 'package:voyage/backend/friend_api.dart';
import 'package:voyage/backend/ptt_media_api.dart';
import 'package:voyage/auth/app_user.dart';
import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/friend.dart';
import 'package:voyage/ptt/ptt_prefs.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_ui_event.dart';

abstract class AuthRepository {
  Future<AuthState> loadInitialAuthState();

  Future<AuthState> completeOnboarding(
    String displayName,
    String avatarEmoji,
  );

  Future<void> signOut();
}

abstract class FriendRepository {
  Future<List<Friend>> loadFriends();

  Future<void> syncPttAllow(String friendId, bool allow);

  /// 친구별 무전 허용 여부를 설정한다.
  ///
  /// 현재는 Fake/로컬 구현에서만 사용되며,
  /// 추후 실제 서버 동기화 시 연동될 수 있다.
  Future<void> setWalkieAllowed({
    required String friendId,
    required bool allowed,
  });

  Future<void> block(String friendId);

  Future<void> unblock(String friendId);
}

abstract class ChatRepository {
  Future<List<ChatMessage>> loadMessages(String chatId);

  Future<ChatMessage> sendText(String chatId, String text);

  Future<ChatMessage> sendVoice(
    String chatId,
    String localPath,
    int durationMillis,
  );
}

abstract class PttMediaRepository {
  Future<String> uploadVoice(
    String localPath, {
    String? chatId,
    String? friendId,
  });

  Future<String> resolvePlaybackUrl(String remoteKey);
}

void _logApiError(String scope, ApiError error) {
  PttLogger.log(
    '[Backend][Repository][Error]',
    scope,
    meta: <String, Object?>{
      'type': error.type.name,
      if (error.statusCode != null) 'statusCode': error.statusCode!,
      if (error.code != null) 'code': error.code!,
    },
  );
}

void _emitGenericError(Ref ref, {String? code}) {
  ref.read(pttUiEventProvider.notifier).emit(
        PttUiEvents.genericError(code: code),
      );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._api, this._ref);

  final AuthApi _api;
  final Ref _ref;

  static AppUser? _cachedUser;

  @override
  Future<AuthState> loadInitialAuthState() async {
    final prefs = _ref.read(pttPrefsProvider);
    final bool onboardingCompleted =
        prefs.loadOnboardingCompleted();
    final existing = _cachedUser;
    if (existing != null) {
      PttLogger.log(
        '[Auth]',
        'loadInitialAuthState existing user',
        meta: <String, Object?>{
          'userId': existing.id,
        },
      );
      return AuthState(
        status: AuthStatus.signedIn,
        user: existing,
        isLoading: false,
      );
    }

    if (onboardingCompleted) {
      final userId =
          prefs.loadUserId() ?? 'user_local';
      final displayName =
          prefs.loadDisplayName() ?? 'User';
      final avatarEmoji =
          prefs.loadAvatarEmoji() ?? '😄';

      final user = AppUser(
        id: userId,
        displayName: displayName,
        avatarEmoji: avatarEmoji,
        createdAt: DateTime.now(),
      );
      _cachedUser = user;

      PttLogger.log(
        '[Auth]',
        'loadInitialAuthState from prefs (onboardingCompleted=true)',
        meta: <String, Object?>{
          'userId': userId,
        },
      );

      return AuthState(
        status: AuthStatus.signedIn,
        user: user,
        isLoading: false,
      );
    }

    PttLogger.log(
      '[Auth]',
      'loadInitialAuthState no user, onboarding',
    );

    return const AuthState(
      status: AuthStatus.onboarding,
      user: null,
      isLoading: false,
    );
  }

  @override
  Future<AuthState> completeOnboarding(
    String displayName,
    String avatarEmoji,
  ) async {
    PttLogger.log(
      '[Auth]',
      'completeOnboarding start',
      meta: <String, Object?>{
        'displayNameLen': displayName.length,
      },
    );

    final String deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final result = await _api.loginWithToken(deviceId);
      final error = result.error;
      if (error != null) {
        _logApiError('AuthRepository.completeOnboarding.login', error);
        _emitGenericError(_ref, code: error.code);
      }
    } catch (e) {
      _logApiError(
        'AuthRepository.completeOnboarding.login.exception',
        const ApiError(type: ApiErrorType.unknown),
      );
      _emitGenericError(_ref, code: 'auth_login_exception');
      PttLogger.log(
        '[Auth]',
        'completeOnboarding login exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
    }

    final now = DateTime.now();
    final user = AppUser(
      id: 'user_$deviceId',
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      createdAt: now,
    );
    _cachedUser = user;

    PttLogger.log(
      '[Auth]',
      'completeOnboarding success',
      meta: <String, Object?>{
        'userId': user.id,
      },
    );

    return AuthState(
      status: AuthStatus.signedIn,
      user: user,
      isLoading: false,
    );
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    PttLogger.log(
      '[Auth]',
      'signOut',
    );
  }
}

class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository(this._api, this._ref);

  final FriendApi _api;
  final Ref _ref;

  @override
  Future<List<Friend>> loadFriends() async {
    final result = await _api.fetchFriends();
    final error = result.error;
    if (error != null) {
      _logApiError('FriendRepository.loadFriends', error);
      _emitGenericError(_ref, code: error.code);
      return <Friend>[];
    }
    return result.data ?? <Friend>[];
  }

  @override
  Future<void> syncPttAllow(String friendId, bool allow) async {
    // 기존 API 호출은 그대로 유지하되,
    // 상위에서 setWalkieAllowed를 통해 접근하는 것을 권장한다.
    final result = await _api.updateFriendPttAllow(friendId, allow);
    final error = result.error;
    if (error != null) {
      _logApiError('FriendRepository.syncPttAllow', error);
      _emitGenericError(_ref, code: error.code);
    }
  }

  @override
  Future<void> setWalkieAllowed({
    required String friendId,
    required bool allowed,
  }) async {
    await syncPttAllow(friendId, allowed);
  }

  @override
  Future<void> block(String friendId) async {
    final result = await _api.blockFriend(friendId);
    final error = result.error;
    if (error != null) {
      _logApiError('FriendRepository.block', error);
      _emitGenericError(_ref, code: error.code);
    }
  }

  @override
  Future<void> unblock(String friendId) async {
    final result = await _api.unblockFriend(friendId);
    final error = result.error;
    if (error != null) {
      _logApiError('FriendRepository.unblock', error);
      _emitGenericError(_ref, code: error.code);
    }
  }
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository(this._api, this._ref);

  final ChatApi _api;
  final Ref _ref;

  @override
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    final result = await _api.fetchMessages(chatId);
    final error = result.error;
    if (error != null) {
      _logApiError('ChatRepository.loadMessages', error);
      _emitGenericError(_ref, code: error.code);
      return <ChatMessage>[];
    }
    return result.data ?? <ChatMessage>[];
  }

  @override
  Future<ChatMessage> sendText(String chatId, String text) async {
    final result = await _api.sendTextMessage(chatId, text);
    final error = result.error;
    if (error != null) {
      _logApiError('ChatRepository.sendText', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception('ChatRepository.sendText failed: ${error.type}');
    }
    return result.data!;
  }

  @override
  Future<ChatMessage> sendVoice(
    String chatId,
    String localPath,
    int durationMillis,
  ) async {
    final result =
        await _api.sendVoiceMessage(chatId, localPath, durationMillis);
    final error = result.error;
    if (error != null) {
      _logApiError('ChatRepository.sendVoice', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception('ChatRepository.sendVoice failed: ${error.type}');
    }
    return result.data!;
  }
}

class FakePttMediaRepository implements PttMediaRepository {
  FakePttMediaRepository(this._api, this._ref);

  final PttMediaApi _api;
  final Ref _ref;

  @override
  Future<String> uploadVoice(
    String localPath, {
    String? chatId,
    String? friendId,
  }) async {
    final result = await _api.uploadVoiceFile(localPath);
    final error = result.error;
    if (error != null) {
      _logApiError('PttMediaRepository.uploadVoice', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception('PttMediaRepository.uploadVoice failed: ${error.type}');
    }

    PttLogger.log(
      '[Backend][Repository][PttMedia]',
      'uploadVoice',
      meta: <String, Object?>{
        'localPathHash': localPath.hashCode,
        if (chatId != null) 'chatIdHash': chatId.hashCode,
        if (friendId != null) 'friendIdHash': friendId.hashCode,
      },
    );

    return result.data!;
  }

  @override
  Future<String> resolvePlaybackUrl(String remoteKey) async {
    final result = await _api.getSignedUrl(remoteKey);
    final error = result.error;
    if (error != null) {
      _logApiError('PttMediaRepository.resolvePlaybackUrl', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception(
        'PttMediaRepository.resolvePlaybackUrl failed: ${error.type}',
      );
    }
    return result.data!;
  }
}

class RealFriendRepository implements FriendRepository {
  RealFriendRepository(this._api, this._ref);

  final FriendApi _api;
  final Ref _ref;

  @override
  Future<List<Friend>> loadFriends() async {
    final result = await _api.fetchFriends();
    final error = result.error;
    if (error != null) {
      _logApiError('RealFriendRepository.loadFriends', error);
      _emitGenericError(_ref, code: error.code);
      return <Friend>[];
    }
    return result.data ?? <Friend>[];
  }

  @override
  Future<void> syncPttAllow(String friendId, bool allow) async {
    // 기존 API 호출은 그대로 유지하되,
    // 상위에서 setWalkieAllowed를 통해 접근하는 것을 권장한다.
    final result = await _api.updateFriendPttAllow(friendId, allow);
    final error = result.error;
    if (error != null) {
      _logApiError('RealFriendRepository.syncPttAllow', error);
      _emitGenericError(_ref, code: error.code);
    }
  }

  @override
  Future<void> setWalkieAllowed({
    required String friendId,
    required bool allowed,
  }) async {
    await syncPttAllow(friendId, allowed);
  }

  @override
  Future<void> block(String friendId) async {
    final result = await _api.blockFriend(friendId);
    final error = result.error;
    if (error != null) {
      _logApiError('RealFriendRepository.block', error);
      _emitGenericError(_ref, code: error.code);
    }
  }

  @override
  Future<void> unblock(String friendId) async {
    final result = await _api.unblockFriend(friendId);
    final error = result.error;
    if (error != null) {
      _logApiError('RealFriendRepository.unblock', error);
      _emitGenericError(_ref, code: error.code);
    }
  }
}

class RealChatRepository implements ChatRepository {
  RealChatRepository(this._api, this._ref);

  final ChatApi _api;
  final Ref _ref;

  @override
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    final result = await _api.fetchMessages(chatId);
    final error = result.error;
    if (error != null) {
      _logApiError('RealChatRepository.loadMessages', error);
      _emitGenericError(_ref, code: error.code);
      return <ChatMessage>[];
    }
    return result.data ?? <ChatMessage>[];
  }

  @override
  Future<ChatMessage> sendText(String chatId, String text) async {
    debugPrint(
      '[FirestoreChatRepository] try sendText '
      'chatId=$chatId textLength=${text.length}',
    );
    final result = await _api.sendTextMessage(chatId, text);
    final error = result.error;
    if (error != null) {
      debugPrint(
        '[FirestoreChatRepository] sendText error: ${error.type.name}',
      );
      _logApiError('RealChatRepository.sendText', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception(
        'RealChatRepository.sendText failed: ${error.type}',
      );
    }
    final ChatMessage message = result.data!;
    debugPrint(
      '[FirestoreChatRepository] sendText success docId=${message.id} '
      'fromUid=${message.fromUid ?? 'null'}',
    );
    return message;
  }

  @override
  Future<ChatMessage> sendVoice(
    String chatId,
    String localPath,
    int durationMillis,
  ) async {
    debugPrint(
      '[FirestoreChatRepository] try sendVoice '
      'chatId=$chatId pathHash=${localPath.hashCode} '
      'durationMillis=$durationMillis',
    );
    final result = await _api.sendVoiceMessage(
      chatId,
      localPath,
      durationMillis,
    );
    final error = result.error;
    if (error != null) {
      debugPrint(
        '[FirestoreChatRepository] sendVoice error: ${error.type.name}',
      );
      _logApiError('RealChatRepository.sendVoice', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception(
        'RealChatRepository.sendVoice failed: ${error.type}',
      );
    }
    final ChatMessage message = result.data!;
    debugPrint(
      '[FirestoreChatRepository] sendVoice success docId=${message.id} '
      'fromUid=${message.fromUid ?? 'null'}',
    );
    return message;
  }
}

class RealPttMediaRepository implements PttMediaRepository {
  RealPttMediaRepository(this._api, this._ref);

  final PttMediaApi _api;
  final Ref _ref;

  @override
  Future<String> uploadVoice(
    String localPath, {
    String? chatId,
    String? friendId,
  }) async {
    final result = await _api.uploadVoiceFile(localPath);
    final error = result.error;
    if (error != null) {
      _logApiError('RealPttMediaRepository.uploadVoice', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception(
        'RealPttMediaRepository.uploadVoice failed: ${error.type}',
      );
    }
    return result.data!;
  }

  @override
  Future<String> resolvePlaybackUrl(String remoteKey) async {
    final result = await _api.getSignedUrl(remoteKey);
    final error = result.error;
    if (error != null) {
      _logApiError('RealPttMediaRepository.resolvePlaybackUrl', error);
      _emitGenericError(_ref, code: error.code);
      throw Exception(
        'RealPttMediaRepository.resolvePlaybackUrl failed: ${error.type}',
      );
    }
    return result.data!;
  }
}

/// NOTE: RealAuthRepository는 아직 실제 서버/토큰 연동이 구현되지 않았다.
/// Android/Windows 환경에서 FakeAuthRepository만 사용하며,
/// iOS/macOS + 실제 백엔드 환경에서 구현/검증이 필요하다.
class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._api, this._ref);

  final AuthApi _api;
  final Ref _ref;

  @override
  Future<AuthState> loadInitialAuthState() async {
    PttLogger.log(
      '[Auth]',
      'RealAuthRepository.loadInitialAuthState (stub)',
      meta: <String, Object?>{
        'apiType': _api.runtimeType.toString(),
      },
    );
    return const AuthState(
      status: AuthStatus.signedOut,
      user: null,
      isLoading: false,
    );
  }

  @override
  Future<AuthState> completeOnboarding(
    String displayName,
    String avatarEmoji,
  ) async {
    PttLogger.log(
      '[Auth]',
      'RealAuthRepository.completeOnboarding (stub)',
      meta: <String, Object?>{
        'displayNameLen': displayName.length,
        'apiType': _api.runtimeType.toString(),
      },
    );
    _emitGenericError(_ref, code: 'real_auth_not_implemented');
    return const AuthState(
      status: AuthStatus.signedOut,
      user: null,
      isLoading: false,
      lastErrorCode: 'real_auth_not_implemented',
    );
  }

  @override
  Future<void> signOut() async {
    PttLogger.log(
      '[Auth]',
      'RealAuthRepository.signOut (stub)',
    );
  }
}
