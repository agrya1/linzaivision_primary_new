import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // 引入Timer
import 'package:provider/provider.dart';
import 'package:linzaivision_primary/services/auth_service.dart'; // 引入认证服务

/// 验证码登录页面
class VerificationCodeLoginPage extends StatefulWidget {
  const VerificationCodeLoginPage({super.key});

  @override
  State<VerificationCodeLoginPage> createState() =>
      _VerificationCodeLoginPageState();
}

class _VerificationCodeLoginPageState extends State<VerificationCodeLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController(); // 新增验证码控制器
  bool _agreedToTerms = false;
  bool _isLoadingGetCode = false;
  bool _isLoadingLogin = false;
  bool _canGetCode = false; // 是否可以获取验证码（手机号格式正确）
  Timer? _timer;
  int _countdown = 60;

  // AuthService实例
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    // 延迟到下一帧获取provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authService = Provider.of<AuthService>(context, listen: false);
    });

    _phoneController.addListener(() {
      // 简单校验手机号长度，实际应更严格
      final phone = _phoneController.text;
      setState(() {
        _canGetCode = phone.length == 11 && _timer == null;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel(); // 取消旧的timer
    _countdown = 60;
    setState(() {
      _isLoadingGetCode = false; // 获取成功后停止loading
      _canGetCode = false; // 开始倒计时后禁用按钮
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _timer?.cancel();
          _timer = null;
          _canGetCode = _phoneController.text.length == 11; // 倒计时结束，重新检查手机号
        }
      });
    });
  }

  Future<void> _handleGetCode() async {
    // 隐藏键盘
    FocusScope.of(context).unfocus();
    if (!_canGetCode || _isLoadingGetCode || _timer != null) return;

    setState(() => _isLoadingGetCode = true);

    try {
      // 调用服务发送验证码
      final success =
          await _authService.sendVerificationCode(_phoneController.text);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('验证码已发送'), backgroundColor: Colors.green),
        );
        _startTimer(); // 启动倒计时
      } else {
        setState(() => _isLoadingGetCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('获取验证码失败，请稍后重试'),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingGetCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('获取验证码失败: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读并同意服务条款和隐私政策')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return; // 增加表单校验

    setState(() => _isLoadingLogin = true);
    FocusScope.of(context).unfocus();

    try {
      // 调用验证码登录
      final success = await _authService.loginWithCode(
          _phoneController.text, _codeController.text);

      if (!mounted) return;

      if (success) {
        // 登录成功
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
        // 返回登录成功的结果
        Navigator.pop(context, true);
      } else {
        // 登录失败
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('登录失败，请检查验证码是否正确'),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLogin = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                '手机号登录/注册', // 调整标题
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '未注册的手机号验证通过后将自动注册',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 50),

              // 手机号输入
              _buildPhoneInput(),
              const SizedBox(height: 20),

              // 验证码输入
              _buildCodeInput(),
              const SizedBox(height: 40),

              // 登录按钮
              _buildLoginButton(),
              const Spacer(),

              // 服务条款
              _buildTermsCheckbox(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11)
      ],
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
              left: 0, right: 10, top: 12, bottom: 12), // 调整内边距使+86垂直居中
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '+86',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              const SizedBox(width: 5),
              Container(height: 20, width: 1, color: Colors.grey[300]), // 分割线
            ],
          ),
        ),
        hintText: '请输入手机号',
        hintStyle: TextStyle(
            fontSize: 18,
            color: Colors.grey[400],
            fontWeight: FontWeight.normal),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12), // 调整垂直内边距
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入手机号';
        }
        if (value.length != 11) {
          return '请输入有效的11位手机号';
        }
        return null;
      },
    );
  }

  Widget _buildCodeInput() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6)
      ],
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
      decoration: InputDecoration(
        hintText: '请输入验证码',
        hintStyle: TextStyle(
            fontSize: 18,
            color: Colors.grey[400],
            fontWeight: FontWeight.normal),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixIcon: TextButton(
          onPressed: _canGetCode && !_isLoadingGetCode && _timer == null
              ? _handleGetCode
              : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(80, 36), // 固定按钮大小
          ),
          child: _isLoadingGetCode
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.grey),
                )
              : Text(
                  _timer == null ? '获取验证码' : '${_countdown}s后重试',
                  style: TextStyle(
                    fontSize: 14,
                    color: _canGetCode && _timer == null
                        ? Colors.black
                        : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入验证码';
        }
        if (value.length != 6) {
          return '请输入6位验证码';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoadingLogin ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: _isLoadingLogin
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登录 / 注册',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    // 与login_page.dart中的样式类似，但文本可能略有不同
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            activeColor: Colors.black,
            checkColor: Colors.white,
            side: BorderSide(color: Colors.grey[400]!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
              children: [
                const TextSpan(text: '我已阅读并同意'),
                TextSpan(
                  text: '《用户协议》',
                  style: const TextStyle(color: Colors.black),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // TODO: 跳转到用户协议页面
                      print('Navigate to User Agreement');
                    },
                ),
                const TextSpan(text: '和'),
                TextSpan(
                  text: '《隐私政策》',
                  style: const TextStyle(color: Colors.black),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // TODO: 跳转到隐私政策页面
                      print('Navigate to Privacy Policy');
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
