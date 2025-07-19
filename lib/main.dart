import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'database/database_init.dart';
import 'pages/goal_page.dart';
import 'package:linzaivision_primary/theme/app_theme.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/services/api_service.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/utils/error_handler.dart';

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
    
    // 创建数据库助手实例
    final databaseHelper = DatabaseHelper();
    
    // 创建仓库实例
    final goalRepository = GoalRepositoryImpl(databaseHelper);

    return MultiProvider(
      providers: [
        // 先提供ApiService
        Provider<ApiService>.value(value: apiService),
        // 提供数据库助手
        Provider<DatabaseHelper>.value(value: databaseHelper),
        // 提供目标仓库
        Provider<GoalRepository>.value(value: goalRepository),
        // 提供全局访问AuthService的能力
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(),
        ),
        // 提供GoalBloc
        BlocProvider<GoalBloc>(
          create: (context) => GoalBloc(
            repository: context.read<GoalRepository>(),
          ),
        ),
      ],
      child: ErrorBoundary(
        child: MaterialApp(
          title: '临在意识',
          theme: AppTheme.createTheme(),
          home: const MyHomePage(),
        ),
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
