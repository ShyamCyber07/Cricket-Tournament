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
  final String email;
  final String password;
  final String fullName;

  const SignupRequested({
    required this.email,
    required this.password,
    required this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

class GoogleLoginRequested extends AuthEvent {
  final String googleToken;

  const GoogleLoginRequested({required this.googleToken});

  @override
  List<Object?> get props => [googleToken];
}

class LogoutRequested extends AuthEvent {}
