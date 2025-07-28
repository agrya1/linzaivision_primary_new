import 'package:equatable/equatable.dart';
import 'dart:io';

/// 用户资料事件基类
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// 加载用户资料事件
class LoadProfile extends ProfileEvent {
  const LoadProfile();
}

/// 更新用户头像事件
class UpdateAvatar extends ProfileEvent {
  final File imageFile;

  const UpdateAvatar(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}

/// 更新用户昵称事件
class UpdateDisplayName extends ProfileEvent {
  final String displayName;

  const UpdateDisplayName(this.displayName);

  @override
  List<Object?> get props => [displayName];
}

/// 刷新会员状态事件
class RefreshMembershipStatus extends ProfileEvent {
  const RefreshMembershipStatus();
} 