import 'package:flutter/foundation.dart';
import 'loading_task.dart';
import 'loading_state.dart';

/// 加载任务管理器
/// 管理任务的注册、状态跟踪和依赖关系
class LoadingTaskManager {
  final Map<String, LoadingTask> _tasks = {};
  final Map<String, LoadingState> _taskStates = {};
  final Map<String, List<String>> _dependencyGraph = {};
  final Map<String, List<String>> _reverseDependencyGraph = {};
  final Set<String> _pausedTasks = {};

  /// 注册单个任务
  void registerTask(LoadingTask task) {
    _tasks[task.id] = task;
    _taskStates[task.id] = LoadingIdle.now(taskId: task.id);
    _dependencyGraph[task.id] = List.from(task.dependencies);

    // 构建反向依赖图
    for (final depId in task.dependencies) {
      _reverseDependencyGraph.putIfAbsent(depId, () => []).add(task.id);
    }

    if (kDebugMode) {
      print('【LoadingTaskManager】注册任务: ${task.id}');
    }
  }

  /// 批量注册任务
  void registerTasks(List<LoadingTask> tasks) {
    for (final task in tasks) {
      registerTask(task);
    }
  }

  /// 获取任务
  LoadingTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// 获取任务状态
  LoadingState getTaskState(String taskId) {
    return _taskStates[taskId] ?? LoadingIdle.now(taskId: taskId);
  }

  /// 更新任务状态
  void updateTaskState(String taskId, LoadingState state) {
    _taskStates[taskId] = state;
  }

  /// 获取所有任务状态
  Map<String, LoadingState> getAllTaskStates() {
    return Map.from(_taskStates);
  }

  /// 获取所有任务
  Map<String, LoadingTask> getAllTasks() {
    return Map.from(_tasks);
  }

  /// 检查是否有循环依赖
  bool hasCyclicDependency() {
    final visited = <String>{};
    final recursionStack = <String>{};

    bool hasCycle(String taskId) {
      if (recursionStack.contains(taskId)) {
        return true;
      }

      if (visited.contains(taskId)) {
        return false;
      }

      visited.add(taskId);
      recursionStack.add(taskId);

      final dependencies = _dependencyGraph[taskId] ?? [];
      for (final depId in dependencies) {
        if (hasCycle(depId)) {
          return true;
        }
      }

      recursionStack.remove(taskId);
      return false;
    }

    for (final taskId in _tasks.keys) {
      if (hasCycle(taskId)) {
        return true;
      }
    }

    return false;
  }

  /// 获取依赖任务链
  List<String> getDependencyChain(String taskId) {
    final visited = <String>{};
    final chain = <String>[];

    void buildChain(String currentTaskId) {
      if (visited.contains(currentTaskId)) return;
      visited.add(currentTaskId);

      final dependencies = _dependencyGraph[currentTaskId] ?? [];
      for (final depId in dependencies) {
        buildChain(depId);
      }

      chain.add(currentTaskId);
    }

    buildChain(taskId);
    return chain;
  }

  /// 获取被依赖的任务（反向依赖）
  List<String> getDependentTasks(String taskId) {
    return _reverseDependencyGraph[taskId] ?? [];
  }

  /// 获取可执行的任务（依赖已满足）
  List<String> getExecutableTasks() {
    final executable = <String>[];

    for (final taskId in _tasks.keys) {
      final currentState = _taskStates[taskId];
      if (currentState is LoadingIdle && _canExecuteTask(taskId)) {
        executable.add(taskId);
      }
    }

    return executable;
  }

  /// 检查任务是否可以执行
  bool _canExecuteTask(String taskId) {
    final dependencies = _dependencyGraph[taskId] ?? [];

    for (final depId in dependencies) {
      final depState = _taskStates[depId];
      if (depState is! LoadingSuccess) {
        return false;
      }
    }

    return true;
  }

  /// 获取整体进度
  double getOverallProgress() {
    if (_tasks.isEmpty) return 0.0;

    var totalWeight = 0.0;
    var completedWeight = 0.0;

    for (final entry in _tasks.entries) {
      final task = entry.value;
      final state =
          _taskStates[entry.key] ?? LoadingIdle.now(taskId: entry.key);

      // 根据优先级分配权重
      var weight = 1.0;
      switch (task.priority) {
        case LoadingPriority.critical:
          weight = 3.0;
          break;
        case LoadingPriority.high:
          weight = 2.0;
          break;
        case LoadingPriority.normal:
          weight = 1.0;
          break;
        case LoadingPriority.low:
          weight = 0.5;
          break;
        case LoadingPriority.background:
          weight = 0.2;
          break;
      }

      totalWeight += weight;

      if (state is LoadingSuccess) {
        completedWeight += weight;
      } else if (state is LoadingInProgress) {
        completedWeight += weight * (state.progress ?? 0.0);
      }
    }

    return totalWeight > 0 ? completedWeight / totalWeight : 0.0;
  }

