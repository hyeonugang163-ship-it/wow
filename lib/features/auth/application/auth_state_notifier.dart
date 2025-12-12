import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/app/app_env.dart';
import 'package:voyage/features/auth/application/auth_state.dart';
import 'package:voyage/services/backend/backend_providers.dart';
import 'package:voyage/services/backend/repositories.dart';
import 'package:voyage/features/ptt/data/ptt_prefs.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';
import 'package:voyage/features/ptt/application/ptt_ui_event.dart';

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._repository, this._ref)
      : super(AuthState.unknown) {
    _loadInitial();
  }

  final AuthRepository _repository;
  final Ref _ref;

  final StreamController<AuthState> _stateStreamController =
      StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get stream => _stateStreamController.stream;

  @override
  set state(AuthState value) {
    super.state = value;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(value);
    }
  }

  @override
  void dispose() {
    _stateStreamController.close();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final next = await _repository.loadInitialAuthState();
      PttLogger.log(
        '[Auth]',
        'loadInitialAuthState completed',
        meta: <String, Object?>{
          'status': next.status.name,
          'hasUser': next.user != null,
        },
      );
      state = next;
    } catch (e) {
      PttLogger.log(
        '[Auth]',
        'loadInitialAuthState error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      state = state.copyWith(
        status: AuthStatus.signedOut,
        isLoading: false,
        lastErrorCode: 'auth_initial_error',
      );
      _ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.genericError(code: 'auth_initial_error'),
          );
    }
  }

  Future<void> refreshAuth() async {
    await _loadInitial();
  }

  Future<void> completeOnboarding(
    String displayName,
    String avatarEmoji,
  ) async {
    state = state.copyWith(isLoading: true, lastErrorCode: null);
    try {
      final next =
          await _repository.completeOnboarding(displayName, avatarEmoji);
      state = next;
      final prefs = _ref.read(pttPrefsProvider);
      final userId = next.user?.id ?? 'user_local';
      await prefs.saveUserProfile(
        userId: userId,
        displayName: displayName,
        avatarEmoji: avatarEmoji,
      );
      await prefs.saveOnboardingCompleted(true);
      try {
        final firebaseAuthClient =
            _ref.read(firebaseAuthClientProvider);
        final uid =
            await firebaseAuthClient.signInAnonymouslyAndGetUid();
        final sharedPrefs = _ref.read(sharedPrefsProvider);
        await sharedPrefs.setString('firebase_uid', uid);
        debugPrint(
          '[Firebase][Auth] firebase_uid saved to SharedPreferences',
        );
        try {
          final envName = AppEnv.currentName;
          final userProfileRepo =
              _ref.read(firebaseUserProfileRepositoryProvider);
          await userProfileRepo.upsertUserProfile(
            uid: uid,
            appEnv: envName,
            platform: 'android',
          );
        } catch (e, st) {
          debugPrint(
            '[Firebase][UserProfile] upsert error: $e',
          );
          debugPrint(st.toString());
        }
      } catch (e, st) {
        debugPrint(
          '[Firebase][Auth] signInAnonymously error: $e',
        );
        debugPrint(st.toString());
      }
    } catch (e) {
      PttLogger.log(
        '[Auth]',
        'completeOnboarding error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      state = state.copyWith(
        isLoading: false,
        lastErrorCode: 'auth_onboarding_error',
      );
      _ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.genericError(code: 'auth_onboarding_error'),
          );
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } catch (e) {
      PttLogger.log(
        '[Auth]',
        'signOut error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
    }
    try {
      final prefs = _ref.read(pttPrefsProvider);
      await prefs.saveOnboardingCompleted(false);
    } catch (_) {
      // ignore prefs errors on sign-out
    }
    state = const AuthState(
      status: AuthStatus.onboarding,
      user: null,
      isLoading: false,
    );
  }
}

final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) {
    final repo = ref.read(authRepositoryProvider);
    return AuthStateNotifier(repo, ref);
  },
);
