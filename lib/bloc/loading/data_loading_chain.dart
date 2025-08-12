import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'loading_task.dart';
import 'loading_state.dart';

/// 数据加载链管理器
/// 优化复杂的异步数据加载链，实现并行加载和错误处理
class DataLoadingChain {
  final Map<String, LoadingTask> _tasks = {};
  final Map<String, LoadingState> _taskStates = {};
  final Map<String, List<String>> _dependencyGraph = {};
  final Map<String, List<String>> _reverseDependencyGraph = {};
  final Map<String, Completer<dynamic>> _taskCompleters = {};
  final Map<String, Timer> _timeoutTimers = {};
  final Map<String, int> _retryCounters = {};

  // 并行执行控制
  int _maxConcurrentTasks = 5;
  final Set<String> _runningTasks = {};
  final Queue<String> _taskQueue = Queue<String>();

  // 性能监控
  final Map<String, DateTime> _taskStartTimes = {};
  final Map<String, Duration> _taskDurations = {};

  // 错误处理
  final Map<String, List<String>> _errorHistory = {};
  final Set<String> _criticalTasks = {};

  /// 设置最大并发任务数
  void setMaxConcurrentTasks(int maxTasks) {
    _maxConcurrentTasks = maxTasks;
  }

  /// 注册任务
  void registerTask(LoadingTask task) {
    _tasks[task.id] = task;
    _taskStates[task.id] = LoadingIdle.now(taskId: task.id);
    _dependencyGraph[task.id] = List.from(task.dependencies);
    _retryCounters[task.id] = 0;

    // 标记关键任务
    if (task.priority == LoadingPriority.critical) {
      _criticalTasks.add(task.id);
    }

    // 构建反向依赖图
    for (final depId in task.dependencies) {
      _reverseDependencyGraph.putIfAbsent(depId, () => []).add(task.id);
    }

    if (kDebugMode) {
      print('【DataLoadingChain】注册任务: ${task.id} (优先级: ${task.priority})');
    }
  }

  /// 批量注册任务
  void registerTasks(List<LoadingTask> tasks) {
    for (final task in tasks) {
      registerTask(task);
    }
  }

  /// 开始执行任务链
  Future<Map<String, dynamic>> executeChain({
    List<String>? taskIds,
    Map<String, dynamic> context = const {},
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  }) async {
    final targetTasks = taskIds ?? _tasks.keys.toList();
    final results = <String, dynamic>{};

    if (kDebugMode) {
      print('【DataLoadingChain】开始执行任务链: ${targetTasks.length}个任务');
    }

    // 按优先级和依赖关系排序任务
    final sortedTasks = _sortTasksByPriorityAndDependency(targetTasks);

    // 分批并行执行任务
    await _executeBatchedTasks(
      sortedTasks,
      context,
      results,
      onProgress,
      onError,
    );

    if (kDebugMode) {
      print('【DataLoadingChain】任务链执行完成，成功: ${results.length}个');
    }

    return results;
  }

  /// 按优先级和依赖关系排序任务
  List<String> _sortTasksByPriorityAndDependency(List<String> taskIds) {
    final sorted = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    // 拓扑排序，同时考虑优先级
    void visit(String taskId) {
      if (visiting.contains(taskId)) {
        if (kDebugMode) {
          print('【DataLoadingChain】检测到循环依赖: $taskId');
        }
        return;
      }

      if (visited.contains(taskId)) return;

      visiting.add(taskId);

      // 先访问依赖任务
      final dependencies = _dependencyGraph[taskId] ?? [];
      for (final depId in dependencies) {
        if (taskIds.contains(depId)) {
          visit(depId);
        }
      }

      visiting.remove(taskId);
      visited.add(taskId);
      sorted.add(taskId);
    }

    // 按优先级分组
    final tasksByPriority = <LoadingPriority, List<String>>{};
    for (final taskId in taskIds) {
      final task = _tasks[taskId];
      if (task != null) {
        tasksByPriority.putIfAbsent(task.priority, () => []).add(taskId);
      }
    }

    // 按优先级顺序处理
    final priorityOrder = [
      LoadingPriority.critical,
      LoadingPriority.high,
      LoadingPriority.normal,
      LoadingPriority.low,
      LoadingPriority.background,
    ];

    for (final priority in priorityOrder) {
      final tasksInPriority = tasksByPriority[priority] ?? [];
      for (final taskId in tasksInPriority) {
        visit(taskId);
      }
    }

    return sorted;
  }

