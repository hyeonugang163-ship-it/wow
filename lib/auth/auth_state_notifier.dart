import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/backend/backend_providers.dart';
import 'package:voyage/backend/repositories.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_ui_event.dart';

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._repository, this._ref)
      : super(AuthState.unknown) {
    _loadInitial();
  }

  final AuthRepository _repository;
  final Ref _ref;

  final StreamController<AuthState> _stateStreamController =
      StreamController<AuthState>.broadcast();

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
