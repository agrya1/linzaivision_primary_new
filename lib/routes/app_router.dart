import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../pages/goal_page.dart';
import '../pages/settings_page.dart'; // 修改为原始设置页面
import '../pages/settings/theme_settings_page.dart';
import '../pages/settings/language_settings_page.dart';
import '../pages/settings/home_page_settings_page.dart';
import '../pages/developer_settings_page.dart';
import '../pages/explore_page.dart';
import '../pages/help_page.dart';
import '../pages/feedback_page.dart';
import '../pages/about_page.dart';
import '../pages/team_apps_page.dart';
import '../pages/auth/login_page.dart';
import 'home_page_router.dart';
import 'route_middleware.dart';
import '../models/goal.dart'; // Added import for Goal model

/// 应用路由生成器
class AppRouter {
  static final List<RouteMiddleware> _middlewares = [];

  /// 添加路由中间件
  static void addMiddleware(RouteMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// 清除所有中间件
  static void clearMiddlewares() {
    _middlewares.clear();
  }

  /// 根据路由名称生成对应的页面路由
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // 执行所有中间件的beforeEnter方法
    bool shouldProceed = true;
    for (final middleware in _middlewares) {
      shouldProceed = middleware.beforeEnter(settings) && shouldProceed;
      if (!shouldProceed) {
        // 如果任何中间件返回false，则拦截路由
        return _buildErrorRoute('路由被拦截: ${settings.name}');
      }
    }

    // 根据路由名称生成对应的路由
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomePageRouter(),
        );
      case AppRoutes.goal:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const GoalPage(),
        );
      case AppRoutes.goalDetails:
        // 解析参数
        final args = settings.arguments as Map<String, dynamic>;
        final goalId = args['goalId'] as int;

        // 创建GoalPage实例，传入goalId
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => GoalPage(
            parentGoal: Goal(
              id: goalId,
              title: '',
              imagePath: 'assets/images/default/default.jpg',
              createdTime: DateTime.now(),
            ),
          ),
        );
      case AppRoutes.explore:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ExplorePage(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsPage(),
        );
      case AppRoutes.themeSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ThemeSettingsPage(),
        );
      case AppRoutes.languageSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LanguageSettingsPage(),
        );
      case AppRoutes.homePageSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomePageSettingsPage(),
        );
      case AppRoutes.developerSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DeveloperSettingsPage(),
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
      case AppRoutes.help:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HelpPage(),
        );
      case AppRoutes.feedback:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const FeedbackPage(),
        );
      case AppRoutes.about:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AboutPage(),
        );
      case AppRoutes.teamApps:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TeamAppsPage(),
        );
      default:
        return _buildErrorRoute('未找到路由: ${settings.name}');
    }
  }

  /// 构建错误路由
  static Route<dynamic> _buildErrorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}
