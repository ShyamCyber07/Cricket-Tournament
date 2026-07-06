import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignupRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;

  const SignupRequested({
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [username, email, password, confirmPassword];
}

class VerifyOtpRequested extends AuthEvent {
  final String email;
  final String otpCode;

  const VerifyOtpRequested({required this.email, required this.otpCode});

  @override
  List<Object?> get props => [email, otpCode];
}

class ResendOtpRequested extends AuthEvent {
  final String email;

  const ResendOtpRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class GoogleLoginRequested extends AuthEvent {
  final String googleToken;

  const GoogleLoginRequested({required this.googleToken});

  @override
  List<Object?> get props => [googleToken];
}

class CompleteProfileRequested extends AuthEvent {
  final String fullName;
  final String displayName;
  final String? username;
  final String? role;
  final String? profilePicture;
  final String? country;
  final String? favoriteTeam;

  const CompleteProfileRequested({
    required this.fullName,
    required this.displayName,
    this.username,
    this.role,
    this.profilePicture,
    this.country,
    this.favoriteTeam,
  });

  @override
  List<Object?> get props => [fullName, displayName, username, role, profilePicture, country, favoriteTeam];
}

class ForgotPasswordRequested extends AuthEvent {
  final String email;

  const ForgotPasswordRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class ResetPasswordRequested extends AuthEvent {
  final String email;
  final String otpCode;
  final String newPassword;
  final String confirmPassword;

  const ResetPasswordRequested({
    required this.email,
    required this.otpCode,
    required this.newPassword,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [email, otpCode, newPassword, confirmPassword];
}

class VerifyForgotPasswordOtpRequested extends AuthEvent {
  final String email;
  final String otpCode;

  const VerifyForgotPasswordOtpRequested({required this.email, required this.otpCode});

  @override
  List<Object?> get props => [email, otpCode];
}

class AuthVerificationRedirectRequested extends AuthEvent {
  final String email;

  const AuthVerificationRedirectRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class LogoutRequested extends AuthEvent {
  final String? reason;
  const LogoutRequested({this.reason});

  @override
  List<Object?> get props => [reason];
}
