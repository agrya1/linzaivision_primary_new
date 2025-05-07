import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_ali_auth/flutter_ali_auth.dart' as ali_auth; // 注释掉一键登录SDK导入
import 'package:shared_preferences/shared_preferences.dart';
import './api_service.dart';

/// 认证响应模型
class AuthResponseModel {
  final String resultCode;
  final String? token;
  final String phone;
  final Map<String, dynamic> data;

  AuthResponseModel({
    required this.resultCode,
    this.token,
    required this.phone,
    required this.data,
  });

  // 添加从JSON构建对象的工厂方法
  factory AuthResponseModel.fromJson(dynamic jsonData) {
    final Map<String, dynamic> dataMap = <String, dynamic>{};
    final Map<String, dynamic> json;

    // 确保input是一个Map
    if (jsonData is Map<String, dynamic>) {
      json = jsonData;
    } else if (jsonData is Map) {
      json = <String, dynamic>{};
      jsonData.forEach((key, value) {
        if (key is String) {
          json[key] = value;
        }
      });
    } else {
      json = <String, dynamic>{};
    }

    // 处理消息等字段
    if (json.containsKey('msg')) dataMap['msg'] = json['msg'];
    if (json.containsKey('requestId')) dataMap['requestId'] = json['requestId'];
    if (json.containsKey('innerCode')) dataMap['innerCode'] = json['innerCode'];
    if (json.containsKey('innerMsg')) dataMap['innerMsg'] = json['innerMsg'];

    return AuthResponseModel(
      resultCode: json['resultCode']?.toString() ?? '',
      token: json['token']?.toString(),
      phone: json['phone']?.toString() ?? '',
      data: dataMap,
    );
  }

  bool get isSuccessful => resultCode == '600000';

  String get message => data['msg'] as String? ?? '';

  @override
  String toString() {
    return 'AuthResponseModel{resultCode: $resultCode, token: $token, phone: $phone, data: $data}';
  }
}

/// 认证UI样式 - 保留枚举但不再使用
enum AuthUIStyle {
  fullScreen,
  bottomSheet,
  alert,
}

/// 导航栏配置
class NavConfig {
  final String navBackgroundColor;
  final String navTitleColor;
  final String navTitleText;
  final bool navBackButtonHidden;

  NavConfig({
    required this.navBackgroundColor,
    required this.navTitleColor,
    required this.navTitleText,
    required this.navBackButtonHidden,
  });
}

/// Logo配置
class LogoConfig {
  final bool logoHidden;
  final String logoImage;

  LogoConfig({
    required this.logoHidden,
    required this.logoImage,
  });
}

/// 隐私协议配置
class PrivacyConfig {
  final List<String> privacyOne;
  final List<String> privacyTwo;
  final String privacyOperatorColor;
  final String privacyTextColor;
  final double privacyTextFontSize;

  PrivacyConfig({
    required this.privacyOne,
    required this.privacyTwo,
    required this.privacyOperatorColor,
    required this.privacyTextColor,
    required this.privacyTextFontSize,
  });
}

/// 认证UI配置
class AuthUIConfig {
  final NavConfig navConfig;
  final LogoConfig logoConfig;
  final PrivacyConfig privacyConfig;

  AuthUIConfig({
    required this.navConfig,
    required this.logoConfig,
    required this.privacyConfig,
  });
}

/// 认证配置
class AuthConfig {
  final String iosSdk;
  final String androidSdk;
  final AuthUIStyle authUIStyle;
  final AuthUIConfig authUIConfig;

  AuthConfig({
    required this.iosSdk,
    required this.androidSdk,
    required this.authUIStyle,
    required this.authUIConfig,
  });
}

/// 阿里云认证客户端 - 移除所有实际引用外部SDK的代码
class AliAuthClient {
  // 模拟获取预取号信息
  static Future<Map<String, dynamic>> getPhoneInfo({int? timeout}) async {
    debugPrint('AliAuthClient.getPhoneInfo: 已禁用，返回模拟数据');
    // 返回模拟成功数据
    return {
      'resultCode': '600000',
      'msg': '预取号成功',
      'phone': '133****5678',
    };
  }

  // 模拟掩码手机号获取
  static Future<String?> getMaskedPhone() async {
    debugPrint('AliAuthClient.getMaskedPhone: 返回模拟掩码手机号');
    return '133****5678';
  }

  // 以下是空方法实现，保持API兼容性

  static Future<void> handleEvent({required Function(dynamic) onEvent}) async {
    debugPrint('AliAuthClient.handleEvent: 已禁用');
    return;
  }

  static Future<void> removeHandler() async {
    debugPrint('AliAuthClient.removeHandler: 已禁用');
    return;
  }

  static Future<void> initSdk({required dynamic authConfig}) async {
    debugPrint('AliAuthClient.initSdk: 已禁用');
    return;
  }

  static Future<void> login({double? timeout}) async {
    debugPrint('AliAuthClient.login: 已禁用');
    return;
  }

  static Future<void> hideLoginLoading() async {
    debugPrint('AliAuthClient.hideLoginLoading: 已禁用');
    return;
  }

  static Future<void> quitLoginPage() async {
    debugPrint('AliAuthClient.quitLoginPage: 已禁用');
    return;
  }
}

