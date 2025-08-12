import 'dart:async';
import 'package:flutter/foundation.dart';
import 'loading_task.dart';
import 'loading_state.dart';
import '../../database/database_helper.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../repository/goal_repository.dart';
import '../../repository/explore_repository.dart';
import '../../repository/settings_repository.dart';
import '../../repository/profile_repository.dart';
import '../../repository/auth_repository.dart';

/// 应用启动加载任务集合
class AppLoadingTasks {
  /// 获取应用启动时的所有加载任务
  static List<LoadingTask> getStartupTasks({
    required DatabaseHelper databaseHelper,
    required StorageService storageService,
    required AuthService authService,
    required GoalRepository goalRepository,
    required ExploreRepository exploreRepository,
    required SettingsRepository settingsRepository,
    required ProfileRepository profileRepository,
    required AuthRepository authRepository,
  }) {
    return [
      // 第一层：关键基础设施 (Critical Priority)
      LoadingTask<void>(
        id: 'database_init',
        name: '初始化数据库',
        description: '初始化SQLite数据库连接和表结构',
        priority: LoadingPriority.critical,
        executor: (context) => _initializeDatabase(databaseHelper),
        timeout: const Duration(seconds: 10),
        maxRetries: 2,
        requiresNetwork: false,
        tags: ['infrastructure', 'database'],
      ),

      LoadingTask<void>(
        id: 'storage_init',
        name: '初始化存储服务',
        description: '初始化本地存储服务和SharedPreferences',
        priority: LoadingPriority.critical,
        executor: (context) => _initializeStorage(storageService),
        timeout: const Duration(seconds: 5),
        maxRetries: 2,
        requiresNetwork: false,
        tags: ['infrastructure', 'storage'],
      ),

      // 第二层：核心数据加载 (High Priority)
      LoadingTask<Map<String, dynamic>>(
        id: 'settings_load',
        name: '加载应用设置',
        description: '从本地存储加载用户设置和偏好',
        priority: LoadingPriority.high,
        dependencies: ['storage_init'],
        executor: (context) => _loadSettings(settingsRepository),
        timeout: const Duration(seconds: 5),
        maxRetries: 3,
        requiresNetwork: false,
        tags: ['settings', 'user_data'],
      ),

      LoadingTask<Map<String, dynamic>>(
        id: 'auth_check',
        name: '检查登录状态',
        description: '验证用户登录状态和令牌有效性',
        priority: LoadingPriority.high,
        dependencies: ['storage_init'],
        executor: (context) => _checkAuthStatus(authRepository),
        timeout: const Duration(seconds: 8),
        maxRetries: 2,
        requiresNetwork: true,
        tags: ['auth', 'user_data'],
      ),

      LoadingTask<List<dynamic>>(
        id: 'goals_load',
        name: '加载目标数据',
        description: '从数据库加载用户的目标和子目标',
        priority: LoadingPriority.high,
        dependencies: ['database_init'],
        executor: (context) => _loadGoalsData(goalRepository),
        timeout: const Duration(seconds: 15),
        maxRetries: 3,
        requiresNetwork: false,
        tags: ['goals', 'user_data'],
      ),

      // 第三层：次要数据加载 (Normal Priority)
      LoadingTask<Map<String, dynamic>>(
        id: 'profile_load',
        name: '加载用户资料',
        description: '加载用户个人资料和偏好设置',
        priority: LoadingPriority.normal,
        dependencies: ['auth_check'],
        executor: (context) => _loadUserProfile(profileRepository),
        timeout: const Duration(seconds: 8),
        maxRetries: 2,
        requiresNetwork: true,
        tags: ['profile', 'user_data'],
      ),

      LoadingTask<List<dynamic>>(
        id: 'explore_load',
        name: '加载探索卡片',
        description: '加载意识探索卡片数据',
        priority: LoadingPriority.normal,
        dependencies: ['database_init'],
        executor: (context) => _loadExploreCards(exploreRepository),
        timeout: const Duration(seconds: 10),
        maxRetries: 3,
        requiresNetwork: false,
        tags: ['explore', 'content'],
      ),

      // 第四层：背景数据和服务 (Low Priority)
      LoadingTask<void>(
        id: 'sync_service_init',
        name: '初始化同步服务',
        description: '启动实时数据同步和跨页面状态管理',
        priority: LoadingPriority.low,
        dependencies: ['goals_load', 'explore_load'],
        executor: (context) => _initializeSyncService(),
        timeout: const Duration(seconds: 8),
        maxRetries: 1,
        requiresNetwork: false,
        tags: ['sync', 'service'],
      ),

      LoadingTask<void>(
        id: 'performance_init',
        name: '初始化性能监控',
        description: '启动性能监控和错误收集服务',
        priority: LoadingPriority.background,
        dependencies: ['settings_load'],
        executor: (context) => _initializePerformanceMonitoring(),
        timeout: const Duration(seconds: 5),
        maxRetries: 1,
        requiresNetwork: false,
        tags: ['performance', 'monitoring'],
      ),

      LoadingTask<void>(
        id: 'cache_warmup',
        name: '预热缓存',
        description: '预加载常用数据到内存缓存',
        priority: LoadingPriority.background,
        dependencies: ['goals_load', 'explore_load'],
        executor: (context) => _warmupCache(),
        timeout: const Duration(seconds: 10),
        maxRetries: 1,
        requiresNetwork: false,
        tags: ['cache', 'optimization'],
      ),
    ];
  }

