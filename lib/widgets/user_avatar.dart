import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile/profile_bloc.dart';
import '../bloc/profile/profile_state.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final double borderRadius;
  final BoxBorder? border;

  const UserAvatar({
    Key? key,
    this.size = 40.0,
    this.onTap,
    this.borderRadius = 20.0,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用 BlocBuilder 监听 ProfileBloc 状态
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        // 从 ProfileBloc 获取头像 URL
        final String? avatarUrl = state is ProfileLoaded ? state.avatarUrl : null;
        final bool isLoggedIn = state is ProfileLoaded ? state.isLoggedIn : false;
        
        // 回退到 AuthService 以保持兼容性
        return Consumer<AuthService>(
          builder: (context, authService, child) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: border,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatar(avatarUrl, isLoggedIn, authService),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(String? avatarUrl, bool isLoggedIn, AuthService authService) {
    if (isLoggedIn) {
      // 用户已登录，优先使用 ProfileBloc 中的头像 URL
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        // 有远程头像，使用网络图片
        return Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败，显示默认头像
            return Image.asset(
              'assets/images/default_avatar.png',
              fit: BoxFit.cover,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
                strokeWidth: 2.0,
              ),
            );
          },
        );
      } else if (authService.avatarUrl != null && authService.avatarUrl!.isNotEmpty) {
        // 回退到 AuthService 中的头像 URL
        return Image.network(
          authService.avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败，显示默认头像
            return Image.asset(
              'assets/images/default_avatar.png',
              fit: BoxFit.cover,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
                strokeWidth: 2.0,
              ),
            );
          },
        );
      } else {
        // 没有远程头像，使用默认头像
        return Image.asset(
          'assets/images/default_avatar.png',
          fit: BoxFit.cover,
        );
      }
    } else {
      // 用户未登录，使用默认未登录头像
      return Image.asset(
        'assets/images/default_avatar_al.png',
        fit: BoxFit.cover,
      );
    }
  }
}
