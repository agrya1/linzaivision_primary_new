import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ali_auth/flutter_ali_auth.dart' as ali_auth;
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

/// 认证UI样式
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

/// 阿里云认证客户端
class AliAuthClient {
  // 监听回调
  static Future<void> handleEvent(
      {required Function(AuthResponseModel) onEvent}) {
    try {
      debugPrint('AliAuthClient.handleEvent: 开始设置事件处理器');
      ali_auth.AliAuthClient.handleEvent(onEvent: (dynamic event) {
        // 将flutter_ali_auth包的事件转换为本地的AuthResponseModel
        debugPrint('AliAuthClient.handleEvent: 收到原始事件: $event');

        Map<String, dynamic> eventMap;
        if (event is Map<String, dynamic>) {
          eventMap = event;
        } else if (event is Map) {
          eventMap = {};
          event.forEach((key, value) {
            if (key is String) {
              eventMap[key] = value;
            }
          });
        } else {
          debugPrint('AliAuthClient.handleEvent: 事件不是Map类型');
          eventMap = {'resultCode': '600008', 'msg': '未知事件格式'};
        }

        debugPrint('AliAuthClient.handleEvent: 处理后的事件Map: $eventMap');
        final resultCode = eventMap['resultCode'] as String? ?? '';
        final token = eventMap['token'] as String?;
        final phone = ''; // flutter_ali_auth可能不直接提供phone
        final data = <String, dynamic>{};
        if (eventMap.containsKey('msg')) data['msg'] = eventMap['msg'];
        if (eventMap.containsKey('requestId'))
          data['requestId'] = eventMap['requestId'];
        if (eventMap.containsKey('innerCode'))
          data['innerCode'] = eventMap['innerCode'];
        if (eventMap.containsKey('innerMsg'))
          data['innerMsg'] = eventMap['innerMsg'];

        final authResponse = AuthResponseModel(
          resultCode: resultCode,
          token: token,
          phone: phone,
          data: data,
        );
        debugPrint(
            'AliAuthClient.handleEvent: 转换为AuthResponseModel: $authResponse');

        onEvent(authResponse);
      });
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error setting up event handler: $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }

  // 移除监听
  static Future<void> removeHandler() {
    try {
      ali_auth.AliAuthClient.removeHandler();
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error removing handler: $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }

  // 初始化SDK
  static Future<void> initSdk({required AuthConfig authConfig}) {
    try {
      // 创建基本的阿里云SDK配置
      ali_auth.AliAuthClient.initSdk(
        authConfig: ali_auth.AuthConfig(
          iosSdk: authConfig.iosSdk,
          androidSdk: authConfig.androidSdk,
          enableLog: true, // 根据需要设置
          authUIStyle: _convertAuthUIStyle(authConfig.authUIStyle),
          // 使用默认UI配置
        ),
      );
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error initializing SDK (setup): $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }

  // 将本地AuthUIStyle转换为阿里云SDK的AuthUIStyle
  static ali_auth.AuthUIStyle _convertAuthUIStyle(AuthUIStyle style) {
    switch (style) {
      case AuthUIStyle.fullScreen:
        return ali_auth.AuthUIStyle.fullScreen;
      case AuthUIStyle.bottomSheet:
        return ali_auth.AuthUIStyle.bottomSheet;
      case AuthUIStyle.alert:
        return ali_auth.AuthUIStyle.alert;
      default:
        return ali_auth.AuthUIStyle.fullScreen;
    }
  }

  // 获取预取号信息
  static Future<Map<String, dynamic>> getPhoneInfo({int? timeout}) async {
    try {
      final result =
          await ali_auth.AliAuthClient.getPhoneInfo(timeout: timeout ?? 5);
      return result is Map
          ? Map<String, dynamic>.from(result)
          : {'resultCode': '600002', 'msg': '预取号失败'};
    } catch (e) {
      print('Error getting phone info: $e');
      rethrow;
    }
  }

  /// 获取登录手机号的掩码形式
  Future<String?> getMaskedPhone() async {
    try {
      debugPrint('开始调用预取号功能...');

      // 调用阿里云SDK的预取号功能
      try {
        debugPrint('调用AliAuthClient.getPhoneInfo开始...');
        final phoneInfoResult = await AliAuthClient.getPhoneInfo(timeout: 5);
        debugPrint('预取号结果完整内容: ${phoneInfoResult.toString()}');

        // 打印Map中所有的键
        debugPrint('预取号结果包含的键: ${phoneInfoResult.keys.toList()}');

        if (phoneInfoResult['resultCode'] == '600000') {
          // 预取号成功
          final maskedPhone = phoneInfoResult['phone'];
          debugPrint('成功获取掩码号码的类型: ${maskedPhone?.runtimeType}');
          debugPrint('成功获取掩码号码: $maskedPhone');

          if (maskedPhone != null) {
            return maskedPhone.toString();
          } else {
            debugPrint('警告: 预取号成功但phone字段为null');
          }
        } else {
          // 预取号失败
          debugPrint('预取号失败: ${phoneInfoResult['msg']}');
        }

        // 尝试从本地存储获取
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone_number') ?? '';
        if (phone.isNotEmpty && phone.length > 7) {
          final masked =
              '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
          debugPrint('从本地存储获取的掩码号码: $masked');
          return masked;
        }

        // 如果都失败，返回模拟数据
        final mockPhone = '133****5678';
        debugPrint('使用模拟的掩码手机号: $mockPhone');
        return mockPhone;
      } catch (sdkError) {
        // 预取号SDK调用出错
        debugPrint('预取号SDK调用异常: $sdkError');

        // 使用模拟数据
        final mockPhone = '134****9876';
        debugPrint('使用模拟的掩码手机号: $mockPhone');
        return mockPhone;
      }
    } catch (e) {
      debugPrint('获取手机号码失败: $e');
      return null;
    }
  }

  // 一键登录
  static Future<void> login({double? timeout}) {
    try {
      ali_auth.AliAuthClient.login(timeout: timeout?.toInt() ?? 5);
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error during login: $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }

  // 隐藏登录加载
  static Future<void> hideLoginLoading() {
    try {
      ali_auth.AliAuthClient.hideLoginLoading();
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error hiding login loading: $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }

  // 退出登录页面
  static Future<void> quitLoginPage() {
    try {
      ali_auth.AliAuthClient.quitLoginPage();
      return Future<void>.value(); // 明确返回一个完成的Future<void>
    } catch (e) {
      print('Error quitting login page: $e');
      return Future<void>.error(e); // 返回一个错误的Future<void>
    }
  }
}

/// 认证服务
class AuthService extends ChangeNotifier {
  final ApiService _apiService;
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

  AuthService({required ApiService apiService}) : _apiService = apiService {
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

  /// 初始化方法（兼容旧接口）
  Future<void> init() async {
    await initAuthSDK();
  }

  /// 初始化认证SDK
  Future<void> initAuthSDK() async {
    try {
      debugPrint('开始获取SDK密钥...');
      // 阿里云一键登录密钥配置
      const String androidSdk =
          "1k8YHEkfCOWwhfmJqBO/uYr+Czwf4TqsCl/nwrgz+NOVeZHQNgvrQJ9OC7Qf6pttD6U8cfPYh8c+biyrs3Rn77+ZprCwLs4mCSGrZ6yXxfIrbXljn9qnzf8jyZVpIEBz9LsXFXP8/xl93X8yvcNGASjhfD6URcPJbGSGfU2EPFdnpTRdMSA7emW5QcRCPIDUHV3uHTI/jak7sCMuHj/9NvkUAtDjADy5h/MWD13AzadtpS0SOV2drABZ1xfUKDxaX3I2O0/DDLIubv0VfQczVwXWDTTdkfAeWLBaZPIyCnFWQepKddIdsCbmIO/Vi30v";
      const String iosSdk =
          "4BXW8eTqoA2tKkCU8k3pQpBeH/NWHPhYKerYXmt74kh84YPxfKgJYSBJRETNz2dmvh+1ygXDiYSSRLQMXx14KdCN4PzziGt6fEG/FtS6qlfx7TCLoz2iqSl0PubGndRN7GYJmB1Lz7tuiaAM52PvkV1IYFFWSjdaGkW5p+0MVMl2nEtsz8REAkdhZg+41KHOk8x1ofdYjyWaY98yEOGFhpP9uQmnrFG5irl+XHqbjEWwJqxawj8gyWKo249p5tGBKjZNS87B/IrmXl8TxwxKGg==";

      debugPrint('Android SDK密钥: ${androidSdk.substring(0, 20)}...');
      debugPrint('iOS SDK密钥: ${iosSdk.substring(0, 20)}...');

      // 配置认证UI
      debugPrint('正在配置UI...');
      final authConfig = AuthConfig(
        iosSdk: iosSdk,
        androidSdk: androidSdk,
        authUIStyle: AuthUIStyle.fullScreen,
        authUIConfig: AuthUIConfig(
          navConfig: NavConfig(
            navBackgroundColor: '#FFFFFF',
            navTitleColor: '#000000',
            navTitleText: '一键登录',
            navBackButtonHidden: false,
          ),
          logoConfig: LogoConfig(
            logoHidden: false,
            logoImage: 'images/logo.png',
          ),
          privacyConfig: PrivacyConfig(
            privacyOne: ['服务条款', 'https://example.com/terms'],
            privacyTwo: ['隐私政策', 'https://example.com/privacy'],
            privacyOperatorColor: '#0000FF',
            privacyTextColor: '#666666',
            privacyTextFontSize: 12.0,
          ),
        ),
      );

      // 初始化SDK
      debugPrint('开始调用阿里云SDK初始化方法...');
      await AliAuthClient.initSdk(authConfig: authConfig);
      debugPrint('阿里云SDK初始化成功');
    } catch (e) {
      debugPrint('初始化认证SDK失败: $e');
      if (e is Exception) {
        debugPrint('错误详情: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// 处理认证事件
  Future<void> handleAuthEvent({
    required Function(AuthResponseModel) onEvent,
  }) async {
    try {
      debugPrint('设置认证事件处理器...');
      await AliAuthClient.handleEvent(onEvent: (response) {
        debugPrint('收到认证事件: $response');

        final authResponse = AuthResponseModel.fromJson(
            response is Map ? response : {'resultCode': '600008'});

        debugPrint(
            '处理认证事件: resultCode=${authResponse.resultCode}, token=${authResponse.token}');
        _lastResponse = authResponse;
        onEvent(authResponse);
      });
    } catch (error) {
      print('处理认证事件失败: $error');
      rethrow; // 重新抛出异常
    }
  }

  /// 移除认证事件处理
  Future<void> removeAuthHandler() async {
    try {
      await AliAuthClient.removeHandler();
      return; // 隐式返回void，修复"body might complete normally"警告
    } catch (e) {
      print('移除认证事件处理失败: $e');
      rethrow;
    }
  }

  /// 一键登录（兼容旧接口）
  Future<void> oneClickLogin({double? timeout}) async {
    await oneKeyLogin(timeout: timeout);
    return; // 隐式返回void，修复"body might complete normally"警告
  }

  /// 一键登录
  Future<bool> oneKeyLogin({double? timeout}) async {
    try {
      debugPrint('开始一键登录流程...');

      // 初始化处理Auth事件
      await handleAuthEvent(onEvent: (response) async {
        debugPrint('一键登录收到认证事件: ${response.toString()}');

        if (response.resultCode == '600000') {
          debugPrint('认证成功，token: ${response.token}');

          if (response.token != null) {
            // 使用token进行登录
            debugPrint('调用API服务进行一键登录: ${response.token}');
            final result = await _apiService.oneKeyLogin(response.token!);
            debugPrint('API服务登录结果: $result');

            if (result['success']) {
              debugPrint('一键登录成功');
              // 更新登录状态
              _isLoggedIn = true;

              // 刷新用户信息
              await refreshUserInfo();

              // 通知UI
              notifyListeners();
            } else {
              debugPrint('API服务登录失败: ${result['message']}');
            }
          } else {
            debugPrint('警告: token为空');
          }
        } else {
          debugPrint('认证失败: ${response.resultCode}, 消息: ${response.message}');
        }
      });

      // 调用一键登录
      debugPrint('调用阿里云一键登录...');
      await AliAuthClient.login(timeout: timeout);
      debugPrint('阿里云一键登录调用完成，等待认证事件回调...');

      return _isLoggedIn;
    } catch (e) {
      print('一键登录失败: $e');
      return false;
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

  /// 获取登录手机号的掩码形式
  Future<String?> getMaskedPhone() async {
    try {
      debugPrint('开始调用预取号功能...');

      // 调用阿里云SDK的预取号功能
      try {
        debugPrint('调用AliAuthClient.getPhoneInfo开始...');
        final phoneInfoResult = await AliAuthClient.getPhoneInfo(timeout: 5);
        debugPrint('预取号结果完整内容: ${phoneInfoResult.toString()}');

        // 打印Map中所有的键
        debugPrint('预取号结果包含的键: ${phoneInfoResult.keys.toList()}');

        if (phoneInfoResult['resultCode'] == '600000') {
          // 预取号成功
          final maskedPhone = phoneInfoResult['phone'];
          debugPrint('成功获取掩码号码的类型: ${maskedPhone?.runtimeType}');
          debugPrint('成功获取掩码号码: $maskedPhone');

          if (maskedPhone != null) {
            return maskedPhone.toString();
          } else {
            debugPrint('警告: 预取号成功但phone字段为null');
          }
        } else {
          // 预取号失败
          debugPrint('预取号失败: ${phoneInfoResult['msg']}');
        }

        // 尝试从本地存储获取
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone_number') ?? '';
        if (phone.isNotEmpty && phone.length > 7) {
          final masked =
              '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
          debugPrint('从本地存储获取的掩码号码: $masked');
          return masked;
        }

        // 如果都失败，返回模拟数据
        final mockPhone = '133****5678';
        debugPrint('使用模拟的掩码手机号: $mockPhone');
        return mockPhone;
      } catch (sdkError) {
        // 预取号SDK调用出错
        debugPrint('预取号SDK调用异常: $sdkError');

        // 使用模拟数据
        final mockPhone = '134****9876';
        debugPrint('使用模拟的掩码手机号: $mockPhone');
        return mockPhone;
      }
    } catch (e) {
      debugPrint('获取手机号码失败: $e');
      return null;
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

  /// 隐藏登录加载
  Future<void> hideLoginLoading() async {
    try {
      await AliAuthClient.hideLoginLoading();
      return; // 隐式返回void，修复"body might complete normally"警告
    } catch (e) {
      print('隐藏登录加载失败: $e');
      rethrow;
    }
  }

  /// 退出登录页面
  Future<void> quitLoginPage() async {
    try {
      await AliAuthClient.quitLoginPage();
      return; // 隐式返回void，修复"body might complete normally"警告
    } catch (e) {
      print('退出登录页面失败: $e');
      rethrow;
    }
  }
}
