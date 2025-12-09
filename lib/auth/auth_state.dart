import 'package:voyage/auth/app_user.dart';

enum AuthStatus {
  unknown,
  signedOut,
  onboarding,
  signedIn,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isLoading = false,
    this.lastErrorCode,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? lastErrorCode;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isLoading,
    String? lastErrorCode,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
    );
  }

  static const AuthState unknown = AuthState(
    status: AuthStatus.unknown,
    user: null,
    isLoading: true,
  );
}

