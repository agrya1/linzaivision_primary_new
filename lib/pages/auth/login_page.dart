import 'package:flutter/material.dart';
import 'verification_code_login_page.dart'; // 引入验证码登录页面

/// 登录页面 (一键登录主页)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    // 在初始化后立即重定向到验证码登录页面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectToVerificationCodeLogin();
    });
  }

  // 自动重定向到验证码登录页面
  void _redirectToVerificationCodeLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const VerificationCodeLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载中的界面，这个界面实际上不会显示很久，因为会被重定向
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('正在准备登录页面...'),
          ],
        ),
      ),
    );
  }
}