  /// 分批并行执行任务
  Future<void> _executeBatchedTasks(
    List<String> sortedTasks,
    Map<String, dynamic> context,
    Map<String, dynamic> results,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) async {
    final remainingTasks = Queue<String>.from(sortedTasks);

    while (remainingTasks.isNotEmpty || _runningTasks.isNotEmpty) {
      // 启动可以并行执行的任务
      while (_runningTasks.length < _maxConcurrentTasks &&
          remainingTasks.isNotEmpty) {
        final taskId = _findNextExecutableTask(remainingTasks);
        if (taskId != null) {
          remainingTasks.remove(taskId);
          _startTask(taskId, context, results, onProgress, onError);
        } else {
          break; // 没有可执行的任务，等待当前任务完成
        }
      }

      // 等待至少一个任务完成
      if (_runningTasks.isNotEmpty) {
        await _waitForAnyTaskCompletion();
      }
    }
  }

  /// 查找下一个可执行的任务
  String? _findNextExecutableTask(Queue<String> remainingTasks) {
    for (final taskId in remainingTasks) {
      if (_canExecuteTask(taskId)) {
        return taskId;
      }
    }
    return null;
  }

  /// 检查任务是否可以执行
  bool _canExecuteTask(String taskId) {
    final dependencies = _dependencyGraph[taskId] ?? [];

    // 检查所有依赖是否已完成
    for (final depId in dependencies) {
      final depState = _taskStates[depId];
      if (depState is! LoadingSuccess) {
        return false;
      }
    }

    return true;
  }

  /// 启动任务执行
  void _startTask(
    String taskId,
    Map<String, dynamic> context,
    Map<String, dynamic> results,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
  ) {
    final task = _tasks[taskId];
    if (task == null) return;

    _runningTasks.add(taskId);
    _taskStates[taskId] =
        LoadingInProgress.now(taskId: taskId, message: '正在执行任务');
    _taskStartTimes[taskId] = DateTime.now();

    final completer = Completer<dynamic>();
    _taskCompleters[taskId] = completer;

    if (kDebugMode) {
      print('【DataLoadingChain】开始执行任务: $taskId');
    }

    // 设置超时
    if (task.timeout != null) {
      _timeoutTimers[taskId] = Timer(task.timeout!, () {
        _handleTaskTimeout(taskId, onError);
      });
    }

    // 执行任务
    _executeTask(task, context, results, onProgress, onError, completer);
  }

  /// 执行单个任务
  void _executeTask(
    LoadingTask task,
    Map<String, dynamic> context,
    Map<String, dynamic> results,
    Function(String taskId, double progress)? onProgress,
    Function(String taskId, String error)? onError,
    Completer<dynamic> completer,
  ) async {
    try {
      // 构建任务上下文
      final taskContext = Map<String, dynamic>.from(context);

      // 添加依赖任务的结果
      for (final depId in task.dependencies) {
        if (results.containsKey(depId)) {
          taskContext['dependency_$depId'] = results[depId];
        }
      }

      // 执行任务
      final result = await task.executor(taskContext);

      // 任务成功完成
      _handleTaskSuccess(task.id, result, results, completer);
    } catch (error, stackTrace) {
      // 任务执行失败
      _handleTaskError(
          task.id, error, stackTrace, context, results, onError, completer);
    }
  }

  /// 处理任务成功
  void _handleTaskSuccess(
    String taskId,
    dynamic result,
    Map<String, dynamic> results,
    Completer<dynamic> completer,
  ) {
    _timeoutTimers[taskId]?.cancel();
    _timeoutTimers.remove(taskId);

    final startTime = _taskStartTimes[taskId];
    if (startTime != null) {
      _taskDurations[taskId] = DateTime.now().difference(startTime);
    }

    _taskStates[taskId] = LoadingSuccess.now(
        taskId: taskId,
        data: result,
        duration: _taskDurations[taskId] ?? Duration.zero);
    results[taskId] = result;
    _runningTasks.remove(taskId);
    _taskCompleters.remove(taskId); // 清理completer

    if (!completer.isCompleted) {
      completer.complete(result);
    }

    if (kDebugMode) {
      final duration = _taskDurations[taskId]?.inMilliseconds ?? 0;
      print('【DataLoadingChain】任务完成: $taskId (耗时: ${duration}ms)');
    }
  }

