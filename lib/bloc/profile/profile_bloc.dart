import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// 用户资料 BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;

  ProfileBloc({required this.repository}) : super(const ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateAvatar>(_onUpdateAvatar);
    on<UpdateDisplayName>(_onUpdateDisplayName);
    on<RefreshMembershipStatus>(_onRefreshMembershipStatus);
  }

  /// 处理加载用户资料事件
  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    try {
      final user = await repository.getUserProfile();
      final membershipStatus = await repository.getMembershipStatus();
      
      emit(ProfileLoaded(
        user: user,
        displayName: user?.displayName,
        avatarUrl: user?.avatarUrl,
        membershipStatus: membershipStatus,
        isLoggedIn: user != null,
      ));
    } catch (e) {
      emit(ProfileError('加载用户资料失败: $e'));
    }
  }

  /// 处理更新头像事件
  Future<void> _onUpdateAvatar(UpdateAvatar event, Emitter<ProfileState> emit) async {
    // 保存当前状态，以便在失败时恢复
    final currentState = state;
    
    // 发出更新中状态
    emit(const AvatarUpdating());
    
    try {
      final avatarUrl = await repository.updateAvatar(event.imageFile);
      
      if (currentState is ProfileLoaded) {
        emit(currentState.copyWith(avatarUrl: avatarUrl));
      } else {
        // 如果之前不是已加载状态，则重新加载用户资料
        add(const LoadProfile());
      }
    } catch (e) {
      emit(ProfileError('更新头像失败: $e'));
      // 恢复到之前的状态
      if (currentState is ProfileLoaded) {
        emit(currentState);
      }
    }
  }

  /// 处理更新昵称事件
  Future<void> _onUpdateDisplayName(UpdateDisplayName event, Emitter<ProfileState> emit) async {
    // 保存当前状态，以便在失败时恢复
    final currentState = state;
    
    // 发出更新中状态
    emit(const DisplayNameUpdating());
    
    try {
      final success = await repository.updateDisplayName(event.displayName);
      
      if (success) {
        if (currentState is ProfileLoaded) {
          emit(currentState.copyWith(displayName: event.displayName));
        } else {
          // 如果之前不是已加载状态，则重新加载用户资料
          add(const LoadProfile());
        }
      } else {
        throw Exception('更新昵称失败');
      }
    } catch (e) {
      emit(ProfileError('更新昵称失败: $e'));
      // 恢复到之前的状态
      if (currentState is ProfileLoaded) {
        emit(currentState);
      }
    }
  }

  /// 处理刷新会员状态事件
  Future<void> _onRefreshMembershipStatus(RefreshMembershipStatus event, Emitter<ProfileState> emit) async {
    if (state is! ProfileLoaded) {
      // 如果当前不是已加载状态，则直接加载用户资料
      add(const LoadProfile());
      return;
    }
    
    final currentState = state as ProfileLoaded;
    
    try {
      final membershipStatus = await repository.getMembershipStatus();
      emit(currentState.copyWith(membershipStatus: membershipStatus));
    } catch (e) {
      // 刷新会员状态失败，但不改变当前状态
      print('刷新会员状态失败: $e');
    }
  }
} 