  /// 获取页面级加载任务
  static List<LoadingTask> getPageLoadingTasks({
    required String pageName,
    required GoalRepository goalRepository,
    required ExploreRepository exploreRepository,
  }) {
    switch (pageName) {
      case 'goal_page':
        return _getGoalPageTasks(goalRepository);
      case 'explore_page':
        return _getExplorePageTasks(exploreRepository);
      default:
        return [];
    }
  }

  /// 获取GoalPage的加载任务
  static List<LoadingTask> _getGoalPageTasks(GoalRepository goalRepository) {
    return [
      LoadingTask<List<dynamic>>(
        id: 'goal_page_data',
        name: '加载目标页面数据',
        description: '加载当前页面的目标数据和状态',
        priority: LoadingPriority.high,
        executor: (context) => _loadGoalPageData(goalRepository, context),
        timeout: const Duration(seconds: 10),
        tags: ['goal_page', 'page_data'],
      ),
      LoadingTask<void>(
        id: 'goal_page_ui_state',
        name: '恢复UI状态',
        description: '恢复页面的UI状态和用户偏好',
        priority: LoadingPriority.normal,
        dependencies: ['goal_page_data'],
        executor: (context) => _restoreGoalPageUIState(context),
        timeout: const Duration(seconds: 3),
        tags: ['goal_page', 'ui_state'],
      ),
    ];
  }

  /// 获取ExplorePage的加载任务
  static List<LoadingTask> _getExplorePageTasks(
      ExploreRepository exploreRepository) {
    return [
      LoadingTask<List<dynamic>>(
        id: 'explore_page_data',
        name: '加载探索页面数据',
        description: '加载探索卡片和相关数据',
        priority: LoadingPriority.high,
        executor: (context) => _loadExplorePageData(exploreRepository, context),
        timeout: const Duration(seconds: 8),
        tags: ['explore_page', 'page_data'],
      ),
    ];
  }

  // 私有方法：具体的任务执行器

