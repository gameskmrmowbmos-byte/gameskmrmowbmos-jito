import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_exception.dart';
import 'package:matka_management/features/auth/data/models/access_status.dart';
import 'package:matka_management/features/auth/data/models/auth_user.dart';
import 'package:matka_management/features/auth/data/repositories/auth_repository.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.accessStatus,
    this.error,
  });

  const AuthState.initializing()
      : status = AuthStatus.initializing,
        user = null,
        accessStatus = null,
        error = null;

  final AuthStatus status;
  final AuthUser? user;
  final AccessStatus? accessStatus;
  final String? error;

  bool get hasAccessRestriction =>
      status == AuthStatus.authenticated && accessStatus?.allowed == false;
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.read(authRepositoryProvider));
  ref.listen<int>(authExpiredSignalProvider, (_, __) {
    controller.expireSession();
  });
  controller.initialize();
  return controller;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.initializing());

  final AuthRepository _repository;

  Future<void> initialize() async {
    try {
      final hasRefreshSession = await _repository.hasRefreshSession();
      if (!hasRefreshSession) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final user = await _repository.refresh();
      final access = await _repository.accessStatus();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        accessStatus: access,
      );
    } on Object {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String identifier, String password) async {
    state = const AuthState.initializing();
    try {
      final loginResult = await _repository.login(
        identifier: identifier,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: loginResult.user,
        accessStatus: loginResult.accessStatus,
      );
    } on Object catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _loginErrorMessage(error),
      );
      rethrow;
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is ApiException &&
        (error.code == 'connectionTimeout' ||
            error.code == 'receiveTimeout' ||
            error.code == 'sendTimeout')) {
      return 'The server is taking longer to start. Please try signing in again shortly.';
    }
    return error.toString();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> refreshAccessStatus() async {
    if (state.status != AuthStatus.authenticated) return;
    final access = await _repository.accessStatus();
    state = AuthState(
      status: state.status,
      user: state.user,
      accessStatus: access,
      error: state.error,
    );
  }

  void expireSession() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Session expired. Please login again.',
    );
  }
}
