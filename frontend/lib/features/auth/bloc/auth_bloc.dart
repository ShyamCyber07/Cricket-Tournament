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
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<ResendOtpRequested>(_onResendOtpRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<CompleteProfileRequested>(_onCompleteProfileRequested);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
    on<VerifyForgotPasswordOtpRequested>(_onVerifyForgotPasswordOtpRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await ApiService.loadPersistedToken();
    if (ApiService.isAuthenticated) {
      try {
        final response = await _apiService.getMe();
        final user = response.data;
        if (user['email_verified'] == false) {
          emit(AuthNeedsVerification(email: user['email']));
        } else if (user['profile_completed'] == false) {
          emit(AuthProfileIncomplete(user: user));
        } else {
          emit(AuthAuthenticated(user: user));
        }
      } catch (e) {
        await ApiService.clearToken();
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
      final user = meResponse.data;
      if (user['email_verified'] == false) {
        emit(AuthNeedsVerification(email: user['email']));
      } else if (user['profile_completed'] == false) {
        emit(AuthProfileIncomplete(user: user));
      } else {
        emit(AuthAuthenticated(user: user));
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      final msg = detail ?? "Login failed. Check credentials.";
      if (detail != null && detail.toString().toLowerCase().contains("email not verified")) {
        emit(AuthNeedsVerification(email: event.email));
      } else {
        emit(AuthError(message: msg.toString()));
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignupRequested(SignupRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.signup(event.email, event.password, event.username, event.confirmPassword);
      emit(AuthNeedsVerification(email: event.email));
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Signup failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onVerifyOtpRequested(VerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.verifyOtp(event.email, event.otpCode);
      final meResponse = await _apiService.getMe();
      final user = meResponse.data;
      if (user['profile_completed'] == false) {
        emit(AuthProfileIncomplete(user: user));
      } else {
        emit(AuthAuthenticated(user: user));
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "OTP verification failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthNeedsVerification(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthNeedsVerification(email: event.email));
    }
  }

  Future<void> _onResendOtpRequested(ResendOtpRequested event, Emitter<AuthState> emit) async {
    try {
      await _apiService.resendOtp(event.email);
      emit(AuthOtpResentSuccess());
      // Re-emit verification state to ensure screen stays active
      emit(AuthNeedsVerification(email: event.email));
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Failed to resend OTP.";
      emit(AuthError(message: msg.toString()));
      emit(AuthNeedsVerification(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthNeedsVerification(email: event.email));
    }
  }

  Future<void> _onGoogleLoginRequested(GoogleLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.loginWithGoogle(event.googleToken);
      final meResponse = await _apiService.getMe();
      final user = meResponse.data;
      if (user['profile_completed'] == false) {
        emit(AuthProfileIncomplete(user: user));
      } else {
        emit(AuthAuthenticated(user: user));
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Google login failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onCompleteProfileRequested(CompleteProfileRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.completeProfile(
        event.fullName,
        event.displayName,
        profilePicture: event.profilePicture,
        country: event.country,
        favoriteTeam: event.favoriteTeam,
      );
      final meResponse = await _apiService.getMe();
      emit(AuthAuthenticated(user: meResponse.data));
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Failed to complete profile.";
      emit(AuthError(message: msg.toString()));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onForgotPasswordRequested(ForgotPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.forgotPassword(event.email);
      emit(AuthForgotPasswordOtpSent(email: event.email));
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Failed to request password reset.";
      emit(AuthError(message: msg.toString()));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onVerifyForgotPasswordOtpRequested(VerifyForgotPasswordOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.verifyResetOtp(event.email, event.otpCode);
      emit(AuthForgotPasswordOtpVerified(email: event.email, otpCode: event.otpCode));
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "OTP verification failed.";
      emit(AuthError(message: msg.toString()));
      emit(AuthForgotPasswordOtpSent(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthForgotPasswordOtpSent(email: event.email));
    }
  }

  Future<void> _onResetPasswordRequested(ResetPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.resetPassword(event.email, event.otpCode, event.newPassword, event.confirmPassword);
      emit(AuthPasswordResetSuccess());
      emit(AuthUnauthenticated());
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? "Failed to reset password.";
      emit(AuthError(message: msg.toString()));
      emit(AuthForgotPasswordOtpVerified(email: event.email, otpCode: event.otpCode));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthForgotPasswordOtpVerified(email: event.email, otpCode: event.otpCode));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _apiService.logout();
    } catch (_) {
      await ApiService.clearToken();
    }
    emit(AuthUnauthenticated());
  }
}