  static Future<void> _initializeDatabase(DatabaseHelper databaseHelper) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始初始化数据库...');
    }

    try {
      await databaseHelper.database;
      if (kDebugMode) {
        print('【AppLoadingTasks】数据库初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】数据库初始化失败: $e');
      }
      rethrow;
    }
  }

  static Future<void> _initializeStorage(StorageService storageService) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始初始化存储服务...');
    }

    try {
      // 这里可以添加存储服务的初始化逻辑
      // 例如检查存储权限、创建必要的目录等
      await Future.delayed(const Duration(milliseconds: 100)); // 模拟初始化时间

      if (kDebugMode) {
        print('【AppLoadingTasks】存储服务初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】存储服务初始化失败: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _loadSettings(
      SettingsRepository settingsRepository) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始加载应用设置...');
    }

    try {
      final useBlocMode = await settingsRepository.getUseBlocMode();
      final themeMode = await settingsRepository.getThemeMode();
      final language = await settingsRepository.getLanguage();

      final settings = {
        'useBlocMode': useBlocMode,
        'themeMode': themeMode,
        'language': language,
      };

      if (kDebugMode) {
        print('【AppLoadingTasks】应用设置加载完成: $settings');
      }

      return settings;
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】应用设置加载失败: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _checkAuthStatus(
      AuthRepository authRepository) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始检查登录状态...');
    }

    try {
      final isLoggedIn = await authRepository.isLoggedIn();
      final currentUser =
          isLoggedIn ? await authRepository.getCurrentUser() : null;

      final authStatus = {
        'isLoggedIn': isLoggedIn,
        'currentUser': currentUser,
      };

      if (kDebugMode) {
        print('【AppLoadingTasks】登录状态检查完成: 已登录=$isLoggedIn');
      }

      return authStatus;
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】登录状态检查失败: $e');
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> _loadGoalsData(
      GoalRepository goalRepository) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始加载目标数据...');
    }

    try {
      final goals = await goalRepository.getGoals();
      final goalTree = await goalRepository.getGoalTree();

      if (kDebugMode) {
        print('【AppLoadingTasks】目标数据加载完成: ${goals.length}个目标');
      }

      return [goals, goalTree];
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】目标数据加载失败: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _loadUserProfile(
      ProfileRepository profileRepository) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始加载用户资料...');
    }

    try {
      final profile = await profileRepository.getUserProfile();

      final profileData = {
        'profile': profile,
      };

      if (kDebugMode) {
        print('【AppLoadingTasks】用户资料加载完成');
      }

      return profileData;
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】用户资料加载失败: $e');
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> _loadExploreCards(
      ExploreRepository exploreRepository) async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始加载探索卡片...');
    }

    try {
      final cards = await exploreRepository.getExploreCards();

      if (kDebugMode) {
        print('【AppLoadingTasks】探索卡片加载完成: ${cards.length}个卡片');
      }

      return [cards];
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】探索卡片加载失败: $e');
      }
      rethrow;
    }
  }

  static Future<void> _initializeSyncService() async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始初始化同步服务...');
    }

    try {
      // 这里可以添加同步服务的初始化逻辑
      await Future.delayed(const Duration(milliseconds: 200)); // 模拟初始化时间

      if (kDebugMode) {
        print('【AppLoadingTasks】同步服务初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】同步服务初始化失败: $e');
      }
      rethrow;
    }
  }

  static Future<void> _initializePerformanceMonitoring() async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始初始化性能监控...');
    }

    try {
      // 这里可以添加性能监控的初始化逻辑
      await Future.delayed(const Duration(milliseconds: 100)); // 模拟初始化时间

      if (kDebugMode) {
        print('【AppLoadingTasks】性能监控初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】性能监控初始化失败: $e');
      }
      rethrow;
    }
  }

  static Future<void> _warmupCache() async {
    if (kDebugMode) {
      print('【AppLoadingTasks】开始预热缓存...');
    }

    try {
      // 这里可以添加缓存预热的逻辑
      await Future.delayed(const Duration(milliseconds: 300)); // 模拟预热时间

      if (kDebugMode) {
        print('【AppLoadingTasks】缓存预热完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【AppLoadingTasks】缓存预热失败: $e');
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> _loadGoalPageData(
      GoalRepository goalRepository, Map<String, dynamic> context) async {
    final parentId = context['parentId'] as int?;
    final goals = await goalRepository.getGoals(parentId: parentId);
    return [goals];
  }

  static Future<void> _restoreGoalPageUIState(
      Map<String, dynamic> context) async {
    // 恢复UI状态的逻辑
    await Future.delayed(const Duration(milliseconds: 50));
  }

  static Future<List<dynamic>> _loadExplorePageData(
      ExploreRepository exploreRepository, Map<String, dynamic> context) async {
    final cards = await exploreRepository.getExploreCards();
    return [cards];
  }
}
