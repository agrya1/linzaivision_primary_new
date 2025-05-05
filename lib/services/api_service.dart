import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 请根据实际后端服务地址修改
  static const String _baseUrl = 'http://192.168.3.51:80';

  // 是否使用本地模拟数据（无后端服务时使用）
  static const bool _useMockData = true;

  // 登录相关接口
  static const String _oneKeyLoginEndpoint = '/login/oneKey';
  static const String _sendCodeEndpoint = '/login/sendCode';
  static const String _phoneCodeLoginEndpoint = '/login/phoneCode';
  static const String _isLoginEndpoint = '/login/isLogin';
  static const String _logoutEndpoint = '/login/logout';

  // 用户信息接口
  static const String _getUserInfoEndpoint = '/user/get';

  // HTTP客户端
  final http.Client _client = http.Client();

  // 获取设备信息（如需）
  Future<String?> _getDeviceInfoJson() async {
    // 这里可根据实际平台获取设备信息，暂用空实现
    // 如需集成device_info_plus等插件可在此实现
    return null;
  }

  // HTTP请求头，支持X-Device-Info
  Future<Map<String, String>> _getHeadersAsync({String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final deviceInfo = await _getDeviceInfoJson();
    if (deviceInfo != null) {
      headers['X-Device-Info'] = deviceInfo;
    }
    return headers;
  }

  // 阿里云一键登录
  Future<Map<String, dynamic>> oneKeyLogin(String accessToken,
      {bool remember = true}) async {
    try {
      debugPrint('API服务: 开始一键登录, accessToken: $accessToken');

      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('API服务: 使用模拟数据进行一键登录');
        // 模拟等待1秒
        await Future.delayed(const Duration(seconds: 1));

        // 生成一个随机电话号码用于演示
        final mockPhone =
            '138${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 16)}';
        debugPrint('API服务: 生成模拟手机号: $mockPhone');

        // 模拟登录成功
        final mockUserData = {
          'uuid': 'mock-user-id-${DateTime.now().millisecondsSinceEpoch}',
          'name': '一键登录用户',
          'phone': mockPhone,
          'headUrl': '', // 空字符串表示使用默认头像
          'memberLevel': 0,
          'memberLevelDesc': '普通会员',
          'memberValidDesc': '永久有效'
        };

        // 保存模拟用户信息
        await _saveUserInfo(mockUserData);
        debugPrint('API服务: 保存模拟用户信息成功');

        // 保存模拟Token
        final mockToken =
            'mock-onekey-token-${DateTime.now().millisecondsSinceEpoch}';
        await _saveUserToken(mockToken);
        debugPrint('API服务: 保存模拟Token成功: $mockToken');

        final result = {
          'success': true,
          'message': '登录成功',
          'data': {
            'user': mockUserData,
            'saTokenInfo': {'tokenValue': mockToken, 'tokenName': 'Bearer'}
          }
        };
        debugPrint('API服务: 返回登录成功结果: $result');
        return result;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl$_oneKeyLoginEndpoint'),
        headers: await _getHeadersAsync(),
        body: jsonEncode({
          'accessToken': accessToken,
          'remember': remember,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API服务: 一键登录异常: $e');
      return {'success': false, 'message': '网络错误: $e', 'data': null};
    }
  }

  // 发送短信验证码 - 新方法名，用于和flutter_ali_auth集成
  Future<Map<String, dynamic>> sendSmsCode(String phone,
      {String? token}) async {
    try {
      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('使用模拟数据：发送验证码 - 手机号: $phone');
        // 模拟等待1秒
        await Future.delayed(const Duration(seconds: 1));
        // 返回模拟成功响应
        return {
          'success': true,
          'message': '验证码发送成功',
          'data': {'code': '123456'} // 模拟验证码为123456
        };
      }

      final Map<String, dynamic> requestBody = {
        'phone': phone,
      };
      if (token != null) {
        requestBody['token'] = token;
      }
      final response = await _client.post(
        Uri.parse('$_baseUrl$_sendCodeEndpoint'),
        headers: await _getHeadersAsync(),
        body: jsonEncode(requestBody),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('发送验证码异常: $e');
      return {'success': false, 'message': '网络错误: $e', 'data': null};
    }
  }

  // 保留旧方法以保持兼容性
  Future<Map<String, dynamic>> sendVerificationCode(String phone,
      {String? token}) async {
    return sendSmsCode(phone, token: token);
  }

  // 验证码登录
  Future<Map<String, dynamic>> phoneCodeLogin(String phone, String code,
      {bool remember = true}) async {
    try {
      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('使用模拟数据：验证码登录 - 手机号: $phone, 验证码: $code');
        // 模拟等待1秒
        await Future.delayed(const Duration(seconds: 1));

        // 模拟验证码检查（这里假设任何123456的验证码都有效）
        if (code == '123456') {
          // 模拟登录成功
          final mockUserData = {
            'uuid': 'mock-user-id-12345',
            'name': '测试用户',
            'phone': phone,
            'headUrl': '', // 空字符串表示使用默认头像
            'memberLevel': 0,
            'memberLevelDesc': '普通会员',
            'memberValidDesc': '永久有效'
          };

          // 保存模拟用户信息
          await _saveUserInfo(mockUserData);

          // 保存模拟Token
          await _saveUserToken(
              'mock-auth-token-${DateTime.now().millisecondsSinceEpoch}');

          return {
            'success': true,
            'message': '登录成功',
            'data': {
              'user': mockUserData,
              'saTokenInfo': {
                'tokenValue':
                    'mock-auth-token-${DateTime.now().millisecondsSinceEpoch}',
                'tokenName': 'Bearer'
              }
            }
          };
        } else {
          // 模拟验证码错误
          return {'success': false, 'message': '验证码错误', 'data': null};
        }
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl$_phoneCodeLoginEndpoint'),
        headers: await _getHeadersAsync(),
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'remember': remember,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('验证码登录异常: $e');
      return {'success': false, 'message': '网络错误: $e', 'data': null};
    }
  }

  // 获取用户信息
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': '未登录', 'data': null};
      }

      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('使用模拟数据：获取用户信息');
        // 模拟等待0.5秒
        await Future.delayed(const Duration(milliseconds: 500));

        // 尝试从本地获取保存的用户信息
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? '';
        final userName = prefs.getString('user_name') ?? '测试用户';
        final phoneNumber = prefs.getString('phone_number') ?? '';
        final memberLevel = prefs.getInt('member_level') ?? 0;
        final memberLevelDesc = prefs.getString('member_level_desc') ?? '普通会员';
        final memberValidDesc = prefs.getString('member_valid_desc') ?? '永久有效';

        final mockUserData = {
          'uuid': userId,
          'name': userName,
          'phone': phoneNumber,
          'headUrl': '',
          'memberLevel': memberLevel,
          'memberLevelDesc': memberLevelDesc,
          'memberValidDesc': memberValidDesc
        };

        return {
          'success': true,
          'message': '获取用户信息成功',
          'data': {'user': mockUserData}
        };
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl$_getUserInfoEndpoint'),
        headers: await _getHeadersAsync(token: token),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('获取用户信息异常: $e');
      return {'success': false, 'message': '网络错误: $e', 'data': null};
    }
  }

  // 检查登录状态
  Future<bool> isLoggedIn() async {
    try {
      final token = await _getAuthToken();

      if (token == null) {
        return false;
      }

      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('使用模拟数据：检查登录状态');
        // 只要有token就认为是已登录
        return true;
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl$_isLoginEndpoint'),
        headers: await _getHeadersAsync(token: token),
      );

      final result = _handleResponse(response);

      return result['success'] && result['data'] == true;
    } catch (e) {
      debugPrint('检查登录状态异常: $e');
      return false;
    }
  }

  // 退出登录
  Future<Map<String, dynamic>> logout() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'message': '未登录', 'data': null};
      }

      // 如果使用本地模拟数据
      if (_useMockData) {
        debugPrint('使用模拟数据：退出登录');
        // 模拟等待0.5秒
        await Future.delayed(const Duration(milliseconds: 500));
        // 清除用户信息
        await _clearUserInfo();
        return {'success': true, 'message': '退出登录成功', 'data': null};
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl$_logoutEndpoint'),
        headers: await _getHeadersAsync(token: token),
      );
      final result = _handleResponse(response);
      if (result['success']) {
        await _clearUserInfo();
      }
      return result;
    } catch (e) {
      debugPrint('退出登录异常: $e');
      return {'success': false, 'message': '网络错误: $e', 'data': null};
    }
  }

  // 处理HTTP响应
  Map<String, dynamic> _handleResponse(http.Response response) {
    final jsonResponse = jsonDecode(response.body);

    if (response.statusCode == 200 && jsonResponse['code'] == 200) {
      // 成功响应
      if (jsonResponse.containsKey('data') &&
          jsonResponse['data'] != null &&
          jsonResponse['data'] is Map &&
          jsonResponse['data'].containsKey('saTokenInfo')) {
        // 保存登录凭证
        _saveUserToken(jsonResponse['data']['saTokenInfo']['tokenValue']);

        // 保存用户信息
        if (jsonResponse['data'].containsKey('user')) {
          _saveUserInfo(jsonResponse['data']['user']);
        }
      }

      return {
        'success': true,
        'message': jsonResponse['message'] ?? '成功',
        'data': jsonResponse['data']
      };
    } else {
      // 错误响应
      return {
        'success': false,
        'message': jsonResponse['message'] ?? '请求失败',
        'data': null
      };
    }
  }

  // 保存token
  Future<void> _saveUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // 保存用户信息
  Future<void> _saveUserInfo(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['uuid'] ?? '');
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_avatar', user['headUrl'] ?? '');
    await prefs.setString('phone_number', user['phone'] ?? '');
    await prefs.setInt('member_level', user['memberLevel'] ?? 0);
    await prefs.setString('member_level_desc', user['memberLevelDesc'] ?? '');
    await prefs.setString('member_valid_desc', user['memberValidDesc'] ?? '');
  }

  // 获取本地token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 清除本地用户信息
  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_avatar');
    await prefs.remove('phone_number');
    await prefs.remove('member_level');
    await prefs.remove('member_level_desc');
    await prefs.remove('member_valid_desc');
  }
}
