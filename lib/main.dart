import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'database/database_init.dart';
import 'pages/goal_page.dart';
import 'package:linzaivision_primary/theme/app_theme.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/services/api_service.dart';
import 'package:linzaivision_primary/test/login_test_page.dart';

Future<void> main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库（仅在非 Web 平台）
  if (!kIsWeb) {
    initializeDatabase();
  }

  // 初始化认证服务
  try {
    final authService = AuthService();
    await authService.init();
    debugPrint('认证服务初始化成功');
  } catch (e) {
    debugPrint('认证服务初始化失败: $e');
    // 即使认证服务初始化失败，也继续启动应用
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建API服务实例 - 确保全局单例
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        // 先提供ApiService
        Provider<ApiService>.value(value: apiService),
        // 提供全局访问AuthService的能力
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'LinzaiVision',
        theme: AppTheme.createTheme(),
        home: const MyHomePage(),
      ),
    );
  }
}

// 添加一个包装类，用于添加测试入口
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GoalPage(),
      ],
    );
  }
}
