import 'dart:async';
import 'package:flutter/foundation.dart';
import 'loading_task.dart';
import 'loading_state.dart';
import 'data_loading_chain.dart';

/// 加载策略类型
enum LoadingStrategy {
  sequential, // 顺序加载
  parallel, // 并行加载
  prioritized, // 优先级加载
  adaptive, // 自适应加载
  lazy, // 懒加载
  preload, // 预加载
}

/// 加载上下文信息
class LoadingContext {
  final String userId;
  final String deviceType;
  final String networkType;
  final bool isFirstLaunch;
  final Map<String, dynamic> userPreferences;
  final Map<String, dynamic> performanceMetrics;

  const LoadingContext({
    required this.userId,
    required this.deviceType,
    required this.networkType,
    required this.isFirstLaunch,
    this.userPreferences = const {},
    this.performanceMetrics = const {},
  });
}

/// 数据加载策略管理器
/// 根据不同场景选择最优的数据加载策略
class LoadingStrategyManager {
  final DataLoadingChain _loadingChain;
  final Map<String, LoadingStrategy> _taskStrategies = {};
  final Map<String, DateTime> _lastLoadTimes = {};
  final Map<String, dynamic> _cachedResults = {};
  final Map<String, Duration> _cacheTTL = {};

  // 性能阈值配置
  static const Duration _slowNetworkThreshold = Duration(seconds: 3);
  static const Duration _fastNetworkThreshold = Duration(milliseconds: 500);
  static const int _maxParallelTasks = 5;
  static const int _lowEndDeviceMaxTasks = 3;

  LoadingStrategyManager(this._loadingChain);

  /// 根据上下文选择加载策略
  LoadingStrategy selectStrategy(
    List<LoadingTask> tasks,
    LoadingContext context,
  ) {
    // 分析任务特征
    final taskAnalysis = _analyzeTasks(tasks);

    // 分析设备性能
    final devicePerformance = _analyzeDevicePerformance(context);

    // 分析网络状况
    final networkCondition = _analyzeNetworkCondition(context);

    // 选择最优策略
    return _selectOptimalStrategy(
      taskAnalysis,
      devicePerformance,
      networkCondition,
      context,
    );
  }

  /// 分析任务特征
  Map<String, dynamic> _analyzeTasks(List<LoadingTask> tasks) {
    final analysis = <String, dynamic>{};

    // 任务数量分析
    analysis['totalTasks'] = tasks.length;
    analysis['criticalTasks'] =
        tasks.where((t) => t.priority == LoadingPriority.critical).length;
    analysis['networkTasks'] = tasks.where((t) => t.requiresNetwork).length;

    // 依赖关系分析
    final hasDependencies = tasks.any((t) => t.dependencies.isNotEmpty);
    analysis['hasDependencies'] = hasDependencies;

    // 估计总执行时间
    final estimatedDuration = tasks.fold<Duration>(
      Duration.zero,
      (sum, task) => sum + task.estimatedDuration,
    );
    analysis['estimatedDuration'] = estimatedDuration;

    // 任务复杂度评分 (1-10)
    var complexityScore = 1;
    if (tasks.length > 10) complexityScore += 2;
    if (hasDependencies) complexityScore += 2;
    if (analysis['networkTasks'] > 5) complexityScore += 2;
    if (estimatedDuration > const Duration(seconds: 30)) complexityScore += 3;
    analysis['complexityScore'] = complexityScore.clamp(1, 10);

    return analysis;
  }

