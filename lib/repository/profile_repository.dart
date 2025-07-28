import 'dart:io';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

/// 用户资料仓库接口
abstract class ProfileRepository {
  /// 获取当前用户资料
  Future<User?> getUserProfile();
  
  /// 更新用户头像
  Future<String?> updateAvatar(File imageFile);
  
  /// 更新用户昵称
  Future<bool> updateDisplayName(String displayName);
  
  /// 获取用户会员状态
  Future<int> getMembershipStatus();
}

/// 用户资料仓库实现
class ProfileRepositoryImpl implements ProfileRepository {
  final AuthService _authService;
  final StorageService _storageService;
  final ApiService _apiService;
  
  // 存储键
  static const String _userDisplayNameKey = 'user_display_name';
  static const String _userAvatarUrlKey = 'user_avatar_url';
  static const String _userMembershipStatusKey = 'user_membership_status';
  
  ProfileRepositoryImpl(this._authService, this._storageService, this._apiService);
  
  @override
  Future<User?> getUserProfile() async {
    if (!_authService.isLoggedIn) {
      return null;
    }
    
    try {
      // 尝试从 AuthService 获取基本信息
      final userId = _authService.userId;
      final username = _authService.userName ?? '';
      final phoneNumber = _authService.phoneNumber;
      
      // 从存储服务获取可能已缓存的额外信息
      final displayName = await _storageService.getString(_userDisplayNameKey);
      final avatarUrl = await _storageService.getString(_userAvatarUrlKey) ?? _authService.avatarUrl;
      
      // 创建用户对象，优先使用缓存的昵称，如果没有则使用用户名，如果都没有则使用手机号后4位
      final effectiveDisplayName = displayName ?? 
                                  (username.isNotEmpty ? username : 
                                  (phoneNumber != null ? '用户${phoneNumber.substring(phoneNumber.length - 4)}' : '未命名用户'));
      
      // 创建用户对象
      return User(
        id: userId != null ? int.tryParse(userId) : null,
        username: username,
        email: null,
        displayName: effectiveDisplayName,
        avatarUrl: avatarUrl,
        preferences: null,
      );
    } catch (e) {
      print('获取用户资料失败: $e');
      return null;
    }
  }
  
  @override
  Future<String?> updateAvatar(File imageFile) async {
    if (!_authService.isLoggedIn) {
      throw Exception('用户未登录');
    }
    
    try {
      // 调用 API 上传头像
      final response = await _apiService.uploadAvatar(imageFile);
      
      if (response['success'] == true && response['data'] != null) {
        // 获取返回的头像 URL
        final avatarUrl = response['data']['avatarUrl'] as String?;
        
        if (avatarUrl != null) {
          // 缓存头像 URL
          await _storageService.saveString(_userAvatarUrlKey, avatarUrl);
          
          // 刷新用户信息
          await _authService.refreshUserInfo();
          
          return avatarUrl;
        }
      }
      
      throw Exception('上传头像失败: ${response['message'] ?? '未知错误'}');
    } catch (e) {
      print('上传头像失败: $e');
      throw Exception('上传头像失败: $e');
    }
  }
  
  @override
  Future<bool> updateDisplayName(String displayName) async {
    if (!_authService.isLoggedIn) {
      throw Exception('用户未登录');
    }
    
    if (displayName.isEmpty) {
      throw Exception('昵称不能为空');
    }
    
    try {
      // 调用 API 更新昵称
      final response = await _apiService.updateUserProfile({
        'displayName': displayName,
      });
      
      if (response['success'] == true) {
        // 缓存新昵称
        await _storageService.saveString(_userDisplayNameKey, displayName);
        
        // 刷新用户信息
        await _authService.refreshUserInfo();
        
        return true;
      }
      
      throw Exception('更新昵称失败: ${response['message'] ?? '未知错误'}');
    } catch (e) {
      print('更新昵称失败: $e');
      throw Exception('更新昵称失败: $e');
    }
  }
  
  @override
  Future<int> getMembershipStatus() async {
    if (!_authService.isLoggedIn) {
      return 0; // 未登录状态
    }
    
    try {
      // 先尝试从存储中获取
      final cachedStatus = await _storageService.getInt(_userMembershipStatusKey);
      if (cachedStatus != null) {
        return cachedStatus;
      }
      
      // 如果没有缓存，则从 API 获取
      final response = await _apiService.getUserInfo();
      
      if (response['success'] == true && response['data'] != null) {
        final memberLevel = response['data']['memberLevel'] as int? ?? 1;
        
        // 缓存会员状态
        await _storageService.saveInt(_userMembershipStatusKey, memberLevel);
        
        return memberLevel;
      }
      
      return 1; // 默认为普通用户
    } catch (e) {
      print('获取会员状态失败: $e');
      return 1; // 出错时默认为普通用户
    }
  }
} 