  /// 获取任务统计
  Map<String, dynamic> getTaskStatistics() {
    final total = _tasks.length;
    var idle = 0;
    var inProgress = 0;
    var completed = 0;
    var failed = 0;
    var cancelled = 0;

    for (final state in _taskStates.values) {
      if (state is LoadingIdle) {
        idle++;
      } else if (state is LoadingInProgress) {
        inProgress++;
      } else if (state is LoadingSuccess) {
        completed++;
      } else if (state is LoadingError) {
        failed++;
      } else if (state is LoadingCancelled) {
        cancelled++;
      }
    }

    return {
      'total': total,
      'idle': idle,
      'inProgress': inProgress,
      'completed': completed,
      'failed': failed,
      'cancelled': cancelled,
      'successRate': total > 0 ? completed / total : 0.0,
      'failureRate': total > 0 ? failed / total : 0.0,
    };
  }

  /// 按优先级排序任务
  List<String> sortTasksByPriority(List<String> taskIds) {
    final tasks = taskIds
        .map((id) => _tasks[id])
        .where((task) => task != null)
        .cast<LoadingTask>()
        .toList();

    tasks.sort((a, b) {
      // 首先按优先级排序
      final priorityComparison = _getPriorityValue(a.priority)
          .compareTo(_getPriorityValue(b.priority));
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      // 然后按依赖关系排序
      if (a.dependsOn(b.id)) {
        return 1; // a 依赖 b，b 应该先执行
      } else if (b.dependsOn(a.id)) {
        return -1; // b 依赖 a，a 应该先执行
      }

      // 最后按名称排序
      return a.name.compareTo(b.name);
    });

    return tasks.map((task) => task.id).toList();
  }

  /// 获取优先级数值
  int _getPriorityValue(LoadingPriority priority) {
    switch (priority) {
      case LoadingPriority.critical:
        return 0;
      case LoadingPriority.high:
        return 1;
      case LoadingPriority.normal:
        return 2;
      case LoadingPriority.low:
        return 3;
      case LoadingPriority.background:
        return 4;
    }
  }

  /// 清除所有任务
  void clearAllTasks() {
    _tasks.clear();
    _taskStates.clear();
    _dependencyGraph.clear();
    _reverseDependencyGraph.clear();

    if (kDebugMode) {
      print('【LoadingTaskManager】清除所有任务');
    }
  }

  /// 移除任务
  void removeTask(String taskId) {
    _tasks.remove(taskId);
    _taskStates.remove(taskId);
    _dependencyGraph.remove(taskId);

    // 从其他任务的依赖中移除
    for (final deps in _dependencyGraph.values) {
      deps.remove(taskId);
    }

    // 清理反向依赖
    _reverseDependencyGraph.remove(taskId);
    for (final deps in _reverseDependencyGraph.values) {
      deps.remove(taskId);
    }

    if (kDebugMode) {
      print('【LoadingTaskManager】移除任务: $taskId');
    }
  }

  /// 获取失败的任务
  List<String> getFailedTasks() {
    return _taskStates.entries
        .where((entry) => entry.value is LoadingError)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取已完成的任务
  List<String> getCompletedTasks() {
    return _taskStates.entries
        .where((entry) => entry.value is LoadingSuccess)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取正在进行的任务
  List<String> getActiveTasks() {
    return _taskStates.entries
        .where((entry) => entry.value is LoadingInProgress)
        .map((entry) => entry.key)
        .toList();
  }

  /// 重置任务状态
  void resetTaskState(String taskId) {
    if (_tasks.containsKey(taskId)) {
      _taskStates[taskId] = LoadingIdle.now(taskId: taskId);
    }
  }

  /// 重置所有任务状态
  void resetAllTaskStates() {
    for (final taskId in _tasks.keys) {
      _taskStates[taskId] = LoadingIdle.now(taskId: taskId);
    }

    if (kDebugMode) {
      print('【LoadingTaskManager】重置所有任务状态');
    }
  }

  /// 暂停任务
  void pauseTask(String taskId) {
    _pausedTasks.add(taskId);
    if (kDebugMode) {
      print('【LoadingTaskManager】暂停任务: $taskId');
    }
  }

  /// 恢复任务
  void resumeTask(String taskId) {
    _pausedTasks.remove(taskId);
    if (kDebugMode) {
      print('【LoadingTaskManager】恢复任务: $taskId');
    }
  }

  /// 检查任务是否被暂停
  bool isTaskPaused(String taskId) {
    return _pausedTasks.contains(taskId);
  }

  /// 获取所有暂停的任务
  List<String> getPausedTasks() {
    return List.from(_pausedTasks);
  }

  /// 获取可以并行执行的任务
  List<LoadingTask> getParallelExecutableTasks(int maxCount) {
    final executable = <LoadingTask>[];

    for (final entry in _tasks.entries) {
      final task = entry.value;
      final taskId = entry.key;
      final currentState = _taskStates[taskId];

      // 检查任务状态
      if (currentState is! LoadingIdle) continue;

      // 检查是否被暂停
      if (_pausedTasks.contains(taskId)) continue;

      // 检查依赖是否都已完成
      if (_canExecuteTask(taskId)) {
        executable.add(task);
      }
    }

    // 按优先级排序
    executable.sort((a, b) =>
        _getPriorityValue(a.priority).compareTo(_getPriorityValue(b.priority)));

    // 限制数量
    return executable.take(maxCount).toList();
  }
}