  /// 处理任务错误
  void _handleTaskError(
    String taskId,
    dynamic error,
    StackTrace stackTrace,
    Map<String, dynamic> context,
    Map<String, dynamic> results,
    Function(String taskId, String error)? onError,
    Completer<dynamic> completer,
  ) async {
    _timeoutTimers[taskId]?.cancel();
    _timeoutTimers.remove(taskId);

    final task = _tasks[taskId];
    if (task == null) return;

    _retryCounters[taskId] = (_retryCounters[taskId] ?? 0) + 1;
    final errorMessage = error.toString();

    // 记录错误历史
    _errorHistory.putIfAbsent(taskId, () => []).add(errorMessage);

    if (kDebugMode) {
      print('【DataLoadingChain】任务失败: $taskId, 错误: $errorMessage');
    }

    // 检查是否可以重试
    if (_retryCounters[taskId]! <= task.maxRetries) {
      if (kDebugMode) {
        print('【DataLoadingChain】重试任务: $taskId (第${_retryCounters[taskId]}次)');
      }

      // 延迟后重试
      await Future.delayed(task.retryDelay);
      _executeTask(task, context, results, null, onError, completer);
      return;
    }

    // 重试次数用尽，任务失败
    _taskStates[taskId] = LoadingError.now(
      taskId: taskId,
      error: errorMessage,
      stackTrace: stackTrace,
    );
    _runningTasks.remove(taskId);
    _taskCompleters.remove(taskId); // 清理completer

    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }

    onError?.call(taskId, errorMessage);

    // 如果是关键任务失败，考虑终止整个链
    if (_criticalTasks.contains(taskId)) {
      if (kDebugMode) {
        print('【DataLoadingChain】关键任务失败，考虑终止执行链: $taskId');
      }
    }
  }

  /// 处理任务超时
  void _handleTaskTimeout(
    String taskId,
    Function(String taskId, String error)? onError,
  ) {
    if (_runningTasks.contains(taskId)) {
      final errorMessage = '任务执行超时';
      _taskStates[taskId] = LoadingError.now(
        taskId: taskId,
        error: errorMessage,
      );
      _runningTasks.remove(taskId);

      final completer = _taskCompleters.remove(taskId); // 清理completer
      if (completer != null && !completer.isCompleted) {
        completer.completeError(TimeoutException('Task timeout'));
      }

      onError?.call(taskId, errorMessage);

      if (kDebugMode) {
        print('【DataLoadingChain】任务超时: $taskId');
      }
    }
  }

  /// 等待任何一个任务完成
  Future<void> _waitForAnyTaskCompletion() async {
    if (_taskCompleters.isEmpty) return;

    final futures = _taskCompleters.values.map((c) => c.future).toList();
    await Future.any(futures.map((f) => f.catchError((_) => null)));
  }

  /// 获取执行统计信息
  Map<String, dynamic> getExecutionStats() {
    final totalTasks = _tasks.length;
    final completedTasks =
        _taskStates.values.where((s) => s is LoadingSuccess).length;
    final failedTasks =
        _taskStates.values.where((s) => s is LoadingError).length;
    final totalDuration = _taskDurations.values.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'failedTasks': failedTasks,
      'successRate': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
      'totalDuration': totalDuration.inMilliseconds,
      'averageDuration': _taskDurations.isNotEmpty
          ? totalDuration.inMilliseconds / _taskDurations.length
          : 0,
      'taskDurations':
          _taskDurations.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'errorHistory': _errorHistory,
    };
  }

  /// 清理资源
  void dispose() {
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
    _taskCompleters.clear();
    _runningTasks.clear();
    _taskQueue.clear();
  }
}
