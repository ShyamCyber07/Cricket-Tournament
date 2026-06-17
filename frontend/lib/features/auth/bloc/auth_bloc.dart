import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    on<AuthVerificationRedirectRequested>((event, emit) {
      emit(AuthNeedsVerification(email: event.email));
    });
  }

  String _getErrorMessage(DioException e, String defaultMessage) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail != null) {
          if (detail is List) {
            try {
              return detail.map((err) {
                if (err is Map) {
                  final loc = err['loc'] as List?;
                  final field = loc != null && loc.length > 1 ? loc.last : '';
                  final msg = err['msg'] ?? '';
                  if (field.isNotEmpty) {
                    return "$field: $msg";
                  }
                  return msg;
                }
                return err.toString();
              }).join(", ");
            } catch (_) {}
          }
          return detail.toString();
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return "Connection timeout. Please check your internet connection.";
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return "Server timeout. Please try again later.";
    } else if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to server. Please check your internet connection or server status.";
    }
    return e.message ?? defaultMessage;
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
      final msg = _getErrorMessage(e, "Login failed. Check credentials.");
      if (msg.toLowerCase().contains("email not verified")) {
        emit(AuthNeedsVerification(email: event.email));
      } else {
        emit(AuthError(message: msg));
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
      final msg = _getErrorMessage(e, "Signup failed.");
      if (msg.toLowerCase().contains("account exists but is not verified")) {
        emit(AuthSignupUnverified(email: event.email));
      } else {
        emit(AuthError(message: msg));
        emit(AuthUnauthenticated());
      }
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
      final msg = _getErrorMessage(e, "OTP verification failed.");
      emit(AuthError(message: msg));
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
      final msg = _getErrorMessage(e, "Failed to resend OTP.");
      emit(AuthError(message: msg));
      emit(AuthNeedsVerification(email: event.email));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthNeedsVerification(email: event.email));
    }
  }

  Future<void> _onGoogleLoginRequested(GoogleLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    print("[DIAGNOSTICS] Google Login requested to backend...");
    try {
      final response = await _apiService.loginWithGoogle(event.googleToken);
      print("[DIAGNOSTICS] Backend response status: ${response.statusCode}");
      print("[DIAGNOSTICS] Backend response body: ${response.data}");
      
      final meResponse = await _apiService.getMe();
      final user = meResponse.data;
      if (user['profile_completed'] == false) {
        emit(AuthProfileIncomplete(user: user));
      } else {
        emit(AuthAuthenticated(user: user));
      }
    } on DioException catch (e, stack) {
      print("[DIAGNOSTICS] Google Login Backend DioException encountered: $e");
      print("[DIAGNOSTICS]   Response status: ${e.response?.statusCode}");
      print("[DIAGNOSTICS]   Response body: ${e.response?.data}");
      print("[DIAGNOSTICS]   Message: ${e.message}");
      print("[DIAGNOSTICS] StackTrace:\n$stack");
      
      final msg = _getErrorMessage(e, "Google login failed.");
      emit(AuthError(message: msg));
      emit(AuthUnauthenticated());
    } catch (e, stack) {
      print("[DIAGNOSTICS] Google Login Backend unexpected error: $e");
      print("[DIAGNOSTICS] StackTrace:\n$stack");
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
        username: event.username,
        role: event.role,
        profilePicture: event.profilePicture,
        country: event.country,
        favoriteTeam: event.favoriteTeam,
      );
      final meResponse = await _apiService.getMe();
      emit(AuthAuthenticated(user: meResponse.data));
    } on DioException catch (e) {
      final msg = _getErrorMessage(e, "Failed to complete profile.");
      emit(AuthError(message: msg));
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
      final msg = _getErrorMessage(e, "Failed to request password reset.");
      emit(AuthError(message: msg));
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
      final msg = _getErrorMessage(e, "OTP verification failed.");
      emit(AuthError(message: msg));
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
      final msg = _getErrorMessage(e, "Failed to reset password.");
      emit(AuthError(message: msg));
      emit(AuthForgotPasswordOtpVerified(email: event.email, otpCode: event.otpCode));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AuthForgotPasswordOtpVerified(email: event.email, otpCode: event.otpCode));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    print("[DIAGNOSTICS] Starting Logout flow...");
    try {
      await _apiService.logout();
    } catch (e) {
      print("[DIAGNOSTICS] Backend logout failed: $e, clearing local token manually.");
      await ApiService.clearToken();
    }
    
    try {
      print("[DIAGNOSTICS] Signing out from Firebase Auth...");
      await FirebaseAuth.instance.signOut();
      print("[DIAGNOSTICS] Firebase Auth Sign-Out completed.");
    } catch (e) {
      print("[DIAGNOSTICS] Error signing out from Firebase Auth: $e");
    }

    try {
      print("[DIAGNOSTICS] Signing out from Google Sign-In...");
      final googleSignIn = GoogleSignIn(
        serverClientId: "270888644885-il2mmaaeehom7amrhglgtckcs3gu1j8c.apps.googleusercontent.com",
      );
      await googleSignIn.signOut();
      print("[DIAGNOSTICS] Google Sign-In Sign-Out completed.");
    } catch (e) {
      print("[DIAGNOSTICS] Error signing out from Google Sign-In: $e");
    }
    
    emit(AuthUnauthenticated());
  }
}