/// 认证服务
class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  AuthResponseModel? _lastResponse;
  AuthResponseModel? get lastResponse => _lastResponse;
  bool _isLoggedIn = false;

  // 用户相关属性
  String? _userId;
  String? _userName;
  String? _phoneNumber;
  String? _avatarUrl;

  // getter
  String? get userId => _userId;
  String? get userName => _userName;
  String? get phoneNumber => _phoneNumber;
  String? get avatarUrl => _avatarUrl;

  // 获取登录状态
  bool get isLoggedIn => _isLoggedIn;

  AuthService() {
    // 初始化时检查登录状态
    _checkLoginStatus();
    // 加载用户信息
    _loadUserInfoFromStorage();
  }

  // 从SharedPreferences加载用户信息
  Future<void> _loadUserInfoFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name');
      _phoneNumber = prefs.getString('phone_number');
      _avatarUrl = prefs.getString('avatar_url');
      notifyListeners();
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  // 检查登录状态
  Future<void> _checkLoginStatus() async {
    try {
      _isLoggedIn = await _apiService.isLoggedIn();
      notifyListeners();
    } catch (e) {
      print('检查登录状态失败: $e');
      _isLoggedIn = false;
    }
  }

  // 刷新用户信息 - 从服务器获取最新信息
  Future<bool> refreshUserInfo() async {
    try {
      final result = await _apiService.getUserInfo();
      if (result['success'] && result['data'] != null) {
        // 更新本地用户信息
        final userData = result['data']['user'];
        final prefs = await SharedPreferences.getInstance();

        _userId = userData['id']?.toString();
        prefs.setString('user_id', _userId ?? '');

        _userName = userData['username']?.toString();
        prefs.setString('user_name', _userName ?? '');

        _phoneNumber = userData['phone']?.toString();
        prefs.setString('phone_number', _phoneNumber ?? '');

        _avatarUrl = userData['avatar']?.toString();
        prefs.setString('avatar_url', _avatarUrl ?? '');

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('刷新用户信息失败: $e');
      return false;
    }
  }

  // 监听用户变化
  void addListener(VoidCallback listener) {
    super.addListener(listener);
  }

  // 移除监听
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
  }

  // 登出方法
  Future<bool> logout() async {
    try {
      final result = await _apiService.logout();
      if (result['success']) {
        // 清空用户信息
        _userId = null;
        _userName = null;
        _phoneNumber = null;
        _avatarUrl = null;
        _isLoggedIn = false;

        // 通知监听器
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('登出失败: $e');
      return false;
    }
  }

  // 为了兼容现有代码，保留init方法但进行简化
  Future<void> init() async {
    // 不再调用SDK初始化，只是一个空实现保持接口一致
    debugPrint('一键登录功能已禁用，仅支持短信验证码登录');
    return;
  }

  // 简化版getMaskedPhone方法，只从本地获取或返回模拟数据
  Future<String?> getMaskedPhone() async {
    try {
      // 不再调用SDK，直接从本地存储获取
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('phone_number') ?? '';
      if (phone.isNotEmpty && phone.length > 7) {
        final masked =
            '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
        debugPrint('从本地存储获取的掩码号码: $masked');
        return masked;
      }

      // 返回模拟数据
      final mockPhone = '133****5678';
      debugPrint('使用模拟的掩码手机号: $mockPhone');
      return mockPhone;
    } catch (e) {
      debugPrint('获取手机号码失败: $e');
      return null;
    }
  }

  /// 验证码登录方法
  Future<bool> loginWithCode(String phone, String code) async {
    try {
      final result = await _apiService.phoneCodeLogin(phone, code);
      if (result['success']) {
        // 更新登录状态
        _isLoggedIn = true;

        // 刷新用户信息
        await refreshUserInfo();

        // 通知UI
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('验证码登录失败: $e');
      return false;
    }
  }

  /// 发送验证码
  Future<bool> sendVerificationCode(String phone) async {
    try {
      final response = await _apiService.sendSmsCode(phone);
      return response['success'] == true;
    } catch (e) {
      print('发送验证码失败: $e');
      return false;
    }
  }

  // 一个便于使用的同步方法，获取掩码手机号
  String? getMarkedPhone() {
    try {
      // 这是同步方法，返回null或最后一次缓存的掩码号码
      if (_phoneNumber == null || _phoneNumber!.isEmpty) return null;

      // 简单掩码处理: 135****1234
      if (_phoneNumber!.length > 7) {
        return '${_phoneNumber!.substring(0, 3)}****${_phoneNumber!.substring(_phoneNumber!.length - 4)}';
      }
      return _phoneNumber;
    } catch (e) {
      print('获取手机号码失败: $e');
      return null;
    }
  }

  // 添加空方法以保持接口兼容性
  Future<void> removeAuthHandler() async {
    // 空实现，为了保持API兼容性
    return;
  }

  // 空的认证事件处理方法，保持API兼容性
  Future<void> handleAuthEvent(Function(dynamic) callback) async {
    // 空实现，为了保持API兼容性
    return;
  }

  // 空的一键登录方法，保持API兼容性
  Future<void> oneKeyLogin({bool? needAgreeTerms}) async {
    // 空实现，为了保持API兼容性
    return;
  }
}
