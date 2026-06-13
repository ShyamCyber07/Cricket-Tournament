import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthNeedsVerification extends AuthState {
  final String email;

  const AuthNeedsVerification({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthProfileIncomplete extends AuthState {
  final Map<String, dynamic> user;

  const AuthProfileIncomplete({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthForgotPasswordOtpSent extends AuthState {
  final String email;

  const AuthForgotPasswordOtpSent({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthForgotPasswordOtpVerified extends AuthState {
  final String email;
  final String otpCode;

  const AuthForgotPasswordOtpVerified({required this.email, required this.otpCode});

  @override
  List<Object?> get props => [email, otpCode];
}

class AuthPasswordResetSuccess extends AuthState {}

class AuthOtpResentSuccess extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthSignupUnverified extends AuthState {
  final String email;

  const AuthSignupUnverified({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
