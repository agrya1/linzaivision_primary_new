import 'package:equatable/equatable.dart';
import '../../models/user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String username;
  final String password;
  
  const LoginEvent(this.username, this.password);
  
  @override
  List<Object?> get props => [username, password];
}

class LogoutEvent extends AuthEvent {}

class CheckAuthStatusEvent extends AuthEvent {}

class UpdateProfileEvent extends AuthEvent {
  final User user;
  
  const UpdateProfileEvent(this.user);
  
  @override
  List<Object?> get props => [user];
} 