  /// 分析设备性能
  Map<String, dynamic> _analyzeDevicePerformance(LoadingContext context) {
    final analysis = <String, dynamic>{};

    // 设备类型评分
    var deviceScore = 5; // 默认中等性能
    switch (context.deviceType.toLowerCase()) {
      case 'high_end':
        deviceScore = 9;
        break;
      case 'mid_range':
        deviceScore = 6;
        break;
      case 'low_end':
        deviceScore = 3;
        break;
    }
    analysis['deviceScore'] = deviceScore;

    // 内存使用情况
    final memoryUsage =
        context.performanceMetrics['memoryUsage'] as double? ?? 0.5;
    analysis['memoryPressure'] = memoryUsage > 0.8
        ? 'high'
        : memoryUsage > 0.6
            ? 'medium'
            : 'low';

    // CPU使用情况
    final cpuUsage = context.performanceMetrics['cpuUsage'] as double? ?? 0.3;
    analysis['cpuLoad'] = cpuUsage > 0.7
        ? 'high'
        : cpuUsage > 0.4
            ? 'medium'
            : 'low';

    return analysis;
  }

  /// 分析网络状况
  Map<String, dynamic> _analyzeNetworkCondition(LoadingContext context) {
    final analysis = <String, dynamic>{};

    // 网络类型评分
    var networkScore = 5;
    switch (context.networkType.toLowerCase()) {
      case 'wifi':
        networkScore = 9;
        break;
      case '5g':
        networkScore = 8;
        break;
      case '4g':
        networkScore = 6;
        break;
      case '3g':
        networkScore = 3;
        break;
      case '2g':
        networkScore = 1;
        break;
    }
    analysis['networkScore'] = networkScore;

    // 网络延迟
    final latency = context.performanceMetrics['networkLatency'] as int? ?? 100;
    analysis['latency'] = latency;
    analysis['latencyLevel'] = latency > 500
        ? 'high'
        : latency > 200
            ? 'medium'
            : 'low';

    return analysis;
  }

  /// 选择最优策略
  LoadingStrategy _selectOptimalStrategy(
    Map<String, dynamic> taskAnalysis,
    Map<String, dynamic> devicePerformance,
    Map<String, dynamic> networkCondition,
    LoadingContext context,
  ) {
    final complexityScore = taskAnalysis['complexityScore'] as int;
    final deviceScore = devicePerformance['deviceScore'] as int;
    final networkScore = networkCondition['networkScore'] as int;
    final hasDependencies = taskAnalysis['hasDependencies'] as bool;

    if (kDebugMode) {
      print('【LoadingStrategyManager】策略选择分析:');
      print('  复杂度: $complexityScore, 设备: $deviceScore, 网络: $networkScore');
    }

    // 首次启动优化
    if (context.isFirstLaunch) {
      return LoadingStrategy.prioritized;
    }

    // 低端设备或网络条件差
    if (deviceScore <= 3 || networkScore <= 3) {
      return hasDependencies
          ? LoadingStrategy.sequential
          : LoadingStrategy.lazy;
    }

    // 高端设备且网络良好
    if (deviceScore >= 8 && networkScore >= 8) {
      return complexityScore > 7
          ? LoadingStrategy.adaptive
          : LoadingStrategy.parallel;
    }

    // 中等条件
    if (hasDependencies) {
      return LoadingStrategy.prioritized;
    } else {
      return complexityScore > 5
          ? LoadingStrategy.adaptive
          : LoadingStrategy.parallel;
    }
  }

  /// 执行加载策略
  Future<Map<String, dynamic>> executeStrategy(
    LoadingStrategy strategy,
    List<LoadingTask> tasks,
    LoadingContext context, {
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  }) async {
    if (kDebugMode) {
      print('【LoadingStrategyManager】执行策略: $strategy, 任务数: ${tasks.length}');
    }

    switch (strategy) {
      case LoadingStrategy.sequential:
        return _executeSequential(tasks, context, onProgress, onError);
      case LoadingStrategy.parallel:
        return _executeParallel(tasks, context, onProgress, onError);
      case LoadingStrategy.prioritized:
        return _executePrioritized(tasks, context, onProgress, onError);
      case LoadingStrategy.adaptive:
        return _executeAdaptive(tasks, context, onProgress, onError);
      case LoadingStrategy.lazy:
        return _executeLazy(tasks, context, onProgress, onError);
      case LoadingStrategy.preload:
        return _executePreload(tasks, context, onProgress, onError);
    }
  }

