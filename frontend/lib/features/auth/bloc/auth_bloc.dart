import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;

  AuthBloc({required ApiService apiService})
      : _apiService = apiService,
        super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<LoginRequested>(_onLoginRequested);
    on<SignupRequested>(_onSignupRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await ApiService.loadPersistedToken();
    if (ApiService.isAuthenticated) {
      try {
        final response = await _apiService.getMe();
        emit(AuthAuthenticated(user: response.data));
      } catch (e) {
        ApiService.setToken(null);
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.login(event.email, event.password);
      final meResponse = await _apiService.getMe();
      emit(AuthAuthenticated(user: meResponse.data));
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? "Login failed. Check credentials.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignupRequested(SignupRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.signup(event.email, event.password, event.fullName);
      // Auto login after signup
      await _apiService.login(event.email, event.password);
      final meResponse = await _apiService.getMe();
      emit(AuthAuthenticated(user: meResponse.data));
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? "Signup failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onGoogleLoginRequested(GoogleLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.loginWithGoogle(event.googleToken);
      final meResponse = await _apiService.getMe();
      emit(AuthAuthenticated(user: meResponse.data));
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? "Google login failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  void _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) {
    ApiService.setToken(null);
    emit(AuthUnauthenticated());
  }
}
