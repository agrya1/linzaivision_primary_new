import 'package:equatable/equatable.dart';
import '../../models/user.dart';

/// 用户资料状态基类
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// 加载中状态
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// 加载成功状态
class ProfileLoaded extends ProfileState {
  final User? user;
  final String? displayName;
  final String? avatarUrl;
  final int membershipStatus;
  final bool isLoggedIn;

  const ProfileLoaded({
    this.user,
    this.displayName,
    this.avatarUrl,
    this.membershipStatus = 0,
    this.isLoggedIn = false,
  });

  @override
  List<Object?> get props => [user, displayName, avatarUrl, membershipStatus, isLoggedIn];

  /// 创建一个新的状态实例，替换指定的属性
  ProfileLoaded copyWith({
    User? user,
    String? displayName,
    String? avatarUrl,
    int? membershipStatus,
    bool? isLoggedIn,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

/// 错误状态
class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

/// 头像更新中状态
class AvatarUpdating extends ProfileState {
  const AvatarUpdating();
}

/// 昵称更新中状态
class DisplayNameUpdating extends ProfileState {
  const DisplayNameUpdating();
} 