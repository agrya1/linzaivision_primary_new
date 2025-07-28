import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int? id;
  final String username;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? preferences;
  
  const User({
    this.id,
    required this.username,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.preferences,
  });
  
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? this.preferences,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'preferences': preferences,
    };
  }
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      username: json['username'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }
  
  @override
  List<Object?> get props => [id, username, email, displayName, avatarUrl, preferences];
} 