  /// 顺序执行策略
  Future<Map<String, dynamic>> _executeSequential(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    _loadingChain.setMaxConcurrentTasks(1);
    return _loadingChain.executeChain(
      taskIds: tasks.map((t) => t.id).toList(),
      context: _buildExecutionContext(context),
      onProgress: onProgress,
      onError: onError,
    );
  }

  /// 并行执行策略
  Future<Map<String, dynamic>> _executeParallel(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    final maxTasks = _getOptimalParallelTasks(context);
    _loadingChain.setMaxConcurrentTasks(maxTasks);

    return _loadingChain.executeChain(
      taskIds: tasks.map((t) => t.id).toList(),
      context: _buildExecutionContext(context),
      onProgress: onProgress,
      onError: onError,
    );
  }

  /// 优先级执行策略
  Future<Map<String, dynamic>> _executePrioritized(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    // 按优先级分组执行
    final tasksByPriority = <LoadingPriority, List<LoadingTask>>{};
    for (final task in tasks) {
      tasksByPriority.putIfAbsent(task.priority, () => []).add(task);
    }

    final results = <String, dynamic>{};
    final priorityOrder = [
      LoadingPriority.critical,
      LoadingPriority.high,
      LoadingPriority.normal,
      LoadingPriority.low,
      LoadingPriority.background,
    ];

    for (final priority in priorityOrder) {
      final priorityTasks = tasksByPriority[priority] ?? [];
      if (priorityTasks.isNotEmpty) {
        final maxTasks = priority == LoadingPriority.critical
            ? 1
            : priority == LoadingPriority.high
                ? 2
                : 3;
        _loadingChain.setMaxConcurrentTasks(maxTasks);

        final priorityResults = await _loadingChain.executeChain(
          taskIds: priorityTasks.map((t) => t.id).toList(),
          context: _buildExecutionContext(context),
          onProgress: onProgress,
          onError: onError,
        );

        results.addAll(priorityResults);
      }
    }

    return results;
  }

  /// 自适应执行策略
  Future<Map<String, dynamic>> _executeAdaptive(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    // 动态调整并发数
    var currentMaxTasks = _getOptimalParallelTasks(context);
    _loadingChain.setMaxConcurrentTasks(currentMaxTasks);

    // 监控执行性能，动态调整
    final startTime = DateTime.now();
    var completedTasks = 0;

    final adaptiveOnProgress = (String taskId, double progress) {
      completedTasks++;

      // 每完成5个任务评估一次性能
      if (completedTasks % 5 == 0) {
        final elapsed = DateTime.now().difference(startTime);
        final avgTimePerTask = elapsed.inMilliseconds / completedTasks;

        // 如果平均时间过长，减少并发数
        if (avgTimePerTask > 1000 && currentMaxTasks > 2) {
          currentMaxTasks--;
          _loadingChain.setMaxConcurrentTasks(currentMaxTasks);
          if (kDebugMode) {
            print('【LoadingStrategyManager】降低并发数至: $currentMaxTasks');
          }
        }
        // 如果执行很快，可以增加并发数
        else if (avgTimePerTask < 300 && currentMaxTasks < _maxParallelTasks) {
          currentMaxTasks++;
          _loadingChain.setMaxConcurrentTasks(currentMaxTasks);
          if (kDebugMode) {
            print('【LoadingStrategyManager】提高并发数至: $currentMaxTasks');
          }
        }
      }

      onProgress?.call(taskId, progress);
    };

    return _loadingChain.executeChain(
      taskIds: tasks.map((t) => t.id).toList(),
      context: _buildExecutionContext(context),
      onProgress: adaptiveOnProgress,
      onError: onError,
    );
  }

