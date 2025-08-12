import 'package:flutter/foundation.dart';
import 'loading_task.dart';
import 'loading_state.dart';
import 'data_loading_chain.dart';
import 'loading_strategy_manager.dart';
import 'loading_performance_monitor.dart';

/// 优化的数据加载链使用示例
/// 展示如何使用新的加载优化功能
class OptimizedLoadingExample {
  late final DataLoadingChain _loadingChain;
  late final LoadingStrategyManager _strategyManager;
  late final LoadingPerformanceMonitor _performanceMonitor;

  OptimizedLoadingExample() {
    _loadingChain = DataLoadingChain();
    _strategyManager = LoadingStrategyManager(_loadingChain);
    _performanceMonitor = LoadingPerformanceMonitor();
  }

  /// 示例1: 应用启动时的优化加载
  Future<Map<String, dynamic>> optimizedAppStartup() async {
    if (kDebugMode) {
      print('【OptimizedLoadingExample】开始优化的应用启动加载');
    }

    // 1. 创建示例任务（实际使用时应该使用AppLoadingTasks.getStartupTasks）
    final tasks = _createSampleTasks();

    // 2. 注册任务到加载链
    _loadingChain.registerTasks(tasks);

    // 3. 构建加载上下文
    final context = LoadingContext(
      userId: 'user_123',
      deviceType: 'high_end', // 可以是 high_end, mid_range, low_end
      networkType: 'wifi', // 可以是 wifi, 5g, 4g, 3g, 2g
      isFirstLaunch: true,
      userPreferences: {
        'enableParallelLoading': true,
        'maxConcurrentTasks': 5,
      },
      performanceMetrics: {
        'memoryUsage': 0.4, // 40% 内存使用
        'cpuUsage': 0.3, // 30% CPU使用
        'networkLatency': 50, // 50ms 网络延迟
      },
    );

    // 4. 选择最优加载策略
    final strategy = _strategyManager.selectStrategy(tasks, context);

    if (kDebugMode) {
      print('【OptimizedLoadingExample】选择的加载策略: $strategy');
    }

    // 5. 执行优化加载
    final results = await _strategyManager.executeStrategy(
      strategy,
      tasks,
      context,
      onProgress: (taskId, progress) {
        if (kDebugMode) {
          print(
              '【OptimizedLoadingExample】任务进度: $taskId -> ${(progress * 100).toStringAsFixed(1)}%');
        }
      },
      onError: (taskId, error) {
        if (kDebugMode) {
          print('【OptimizedLoadingExample】任务错误: $taskId -> $error');
        }
      },
    );

    // 6. 获取性能统计
    final stats = _loadingChain.getExecutionStats();
    if (kDebugMode) {
      print('【OptimizedLoadingExample】执行统计: $stats');
    }

    return results;
  }

  /// 示例2: 页面级数据加载优化
  Future<Map<String, dynamic>> optimizedPageLoading(String pageName) async {
    if (kDebugMode) {
      print('【OptimizedLoadingExample】开始优化的页面加载: $pageName');
    }

    // 1. 创建页面特定任务（实际使用时应该使用AppLoadingTasks.getPageLoadingTasks）
    final tasks = _createPageTasks(pageName);

    if (tasks.isEmpty) {
      if (kDebugMode) {
        print('【OptimizedLoadingExample】页面 $pageName 没有特定的加载任务');
      }
      return {};
    }

    // 2. 注册任务
    _loadingChain.registerTasks(tasks);

    // 3. 构建页面加载上下文
    final context = LoadingContext(
      userId: 'user_123',
      deviceType: 'mid_range',
      networkType: '4g',
      isFirstLaunch: false,
      userPreferences: {
        'enableCaching': true,
        'preloadNextPage': true,
      },
      performanceMetrics: {
        'memoryUsage': 0.6,
        'cpuUsage': 0.4,
        'networkLatency': 150,
      },
    );

    // 4. 使用自适应策略
    final results = await _strategyManager.executeStrategy(
      LoadingStrategy.adaptive,
      tasks,
      context,
      onProgress: (taskId, progress) {
        // 页面加载进度更新
        if (kDebugMode) {
          print('【页面加载】$taskId: ${(progress * 100).toStringAsFixed(1)}%');
        }
      },
      onError: (taskId, error) {
        // 页面加载错误处理
        if (kDebugMode) {
          print('【页面加载错误】$taskId: $error');
        }
      },
    );

    return results;
  }

