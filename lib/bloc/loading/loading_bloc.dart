import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'loading_event.dart';
import 'loading_state.dart';
import 'loading_task.dart';
import 'loading_task_manager.dart';
import 'data_loading_chain.dart';
import 'loading_strategy_manager.dart';
import 'loading_performance_monitor.dart';

/// 取消令牌
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// 统一加载状态管理BLoC
class LoadingBloc extends Bloc<LoadingEvent, LoadingBlocState> {
  final LoadingTaskManager _taskManager = LoadingTaskManager();
  final DataLoadingChain _loadingChain = DataLoadingChain();
  late final LoadingStrategyManager _strategyManager;
  late final LoadingPerformanceMonitor _performanceMonitor;

  final Map<String, Timer> _timeoutTimers = {};
  final Map<String, Completer> _taskCompleters = {};
  final Map<String, CancelToken> _cancelTokens = {};

  // 配置参数
  int _maxConcurrentTasks = 5;
  Duration _defaultTimeout = const Duration(seconds: 30);
  int _defaultMaxRetries = 3;
  Duration _defaultRetryDelay = const Duration(seconds: 1);
  bool _enablePerformanceMonitoring = true;

  // 性能监控
  final Map<String, DateTime> _taskStartTimes = {};
  final Map<String, Duration> _taskDurations = {};

  LoadingBloc() : super(LoadingBlocState.initial()) {
    // 初始化优化组件
    _strategyManager = LoadingStrategyManager(_loadingChain);
    _performanceMonitor = LoadingPerformanceMonitor();

    on<RegisterLoadingTasks>(_onRegisterLoadingTasks);
    on<StartLoadingTask>(_onStartLoadingTask);
    on<StartLoadingTasks>(_onStartLoadingTasks);
    on<UpdateTaskProgress>(_onUpdateTaskProgress);
    on<CompleteTask>(_onCompleteTask);
    on<FailTask>(_onFailTask);
    on<RetryFailedTask>(_onRetryFailedTask);
    on<RetryAllFailedTasks>(_onRetryAllFailedTasks);
    on<CancelLoadingTask>(_onCancelLoadingTask);
    on<CancelAllTasks>(_onCancelAllTasks);
    on<ClearCompletedTasks>(_onClearCompletedTasks);
    on<ClearFailedTasks>(_onClearFailedTasks);
    on<ResetLoadingState>(_onResetLoadingState);
    on<PauseTaskExecution>(_onPauseTaskExecution);
    on<ResumeTaskExecution>(_onResumeTaskExecution);
    on<SetTaskPriority>(_onSetTaskPriority);
    on<BatchExecuteTasks>(_onBatchExecuteTasks);
    on<ExecuteDependencyChain>(_onExecuteDependencyChain);
    on<SetLoadingConfig>(_onSetLoadingConfig);
    on<TaskTimeout>(_onTaskTimeout);
    on<CheckDependencies>(_onCheckDependencies);
    on<ExecuteNextBatch>(_onExecuteNextBatch);
  }

  @override
  Future<void> close() {
    // 清理所有定时器
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();

    // 取消所有正在执行的任务
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();

    return super.close();
  }

