import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/pages/auth/login_page.dart';
import 'package:linzaivision_primary/pages/auth/verification_code_login_page.dart';
import 'package:linzaivision_primary/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录功能测试页面
/// 用于测试登录流程和UI状态联动
class LoginTestPage extends StatefulWidget {
  const LoginTestPage({super.key});

  @override
  State<LoginTestPage> createState() => _LoginTestPageState();
}

class _LoginTestPageState extends State<LoginTestPage> {
  final TextEditingController _logController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic> _userInfo = {};
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  // 加载当前用户状态
  Future<void> _loadUserState() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _token = prefs.getString('auth_token');
        _userInfo = {
          'user_id': prefs.getString('user_id') ?? '',
          'user_name': prefs.getString('user_name') ?? '',
          'phone_number': prefs.getString('phone_number') ?? '',
          'user_avatar': prefs.getString('user_avatar') ?? '',
          'member_level': prefs.getInt('member_level') ?? 0,
        };
      });
    } catch (e) {
      _log('加载用户状态失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 记录日志
  void _log(String message) {
    setState(() {
      _logController.text =
          '${DateTime.now().toString().substring(11, 19)} $message\n${_logController.text}';
    });
  }

  // 清除日志
  void _clearLog() {
    setState(() {
      _logController.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isLoggedIn = authService.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录功能测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUserState();
              _log('刷新用户状态');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 当前登录状态
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLoggedIn ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLoggedIn ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '登录状态: ${isLoggedIn ? "已登录" : "未登录"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isLoggedIn) ...[
                        const SizedBox(height: 8),
                        Text('用户ID: ${authService.userId ?? "未知"}'),
                        Text('用户名: ${authService.userName ?? "未知"}'),
                        Text('手机号: ${authService.phoneNumber ?? "未知"}'),
                        if (authService.avatarUrl != null)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(authService.avatarUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                // 测试按钮区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '测试操作',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () => _testOneKeyLogin(context),
                            child: const Text('一键登录'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                _testVerificationCodeLogin(context),
                            child: const Text('验证码登录'),
                          ),
                          ElevatedButton(
                            onPressed:
                                isLoggedIn ? () => _testLogout(context) : null,
                            child: const Text('登出'),
                          ),
                          ElevatedButton(
                            onPressed: () => _testSettingsPage(context),
                            child: const Text('设置页面'),
                          ),
                          ElevatedButton(
                            onPressed: isLoggedIn
                                ? () => _testRefreshUserInfo(context)
                                : null,
                            child: const Text('刷新用户信息'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 本地存储的用户信息
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本地存储信息',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Token: ${_token != null && _token!.isNotEmpty ? "${_token!.substring(0, min(_token!.length, 10))}..." : "未设置"}'),
                      Text('用户ID: ${_userInfo['user_id'] ?? "未设置"}'),
                      Text('用户名: ${_userInfo['user_name'] ?? "未设置"}'),
                      Text('手机号: ${_userInfo['phone_number'] ?? "未设置"}'),
                      Text('会员级别: ${_userInfo['member_level'] ?? "未设置"}'),
                    ],
                  ),
                ),

                // 日志区域
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _logController,
                      maxLines: null,
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: '日志区域',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // 测试一键登录
  Future<void> _testOneKeyLogin(BuildContext context) async {
    _log('开始测试一键登录');
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );

      if (result == true) {
        _log('一键登录成功');
        await _loadUserState();
      } else {
        _log('一键登录取消或失败');
      }
    } catch (e) {
      _log('一键登录出错: $e');
    }
  }

  // 测试验证码登录
  Future<void> _testVerificationCodeLogin(BuildContext context) async {
    _log('开始测试验证码登录');
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const VerificationCodeLoginPage()),
      );

      if (result == true) {
        _log('验证码登录成功');
        await _loadUserState();
      } else {
        _log('验证码登录取消或失败');
      }
    } catch (e) {
      _log('验证码登录出错: $e');
    }
  }

  // 测试登出
  Future<void> _testLogout(BuildContext context) async {
    _log('开始测试登出');
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.logout();

      if (result) {
        _log('登出成功');
        await _loadUserState();
      } else {
        _log('登出失败');
      }
    } catch (e) {
      _log('登出出错: $e');
    }
  }

  // 测试进入设置页面
  Future<void> _testSettingsPage(BuildContext context) async {
    _log('进入设置页面');
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );

      _log('从设置页面返回');
      await _loadUserState();
    } catch (e) {
      _log('设置页面出错: $e');
    }
  }

  // 测试刷新用户信息
  Future<void> _testRefreshUserInfo(BuildContext context) async {
    _log('开始刷新用户信息');
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // 调用内部方法刷新用户信息
      await authService.refreshUserInfo();
      _log('刷新用户信息成功');
      await _loadUserState();
    } catch (e) {
      _log('刷新用户信息出错: $e');
    }
  }
}

// 计算最小值辅助函数
int min(int a, int b) => a < b ? a : b;