  /// 示例3: 性能监控和优化建议
  void demonstratePerformanceMonitoring() {
    if (kDebugMode) {
      print('【OptimizedLoadingExample】性能监控演示');
    }

    // 模拟一些性能数据
    _performanceMonitor.recordMetric(
      taskId: 'database_init',
      metric: PerformanceMetric.executionTime,
      value: 1500.0, // 1.5秒
    );

    _performanceMonitor.recordMetric(
      taskId: 'database_init',
      metric: PerformanceMetric.memoryUsage,
      value: 25.0, // 25MB
    );

    _performanceMonitor.recordCacheHit('goals_load', true);
    _performanceMonitor.recordCacheHit('goals_load', false);
    _performanceMonitor.recordCacheHit('goals_load', true);

    // 获取整体统计
    final overallStats = _performanceMonitor.getOverallStats();
    if (kDebugMode) {
      print('【性能统计】整体: $overallStats');
    }

    // 获取任务特定统计
    final taskStats = _performanceMonitor.getTaskStats('database_init');
    if (kDebugMode) {
      print('【性能统计】database_init: $taskStats');
    }

    // 获取性能建议
    final recommendations = _performanceMonitor.getPerformanceRecommendations();
    if (kDebugMode) {
      print('【性能建议】: $recommendations');
    }

    // 获取最近警告
    final warnings = _performanceMonitor.getRecentWarnings();
    if (kDebugMode) {
      print('【性能警告】: ${warnings.length}个警告');
      for (final warning in warnings) {
        print('  - [${warning.severity}] ${warning.message}');
      }
    }
  }

  /// 示例4: 不同网络条件下的策略选择
  Future<void> demonstrateNetworkAdaptiveLoading() async {
    final tasks = _createSampleTasks();

    // 测试不同网络条件
    final networkConditions = [
      ('wifi', 'WiFi环境'),
      ('5g', '5G网络'),
      ('4g', '4G网络'),
      ('3g', '3G网络'),
      ('2g', '2G网络'),
    ];

    for (final condition in networkConditions) {
      final context = LoadingContext(
        userId: 'user_123',
        deviceType: 'mid_range',
        networkType: condition.$1,
        isFirstLaunch: false,
        performanceMetrics: {
          'networkLatency': condition.$1 == 'wifi'
              ? 20
              : condition.$1 == '5g'
                  ? 30
                  : condition.$1 == '4g'
                      ? 100
                      : condition.$1 == '3g'
                          ? 300
                          : 800,
        },
      );

      final strategy = _strategyManager.selectStrategy(tasks, context);

      if (kDebugMode) {
        print('【网络自适应】${condition.$2}: 选择策略 $strategy');
      }
    }
  }

  /// 创建示例任务
  List<LoadingTask> _createSampleTasks() {
    return [
      LoadingTask<String>(
        id: 'task_1',
        name: '基础数据加载',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return 'basic_data';
        },
        priority: LoadingPriority.high,
        requiresNetwork: false,
      ),
      LoadingTask<String>(
        id: 'task_2',
        name: '网络数据同步',
        executor: (context) async {
          await Future.delayed(const Duration(seconds: 2));
          return 'network_data';
        },
        priority: LoadingPriority.normal,
        requiresNetwork: true,
        dependencies: ['task_1'],
      ),
      LoadingTask<String>(
        id: 'task_3',
        name: '缓存预热',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 800));
          return 'cache_warmed';
        },
        priority: LoadingPriority.low,
        requiresNetwork: false,
        dependencies: ['task_1'],
      ),
    ];
  }

  /// 创建页面特定任务
  List<LoadingTask> _createPageTasks(String pageName) {
    switch (pageName) {
      case 'goal_page':
        return [
          LoadingTask<String>(
            id: 'goal_data',
            name: '加载目标数据',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 300));
              return 'goal_data_loaded';
            },
            priority: LoadingPriority.high,
          ),
        ];
      case 'explore_page':
        return [
          LoadingTask<String>(
            id: 'explore_data',
            name: '加载探索数据',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 400));
              return 'explore_data_loaded';
            },
            priority: LoadingPriority.normal,
          ),
        ];
      default:
        return [];
    }
  }

  /// 清理资源
  void dispose() {
    _loadingChain.dispose();
    _performanceMonitor.dispose();
  }
}

/// 使用示例的主函数
Future<void> runOptimizedLoadingExample() async {
  final example = OptimizedLoadingExample();

  try {
    // 1. 演示应用启动优化
    await example.optimizedAppStartup();

    // 2. 演示页面加载优化
    await example.optimizedPageLoading('goal_page');

    // 3. 演示性能监控
    example.demonstratePerformanceMonitoring();

    // 4. 演示网络自适应加载
    await example.demonstrateNetworkAdaptiveLoading();
  } finally {
    example.dispose();
  }
}