  /// 注册加载任务
  Future<void> _onRegisterLoadingTasks(
    RegisterLoadingTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    if (event.clearExisting) {
      _taskManager.clearAllTasks();
      _clearAllTimers();
    }

    // 注册所有任务
    _taskManager.registerTasks(event.tasks);

    // 检查循环依赖
    if (_taskManager.hasCyclicDependency()) {
      if (kDebugMode) {
        print('【LoadingBloc】警告: 检测到循环依赖');
      }
    }

    // 更新状态
    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      isLoading: false,
      overallProgress: _taskManager.getOverallProgress(),
    ));

    if (kDebugMode) {
      print('【LoadingBloc】已注册 ${event.tasks.length} 个任务');
    }
  }

  /// 开始执行单个任务
  Future<void> _onStartLoadingTask(
    StartLoadingTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final task = _taskManager.getTask(event.taskId);
    if (task == null) {
      if (kDebugMode) {
        print('【LoadingBloc】任务不存在: ${event.taskId}');
      }
      return;
    }

    final currentState = _taskManager.getTaskState(event.taskId);
    if (currentState is! LoadingIdle) {
      if (kDebugMode) {
        print(
            '【LoadingBloc】任务 ${event.taskId} 不在空闲状态，当前状态: ${currentState.runtimeType}');
      }
      return;
    }

    // 检查依赖是否满足
    final unmetDependencies = task.dependencies.where((depId) {
      final depState = _taskManager.getTaskState(depId);
      return depState is! LoadingSuccess;
    }).toList();

    if (unmetDependencies.isNotEmpty) {
      if (kDebugMode) {
        print('【LoadingBloc】任务 ${event.taskId} 的依赖未满足: $unmetDependencies');
      }
      return;
    }

    await _executeTask(task, event.context ?? {}, emit);
  }

  /// 开始执行多个任务
  Future<void> _onStartLoadingTasks(
    StartLoadingTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final executableTasks = event.taskIds
        .map((id) => _taskManager.getTask(id))
        .where((task) => task != null)
        .cast<LoadingTask>()
        .where((task) {
      final currentState = _taskManager.getTaskState(task.id);
      return currentState is LoadingIdle;
    }).toList();

    // 按优先级排序
    executableTasks
        .sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // 限制并发数量
    final tasksToExecute = executableTasks.take(_maxConcurrentTasks).toList();

    for (final task in tasksToExecute) {
      await _executeTask(task, event.context ?? {}, emit);
    }
  }

  /// 执行任务的核心逻辑
  Future<void> _executeTask(
    LoadingTask task,
    Map<String, dynamic> context,
    Emitter<LoadingBlocState> emit,
  ) async {
    final taskId = task.id;

    // 创建取消令牌
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    // 记录开始时间
    final startTime = DateTime.now();
    _taskStartTimes[taskId] = startTime;

    // 更新为加载中状态
    final loadingState = LoadingInProgress.now(
      taskId: taskId,
      message: '正在${task.name}...',
      priority: task.priority,
      dependencies: task.dependencies,
    );

    _taskManager.updateTaskState(taskId, loadingState);

    final activeTasks = [...state.activeTasks, taskId];
    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      isLoading: true,
      activeTasks: activeTasks,
      currentMessage: loadingState.message,
      currentPriority: _getHighestActivePriority(activeTasks),
      overallProgress: _taskManager.getOverallProgress(),
    ));

    // 设置超时定时器
    final timeout = task.timeout ?? _defaultTimeout;
    _timeoutTimers[taskId] = Timer(timeout, () {
      if (!cancelToken.isCancelled) {
        add(TaskTimeout(taskId));
      }
    });

    try {
      // 执行任务
      final result = await task.executor(context);

      if (cancelToken.isCancelled) {
        return; // 任务已被取消
      }

      // 计算执行时间
      final duration = DateTime.now().difference(startTime);
      _taskDurations[taskId] = duration;

      // 任务成功完成
      add(CompleteTask(
        taskId: taskId,
        data: result,
        duration: duration,
      ));
    } catch (e, stackTrace) {
      if (cancelToken.isCancelled) {
        return; // 任务已被取消
      }

      // 任务执行失败
      add(FailTask(
        taskId: taskId,
        error: e.toString(),
        stackTrace: stackTrace,
        isRetryable: true,
        retryDelay: task.retryDelay,
      ));
    } finally {
      // 清理资源
      _timeoutTimers[taskId]?.cancel();
      _timeoutTimers.remove(taskId);
      _cancelTokens.remove(taskId);
      _taskStartTimes.remove(taskId);
    }
  }

  /// 更新任务进度
  Future<void> _onUpdateTaskProgress(
    UpdateTaskProgress event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final currentState = _taskManager.getTaskState(event.taskId);
    if (currentState is LoadingInProgress) {
      final updatedState = currentState.updateProgress(
        event.progress,
        newMessage: event.message,
      );

      _taskManager.updateTaskState(event.taskId, updatedState);

      emit(state.copyWith(
        taskStates: _taskManager.getAllTaskStates(),
        overallProgress: _taskManager.getOverallProgress(),
        currentMessage: event.message ?? state.currentMessage,
      ));
    }
  }

  /// 完成任务
  Future<void> _onCompleteTask(
    CompleteTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final successState = LoadingSuccess.now(
      taskId: event.taskId,
      data: event.data,
      duration: event.duration,
      metadata: event.metadata ?? {},
    );

    _taskManager.updateTaskState(event.taskId, successState);

    final activeTasks =
        state.activeTasks.where((id) => id != event.taskId).toList();
    final completedTasks = [...state.completedTasks, event.taskId];

    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      activeTasks: activeTasks,
      completedTasks: completedTasks,
      overallProgress: _taskManager.getOverallProgress(),
      isLoading: activeTasks.isNotEmpty,
      currentPriority: _getHighestActivePriority(activeTasks),
    ));

    if (kDebugMode) {
      print(
          '【LoadingBloc】任务完成: ${event.taskId}, 耗时: ${event.duration.inMilliseconds}ms');
    }

    // 检查是否有新的可执行任务
    add(const CheckDependencies());
  }

  /// 任务失败处理
  Future<void> _onFailTask(
    FailTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final task = _taskManager.getTask(event.taskId);
    final currentState = _taskManager.getTaskState(event.taskId);

    int retryCount = 0;
    if (currentState is LoadingError) {
      retryCount = currentState.retryCount;
    }

    final errorState = LoadingError.now(
      taskId: event.taskId,
      error: event.error,
      errorCode: event.errorCode,
      stackTrace: event.stackTrace,
      isRetryable: event.isRetryable &&
          (task?.maxRetries ?? _defaultMaxRetries) > retryCount,
      retryCount: retryCount,
      retryDelay: event.retryDelay ?? task?.retryDelay ?? _defaultRetryDelay,
      metadata: event.metadata ?? {},
    );

    _taskManager.updateTaskState(event.taskId, errorState);

    final activeTasks =
        state.activeTasks.where((id) => id != event.taskId).toList();
    final failedTasks = [...state.failedTasks];
    if (!failedTasks.contains(event.taskId)) {
      failedTasks.add(event.taskId);
    }

    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      activeTasks: activeTasks,
      failedTasks: failedTasks,
      overallProgress: _taskManager.getOverallProgress(),
      isLoading: activeTasks.isNotEmpty,
      currentPriority: _getHighestActivePriority(activeTasks),
    ));

    if (kDebugMode) {
      print('【LoadingBloc】任务失败: ${event.taskId}, 错误: ${event.error}');
    }
  }

  /// 重试失败任务
  Future<void> _onRetryFailedTask(
    RetryFailedTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final currentState = _taskManager.getTaskState(event.taskId);
    if (currentState is LoadingError && currentState.isRetryable) {
      // 重置任务状态为空闲
      _taskManager.updateTaskState(
          event.taskId, LoadingIdle.now(taskId: event.taskId));

      // 从失败列表中移除
      final failedTasks =
          state.failedTasks.where((id) => id != event.taskId).toList();

      emit(state.copyWith(
        taskStates: _taskManager.getAllTaskStates(),
        failedTasks: failedTasks,
      ));

      // 重新执行任务
      add(StartLoadingTask(event.taskId, context: event.context));
    }
  }

  /// 重试所有失败任务
  Future<void> _onRetryAllFailedTasks(
    RetryAllFailedTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final retryableTasks = state.failedTasks.where((taskId) {
      final taskState = _taskManager.getTaskState(taskId);
      return taskState is LoadingError && taskState.isRetryable;
    }).toList();

    for (final taskId in retryableTasks) {
      add(RetryFailedTask(taskId, context: event.context));
    }
  }

  /// 取消任务
  Future<void> _onCancelLoadingTask(
    CancelLoadingTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final cancelToken = _cancelTokens[event.taskId];
    cancelToken?.cancel();

    final cancelledState = LoadingCancelled.now(
      taskId: event.taskId,
      reason: event.reason,
    );

    _taskManager.updateTaskState(event.taskId, cancelledState);

    final activeTasks =
        state.activeTasks.where((id) => id != event.taskId).toList();

    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      activeTasks: activeTasks,
      isLoading: activeTasks.isNotEmpty,
      currentPriority: _getHighestActivePriority(activeTasks),
    ));

    if (kDebugMode) {
      print('【LoadingBloc】任务已取消: ${event.taskId}, 原因: ${event.reason}');
    }
  }

  /// 设置加载配置
  Future<void> _onSetLoadingConfig(
    SetLoadingConfig event,
    Emitter<LoadingBlocState> emit,
  ) async {
    _maxConcurrentTasks = event.maxConcurrentTasks;
    _defaultTimeout = event.defaultTimeout;
    _defaultMaxRetries = event.defaultMaxRetries;
    _defaultRetryDelay = event.defaultRetryDelay;
    _enablePerformanceMonitoring = event.enablePerformanceMonitoring;

    if (kDebugMode) {
      print(
          '【LoadingBloc】配置已更新: 最大并发=${_maxConcurrentTasks}, 默认超时=${_defaultTimeout}');
    }
  }

  /// 获取当前最高优先级
  LoadingPriority? _getHighestActivePriority(List<String> activeTasks) {
    LoadingPriority? highest;

    for (final taskId in activeTasks) {
      final state = _taskManager.getTaskState(taskId);
      if (state is LoadingInProgress) {
        if (highest == null || state.priority.index < highest.index) {
          highest = state.priority;
        }
      }
    }

    return highest;
  }

  /// 清理所有定时器
  void _clearAllTimers() {
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
  }

  /// 取消所有任务
  Future<void> _onCancelAllTasks(
    CancelAllTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    // 取消所有正在执行的任务
    for (final taskId in state.activeTasks) {
      add(CancelLoadingTask(taskId, reason: event.reason));
    }
  }

  /// 清除已完成任务
  Future<void> _onClearCompletedTasks(
    ClearCompletedTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final completedTaskIds = state.completedTasks.toList();

    // 从任务管理器中移除已完成的任务
    for (final taskId in completedTaskIds) {
      _taskManager.removeTask(taskId);
    }

    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      completedTasks: [],
      overallProgress: _taskManager.getOverallProgress(),
    ));

    if (kDebugMode) {
      print('【LoadingBloc】已清除 ${completedTaskIds.length} 个已完成任务');
    }
  }

  /// 清除失败任务
  Future<void> _onClearFailedTasks(
    ClearFailedTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final failedTaskIds = state.failedTasks.toList();

    // 从任务管理器中移除失败的任务
    for (final taskId in failedTaskIds) {
      _taskManager.removeTask(taskId);
    }

    emit(state.copyWith(
      taskStates: _taskManager.getAllTaskStates(),
      failedTasks: [],
      overallProgress: _taskManager.getOverallProgress(),
    ));

    if (kDebugMode) {
      print('【LoadingBloc】已清除 ${failedTaskIds.length} 个失败任务');
    }
  }

  /// 重置加载状态
  Future<void> _onResetLoadingState(
    ResetLoadingState event,
    Emitter<LoadingBlocState> emit,
  ) async {
    // 取消所有正在执行的任务
    add(const CancelAllTasks(reason: '重置加载状态'));

    // 清理所有资源
    _clearAllTimers();
    _cancelTokens.clear();
    _taskStartTimes.clear();
    _taskDurations.clear();
    _taskManager.clearAllTasks();

    // 重置状态
    emit(LoadingBlocState.initial());

    if (kDebugMode) {
      print('【LoadingBloc】加载状态已重置');
    }
  }

  /// 暂停任务执行
  Future<void> _onPauseTaskExecution(
    PauseTaskExecution event,
    Emitter<LoadingBlocState> emit,
  ) async {
    if (event.taskId != null) {
      _taskManager.pauseTask(event.taskId!);
      if (kDebugMode) {
        print('【LoadingBloc】任务已暂停: ${event.taskId}');
      }
    } else {
      // 暂停所有任务
      for (final taskId in _taskManager.getAllTasks().keys) {
        _taskManager.pauseTask(taskId);
      }
      if (kDebugMode) {
        print('【LoadingBloc】所有任务已暂停');
      }
    }
  }

  /// 恢复任务执行
  Future<void> _onResumeTaskExecution(
    ResumeTaskExecution event,
    Emitter<LoadingBlocState> emit,
  ) async {
    if (event.taskId != null) {
      _taskManager.resumeTask(event.taskId!);
      if (kDebugMode) {
        print('【LoadingBloc】任务已恢复: ${event.taskId}');
      }
    } else {
      // 恢复所有任务
      for (final taskId in _taskManager.getAllTasks().keys) {
        _taskManager.resumeTask(taskId);
      }
      if (kDebugMode) {
        print('【LoadingBloc】所有任务已恢复');
      }
    }

    // 检查是否有可执行的任务
    add(const ExecuteNextBatch());
  }

  /// 设置任务优先级
  Future<void> _onSetTaskPriority(
    SetTaskPriority event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final task = _taskManager.getTask(event.taskId);
    if (task != null) {
      final updatedTask = task.copyWith(priority: event.priority);
      _taskManager.removeTask(event.taskId);
      _taskManager.registerTask(updatedTask);

      emit(state.copyWith(
        taskStates: _taskManager.getAllTaskStates(),
      ));

      if (kDebugMode) {
        print(
            '【LoadingBloc】任务优先级已更新: ${event.taskId} -> ${event.priority.name}');
      }
    }
  }

  /// 批量执行任务
  Future<void> _onBatchExecuteTasks(
    BatchExecuteTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final maxConcurrent = event.maxConcurrent ?? _maxConcurrentTasks;
    final executableTasks = event.taskIds
        .map((id) => _taskManager.getTask(id))
        .where((task) => task != null)
        .cast<LoadingTask>()
        .where((task) {
      final currentState = _taskManager.getTaskState(task.id);
      return currentState is LoadingIdle && !_taskManager.isTaskPaused(task.id);
    }).toList();

    // 按优先级排序并限制并发数
    executableTasks
        .sort((a, b) => a.priority.index.compareTo(b.priority.index));
    final tasksToExecute = executableTasks.take(maxConcurrent).toList();

    for (final task in tasksToExecute) {
      await _executeTask(task, event.context ?? {}, emit);
    }

    if (kDebugMode) {
      print('【LoadingBloc】批量执行 ${tasksToExecute.length} 个任务');
    }
  }

  /// 执行依赖任务链
  Future<void> _onExecuteDependencyChain(
    ExecuteDependencyChain event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final dependencyChain = _taskManager.getDependencyChain(event.rootTaskId);

    if (kDebugMode) {
      print('【LoadingBloc】执行依赖链: $dependencyChain');
    }

    // 按依赖顺序执行任务
    for (final taskId in dependencyChain) {
      final task = _taskManager.getTask(taskId);
      final currentState = _taskManager.getTaskState(taskId);

      if (task != null && currentState is LoadingIdle) {
        await _executeTask(task, event.context ?? {}, emit);

        // 等待任务完成或失败
        while (true) {
          final state = _taskManager.getTaskState(taskId);
          if (state is LoadingSuccess ||
              state is LoadingError ||
              state is LoadingCancelled) {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 如果任务失败，停止执行链
        final finalState = _taskManager.getTaskState(taskId);
        if (finalState is LoadingError) {
          if (kDebugMode) {
            print('【LoadingBloc】依赖链执行中断，任务失败: $taskId');
          }
          break;
        }
      }
    }
  }

  /// 任务超时处理
  Future<void> _onTaskTimeout(
    TaskTimeout event,
    Emitter<LoadingBlocState> emit,
  ) async {
    add(FailTask(
      taskId: event.taskId,
      error: '任务执行超时',
      errorCode: 'TIMEOUT',
      isRetryable: true,
    ));
  }

  /// 检查依赖任务
  Future<void> _onCheckDependencies(
    CheckDependencies event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final executableTasks = _taskManager.getParallelExecutableTasks(
        _maxConcurrentTasks - state.activeTasks.length);

    if (executableTasks.isNotEmpty) {
      add(const ExecuteNextBatch());
    }
  }

  /// 执行下一批任务
  Future<void> _onExecuteNextBatch(
    ExecuteNextBatch event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final availableSlots = _maxConcurrentTasks - state.activeTasks.length;
    if (availableSlots <= 0) return;

    final executableTasks =
        _taskManager.getParallelExecutableTasks(availableSlots);

    for (final task in executableTasks) {
      await _executeTask(task, {}, emit);
    }
  }
}
