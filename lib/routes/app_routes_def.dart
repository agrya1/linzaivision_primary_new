import 'typed_route.dart';
import 'app_routes.dart';

/// 应用路由定义
/// 
/// 使用类型安全的路由定义
class AppRoutesDef {
  /// 首页路由
  static const home = NoArgsRoute(name: AppRoutes.home);
  
  /// 目标页路由
  static const goal = NoArgsRoute(name: AppRoutes.goal);
  
  /// 意识探索页路由
  static const explore = NoArgsRoute(name: AppRoutes.explore);
  
  /// 设置页路由
  static const settings = NoArgsRoute(name: AppRoutes.settings);
  
  /// 主题设置页路由
  static const themeSettings = NoArgsRoute(name: AppRoutes.themeSettings);
  
  /// 语言设置页路由
  static const languageSettings = NoArgsRoute(name: AppRoutes.languageSettings);
  
  /// 首页设置页路由
  static const homePageSettings = NoArgsRoute(name: AppRoutes.homePageSettings);
  
  /// 目标详情页路由
  static final goalDetails = TypedRoute<GoalDetailsArgs>(
    name: AppRoutes.goalDetails,
    createDefaultArgs: () => GoalDetailsArgs(goalId: 0),
  );
  
  /// 意识卡片详情页路由
  static final exploreCardDetails = TypedRoute<ExploreCardDetailsArgs>(
    name: AppRoutes.exploreCardDetails,
    createDefaultArgs: () => ExploreCardDetailsArgs(cardId: ''),
  );
  
  /// 登录页路由
  static const login = NoArgsRoute(name: AppRoutes.login);
  
  /// 帮助页路由
  static const help = NoArgsRoute(name: AppRoutes.help);
  
  /// 反馈页路由
  static const feedback = NoArgsRoute(name: AppRoutes.feedback);
  
  /// 关于页路由
  static const about = NoArgsRoute(name: AppRoutes.about);
  
  /// 团队其他应用页路由
  static const teamApps = NoArgsRoute(name: AppRoutes.teamApps);
}

/// 目标详情页参数
class GoalDetailsArgs {
  /// 目标ID
  final int goalId;
  
  /// 是否显示编辑按钮
  final bool showEditButton;
  
  /// 构造函数
  const GoalDetailsArgs({
    required this.goalId,
    this.showEditButton = true,
  });
}

/// 意识卡片详情页参数
class ExploreCardDetailsArgs {
  /// 卡片ID
  final String cardId;
  
  /// 构造函数
  const ExploreCardDetailsArgs({
    required this.cardId,
  });
} 