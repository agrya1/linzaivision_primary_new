import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_code_login_page.dart'; // 引入验证码登录页面
import 'package:linzaivision_primary/services/auth_service.dart'; // 引入认证服务

/// 登录页面 (一键登录主页)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _maskedPhoneNumber = '加载中...'; // 初始化为加载状态
  String _carrierInfo = '认证服务加载中...'; // 初始化为加载状态
  bool _agreedToTerms = false;
  bool _isLoadingOneClick = false;
  bool _isInitializing = true; // 是否正在初始化SDK
  bool _initFailed = false; // 初始化是否失败

  // AuthService实例
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    // 延迟到下一帧获取provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authService = Provider.of<AuthService>(context, listen: false);
      // 初始化SDK并预取号
      _initSDKAndFetchNumber();

      // 设置认证事件处理
      _setupAuthEventHandler();
    });
  }

  // 初始化SDK并获取本机掩码号码
  Future<void> _initSDKAndFetchNumber() async {
    setState(() {
      _isInitializing = true;
      _initFailed = false;
    });

    try {
      debugPrint('开始初始化阿里云SDK...');
      // 初始化SDK
      await _authService.init();
      debugPrint('阿里云SDK初始化成功');

      // 预取号并获取掩码手机号
      debugPrint('开始预取号...');
      await _fetchMaskedNumber();
      debugPrint('预取号成功');

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('阿里云SDK初始化或预取号失败: $e');
      if (e is Exception) {
        debugPrint('错误详情: ${e.toString()}');
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initFailed = true;
          _maskedPhoneNumber = '获取失败';
          _carrierInfo = '认证服务初始化失败';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('初始化失败: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // 获取本机掩码号码
  Future<void> _fetchMaskedNumber() async {
    try {
      debugPrint('开始获取掩码手机号...');
      // 获取掩码手机号
      final maskedPhone = await _authService.getMaskedPhone();
      debugPrint('掩码手机号获取结果: $maskedPhone');

      if (mounted) {
        setState(() {
          if (maskedPhone != null) {
            _maskedPhoneNumber = maskedPhone;
            debugPrint('成功获取掩码号码: $_maskedPhoneNumber');
            // 根据掩码号码前三位判断运营商
            final prefix = _maskedPhoneNumber.substring(0, 3);
            if (['134', '135', '136', '137', '138', '139', '150', '151', '152']
                .contains(prefix)) {
              _carrierInfo = '认证服务由中国移动提供';
            } else if (['130', '131', '132', '155', '156', '166']
                .contains(prefix)) {
              _carrierInfo = '认证服务由中国联通提供';
            } else {
              _carrierInfo = '认证服务由中国电信提供';
            }
          } else {
            _maskedPhoneNumber = '获取失败';
            _carrierInfo = '获取掩码号码失败';
            debugPrint('掩码号码为空');
          }
        });
      }
    } catch (e) {
      debugPrint('获取掩码手机号异常: $e');
      if (e is Exception) {
        debugPrint('错误详情: ${e.toString()}');
      }
      if (mounted) {
        setState(() {
          _maskedPhoneNumber = '获取失败';
          _carrierInfo = '获取掩码号码出错';
        });
      }
    }
  }

  // 设置认证事件处理
  Future<void> _setupAuthEventHandler() async {
    try {
      await _authService.handleAuthEvent(onEvent: (response) async {
        // 处理认证事件
        if (response.resultCode == '600000' && response.token != null) {
          // 登录成功处理
          if (mounted) {
            setState(() => _isLoadingOneClick = false);
            Navigator.pop(context, true);
          }
        } else {
          // 登录失败处理
          if (mounted) {
            setState(() => _isLoadingOneClick = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('登录失败: ${response.message}'),
                  backgroundColor: Colors.redAccent),
            );
          }
        }
      });
    } catch (e) {
      print('设置认证事件处理失败: $e');
    }
  }

  // 处理一键登录
  Future<void> _handleOneClickLogin() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读并同意服务条款和隐私政策')),
      );
      return;
    }

    setState(() => _isLoadingOneClick = true);

    try {
      // 调用一键登录
      await _authService.oneKeyLogin(timeout: 5.0);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingOneClick = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('一键登录错误: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // 重试初始化
  void _retryInit() {
    _initSDKAndFetchNumber();
  }

  void _navigateToVerificationCodeLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const VerificationCodeLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // 使用浅色背景，更符合参考图
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          // 使用黑色图标
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.center, // 默认就是 center
          mainAxisAlignment: MainAxisAlignment.center, // 让内容在垂直方向居中
          children: [
            const Spacer(flex: 2), // 顶部留白，权重2
            // 标题
            const Text(
              '新用户登录送会员',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50), // 调整间距

            // 初始化失败时显示重试按钮
            if (_initFailed) ...[
              const Text(
                '获取本机号码失败',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _retryInit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('重试'),
              ),
            ] else if (_isInitializing) ...[
              // 正在初始化，显示加载指示器
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
              const SizedBox(height: 20),
              const Text(
                '正在获取本机号码...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ] else ...[
              // 显示手机号
              Text(
                _maskedPhoneNumber,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10), // 调整间距
              // 运营商信息
              Text(
                _carrierInfo,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6), // 调整间距
              const Text(
                '未注册的手机号验证通过后将自动注册',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],

            // const Spacer(), // 移除Spacer，让内容更集中
            const Spacer(flex: 3), // 中间留白，权重3
            // 服务条款
            _buildTermsCheckbox(),
            const SizedBox(height: 25), // 调整间距
            // 一键登录按钮
            _buildOneClickLoginButton(),
            const SizedBox(height: 16),
            // 其他号码登录按钮
            _buildOtherLoginButton(),
            const Spacer(flex: 1), // 底部留白，权重1
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // 尝试居中对齐 Checkbox 和文本
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (bool? value) {
              setState(() {
                _agreedToTerms = value ?? false;
              });
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: Colors.black, // 选中颜色
            checkColor: Colors.white, // 对勾颜色
            side: BorderSide(color: Colors.grey[400]!), // 边框颜色
            visualDensity: VisualDensity.compact, // 使 Checkbox 更紧凑
          ),
        ),
        const SizedBox(width: 6), // 调整间距
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[600], height: 1.4), // 调整行高
              children: [
                const TextSpan(text: '我们的服务依赖于使用抖音账号登录，请阅读并同意'),
                // 注意：协议名称前后可以加空格，避免粘连影响换行
                const TextSpan(text: ' '),
                TextSpan(
                  text: '《中国电信认证服务条款》',
                  style: const TextStyle(color: Colors.black), // 协议颜色
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // TODO: 跳转到电信服务条款页面
                      print('Navigate to Telecom Terms');
                    },
                ),
                const TextSpan(text: ' 及 '), // 使用空格分隔
                TextSpan(
                  text: '《用户登录指引协议》',
                  style: const TextStyle(color: Colors.black),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // TODO: 跳转到用户登录指引协议页面
                      print('Navigate to User Agreement');
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOneClickLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoadingOneClick || _isInitializing || _initFailed
            ? null
            : _handleOneClickLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // 更圆的按钮
          ),
          elevation: 0, // 参考图无阴影
        ),
        child: _isLoadingOneClick
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '本机号码一键登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildOtherLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _navigateToVerificationCodeLogin,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.grey, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // 圆形按钮
          ),
        ),
        child: const Text(
          '其他号码登录',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 清理认证事件处理
    _authService.removeAuthHandler().catchError((e) {
      print('清理认证事件处理失败: $e');
    });
    super.dispose();
  }
}
