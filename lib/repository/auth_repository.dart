import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

abstract class AuthRepository {
  Future<User> login(String username, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isLoggedIn();
  Future<void> updateUserProfile(User user);
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final StorageService _storageService;
  
  // 用户信息缓存键
  static const String _userIdKey = 'auth_user_id';
  static const String _userNameKey = 'auth_user_name';
  static const String _userPhoneKey = 'auth_user_phone';
  static const String _userAvatarKey = 'auth_user_avatar';
  static const String _userTokenKey = 'auth_user_token';
  static const String _isLoggedInKey = 'auth_is_logged_in';
  
  AuthRepositoryImpl(this._authService, this._storageService);
  
  @override
  Future<User> login(String username, String password) async {
    try {
      // 使用AuthService的loginWithCode方法（假设用户名是手机号，密码是验证码）
      final result = await _authService.loginWithCode(username, password);
      
      if (result && _authService.isLoggedIn) {
        final user = User(
          id: int.tryParse(_authService.userId ?? '0'),
          username: _authService.userName ?? username,
          email: null,
          displayName: _authService.userName,
          avatarUrl: _authService.avatarUrl,
        );
        
        // 保存用户信息到存储服务
        await _saveUserToStorage(user);
        
        return user;
      } else {
        throw Exception('登录失败');
      }
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }
  
  @override
  Future<void> logout() async {
    await _authService.logout();
    
    // 清除存储的用户信息
    await _clearUserFromStorage();
  }
  
  @override
  Future<User?> getCurrentUser() async {
    if (_authService.isLoggedIn) {
      return User(
        id: int.tryParse(_authService.userId ?? '0'),
        username: _authService.userName ?? '',
        email: null,
        displayName: _authService.userName,
        avatarUrl: _authService.avatarUrl,
      );
    }
    
    // 尝试从存储中获取用户信息
    return _getUserFromStorage();
  }
  
  @override
  Future<bool> isLoggedIn() async {
    // 先检查AuthService的状态
    if (_authService.isLoggedIn) {
      return true;
    }
    
    // 再检查存储中的登录状态
    return await _storageService.getBool(_isLoggedInKey) ?? false;
  }
  
  @override
  Future<void> updateUserProfile(User user) async {
    // AuthService可能没有直接的方法来更新用户资料
    // 这里我们使用refreshUserInfo作为一个替代方案
    await _authService.refreshUserInfo();
    
    // 更新存储中的用户信息
    await _saveUserToStorage(user);
  }
  
  // 保存用户信息到存储
  Future<void> _saveUserToStorage(User user) async {
    await _storageService.saveString(_userIdKey, user.id?.toString() ?? '');
    await _storageService.saveString(_userNameKey, user.username);
    await _storageService.saveString(_userPhoneKey, _authService.phoneNumber ?? '');
    await _storageService.saveString(_userAvatarKey, user.avatarUrl ?? '');
    await _storageService.saveBool(_isLoggedInKey, true);
  }
  
  // 从存储获取用户信息
  Future<User?> _getUserFromStorage() async {
    final isLoggedIn = await _storageService.getBool(_isLoggedInKey);
    if (isLoggedIn != true) {
      return null;
    }
    
    final userId = await _storageService.getString(_userIdKey);
    final userName = await _storageService.getString(_userNameKey);
    final avatarUrl = await _storageService.getString(_userAvatarKey);
    
    if (userName == null || userName.isEmpty) {
      return null;
    }
    
    return User(
      id: int.tryParse(userId ?? '0'),
      username: userName,
      email: null,
      displayName: userName,
      avatarUrl: avatarUrl,
    );
  }
  
  // 清除存储的用户信息
  Future<void> _clearUserFromStorage() async {
    await _storageService.remove(_userIdKey);
    await _storageService.remove(_userNameKey);
    await _storageService.remove(_userPhoneKey);
    await _storageService.remove(_userAvatarKey);
    await _storageService.remove(_userTokenKey);
    await _storageService.saveBool(_isLoggedInKey, false);
  }
} 