  /// 懒加载策略
  Future<Map<String, dynamic>> _executeLazy(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String, String error)? onError,
  ) async {
    // 只加载关键任务，其他任务延迟加载
    final criticalTasks = tasks
        .where((t) =>
            t.priority == LoadingPriority.critical ||
            t.priority == LoadingPriority.high)
        .toList();

    _loadingChain.setMaxConcurrentTasks(2);

    final results = await _loadingChain.executeChain(
      taskIds: criticalTasks.map((t) => t.id).toList(),
      context: _buildExecutionContext(context),
      onProgress: onProgress,
      onError: onError,
    );

    // 延迟加载其他任务
    final remainingTasks = tasks
        .where((t) =>
            t.priority != LoadingPriority.critical &&
            t.priority != LoadingPriority.high)
        .toList();

    if (remainingTasks.isNotEmpty) {
      Timer(const Duration(seconds: 2), () async {
        await _loadingChain.executeChain(
          taskIds: remainingTasks.map((t) => t.id).toList(),
          context: _buildExecutionContext(context),
          onProgress: onProgress,
          onError: onError,
        );
      });
    }

    return results;
  }

  /// 预加载策略
  Future<Map<String, dynamic>> _executePreload(
    List<LoadingTask> tasks,
    LoadingContext context,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    // 检查缓存
    final cachedResults = <String, dynamic>{};
    final tasksToExecute = <LoadingTask>[];

    for (final task in tasks) {
      if (_isCacheValid(task.id)) {
        cachedResults[task.id] = _cachedResults[task.id];
      } else {
        tasksToExecute.add(task);
      }
    }

    if (kDebugMode) {
      print(
          '【LoadingStrategyManager】使用缓存: ${cachedResults.length}个, 需要加载: ${tasksToExecute.length}个');
    }

    // 执行需要加载的任务
    final newResults = tasksToExecute.isNotEmpty
        ? await _executeParallel(tasksToExecute, context, onProgress, onError)
        : <String, dynamic>{};

    // 更新缓存
    for (final entry in newResults.entries) {
      _cachedResults[entry.key] = entry.value;
      _lastLoadTimes[entry.key] = DateTime.now();
    }

    // 合并结果
    return {...cachedResults, ...newResults};
  }

  /// 获取最优并行任务数
  int _getOptimalParallelTasks(LoadingContext context) {
    final deviceScore = context.performanceMetrics['deviceScore'] as int? ?? 5;

    if (deviceScore <= 3) {
      return _lowEndDeviceMaxTasks;
    } else if (deviceScore >= 8) {
      return _maxParallelTasks;
    } else {
      return (deviceScore * 0.6).round().clamp(2, _maxParallelTasks);
    }
  }

  /// 构建执行上下文
  Map<String, dynamic> _buildExecutionContext(LoadingContext context) {
    return {
      'userId': context.userId,
      'deviceType': context.deviceType,
      'networkType': context.networkType,
      'isFirstLaunch': context.isFirstLaunch,
      'userPreferences': context.userPreferences,
      'performanceMetrics': context.performanceMetrics,
    };
  }

  /// 检查缓存是否有效
  bool _isCacheValid(String taskId) {
    final lastLoadTime = _lastLoadTimes[taskId];
    final ttl = _cacheTTL[taskId] ?? const Duration(minutes: 5);

    if (lastLoadTime == null) return false;

    return DateTime.now().difference(lastLoadTime) < ttl;
  }

  /// 设置任务缓存TTL
  void setCacheTTL(String taskId, Duration ttl) {
    _cacheTTL[taskId] = ttl;
  }

  /// 清理过期缓存
  void cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _lastLoadTimes.entries) {
      final ttl = _cacheTTL[entry.key] ?? const Duration(minutes: 5);
      if (now.difference(entry.value) > ttl) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cachedResults.remove(key);
      _lastLoadTimes.remove(key);
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      print('【LoadingStrategyManager】清理过期缓存: ${expiredKeys.length}个');
    }
  }
}
