import 'package:equatable/equatable.dart';

/// 加载优先级枚举
enum LoadingPriority {
  critical, // 关键数据，阻塞UI
  high, // 重要数据，优先加载
  normal, // 普通数据，正常加载
  low, // 次要数据，后台加载
  background // 背景数据，空闲时加载
}

/// 统一的加载状态基类
abstract class LoadingState extends Equatable {
  final String taskId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const LoadingState({
    required this.taskId,
    required this.timestamp,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [taskId, timestamp, metadata];
}

/// 空闲状态 - 任务未开始
class LoadingIdle extends LoadingState {
  LoadingIdle({
    required String taskId,
    Map<String, dynamic> metadata = const {},
  }) : super(
          taskId: taskId,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0), // 使用常量避免时间戳比较问题
          metadata: metadata,
        );

  // 创建带当前时间戳的实例
  factory LoadingIdle.now({
    required String taskId,
    Map<String, dynamic> metadata = const {},
  }) {
    return LoadingIdle(
      taskId: taskId,
      metadata: {
        ...metadata,
        'created_at': DateTime.now().millisecondsSinceEpoch
      },
    );
  }
}

/// 加载中状态
class LoadingInProgress extends LoadingState {
  final String message;
  final double? progress; // 0.0 - 1.0
  final LoadingPriority priority;
  final List<String> dependencies;

  LoadingInProgress({
    required String taskId,
    required this.message,
    this.progress,
    this.priority = LoadingPriority.normal,
    this.dependencies = const [],
    Map<String, dynamic> metadata = const {},
  }) : super(
          taskId: taskId,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
          metadata: metadata,
        );

  factory LoadingInProgress.now({
    required String taskId,
    required String message,
    double? progress,
    LoadingPriority priority = LoadingPriority.normal,
    List<String> dependencies = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return LoadingInProgress(
      taskId: taskId,
      message: message,
      progress: progress,
      priority: priority,
      dependencies: dependencies,
      metadata: {
        ...metadata,
        'started_at': DateTime.now().millisecondsSinceEpoch
      },
    );
  }

  @override
  List<Object?> get props =>
      [taskId, timestamp, metadata, message, progress, priority, dependencies];

  /// 更新进度
  LoadingInProgress updateProgress(double newProgress, {String? newMessage}) {
    return LoadingInProgress(
      taskId: taskId,
      message: newMessage ?? message,
      progress: newProgress,
      priority: priority,
      dependencies: dependencies,
      metadata: {
        ...metadata,
        'last_updated': DateTime.now().millisecondsSinceEpoch
      },
    );
  }
}

/// 加载成功状态
class LoadingSuccess extends LoadingState {
  final dynamic data;
  final Duration duration;

  LoadingSuccess({
    required String taskId,
    required this.data,
    required this.duration,
    Map<String, dynamic> metadata = const {},
  }) : super(
          taskId: taskId,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
          metadata: metadata,
        );

  factory LoadingSuccess.now({
    required String taskId,
    required dynamic data,
    required Duration duration,
    Map<String, dynamic> metadata = const {},
  }) {
    return LoadingSuccess(
      taskId: taskId,
      data: data,
      duration: duration,
      metadata: {
        ...metadata,
        'completed_at': DateTime.now().millisecondsSinceEpoch
      },
    );
  }

  @override
  List<Object?> get props => [taskId, timestamp, metadata, data, duration];
}

/// 加载错误状态
class LoadingError extends LoadingState {
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final bool isRetryable;
  final int retryCount;
  final DateTime? nextRetryTime;

  LoadingError({
    required String taskId,
    required this.error,
    this.errorCode,
    this.stackTrace,
    this.isRetryable = true,
    this.retryCount = 0,
    this.nextRetryTime,
    Map<String, dynamic> metadata = const {},
  }) : super(
          taskId: taskId,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
          metadata: metadata,
        );

  factory LoadingError.now({
    required String taskId,
    required String error,
    String? errorCode,
    StackTrace? stackTrace,
    bool isRetryable = true,
    int retryCount = 0,
    Duration? retryDelay,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return LoadingError(
      taskId: taskId,
      error: error,
      errorCode: errorCode,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
      retryCount: retryCount,
      nextRetryTime: retryDelay != null ? now.add(retryDelay) : null,
      metadata: {...metadata, 'failed_at': now.millisecondsSinceEpoch},
    );
  }

  @override
  List<Object?> get props => [
        taskId,
        timestamp,
        metadata,
        error,
        errorCode,
        isRetryable,
        retryCount,
        nextRetryTime
      ];

  /// 创建重试状态
  LoadingError withRetry() {
    return LoadingError(
      taskId: taskId,
      error: error,
      errorCode: errorCode,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
      retryCount: retryCount + 1,
      nextRetryTime: nextRetryTime,
      metadata: {
        ...metadata,
        'retry_at': DateTime.now().millisecondsSinceEpoch
      },
    );
  }
}

/// 任务取消状态
class LoadingCancelled extends LoadingState {
  final String reason;

  LoadingCancelled({
    required String taskId,
    required this.reason,
    Map<String, dynamic> metadata = const {},
  }) : super(
          taskId: taskId,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
          metadata: metadata,
        );

  factory LoadingCancelled.now({
    required String taskId,
    required String reason,
    Map<String, dynamic> metadata = const {},
  }) {
    return LoadingCancelled(
      taskId: taskId,
      reason: reason,
      metadata: {
        ...metadata,
        'cancelled_at': DateTime.now().millisecondsSinceEpoch
      },
    );
  }

  @override
  List<Object?> get props => [taskId, timestamp, metadata, reason];
}

/// 整体加载状态
class LoadingBlocState extends Equatable {
  final Map<String, LoadingState> taskStates;
  final double overallProgress;
  final bool isLoading;
  final List<String> activeTasks;
  final List<String> failedTasks;
  final List<String> completedTasks;
  final String? currentMessage;
  final LoadingPriority? currentPriority;
  final DateTime lastUpdateTime;

  LoadingBlocState({
    this.taskStates = const {},
    this.overallProgress = 0.0,
    this.isLoading = false,
    this.activeTasks = const [],
    this.failedTasks = const [],
    this.completedTasks = const [],
    this.currentMessage,
    this.currentPriority,
    DateTime? lastUpdateTime,
  }) : lastUpdateTime =
            lastUpdateTime ?? DateTime.fromMicrosecondsSinceEpoch(0);

  factory LoadingBlocState.initial() {
    return LoadingBlocState(
      lastUpdateTime: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        taskStates,
        overallProgress,
        isLoading,
        activeTasks,
        failedTasks,
        completedTasks,
        currentMessage,
        currentPriority,
        lastUpdateTime
      ];

  LoadingBlocState copyWith({
    Map<String, LoadingState>? taskStates,
    double? overallProgress,
    bool? isLoading,
    List<String>? activeTasks,
    List<String>? failedTasks,
    List<String>? completedTasks,
    String? currentMessage,
    LoadingPriority? currentPriority,
    DateTime? lastUpdateTime,
  }) {
    return LoadingBlocState(
      taskStates: taskStates ?? this.taskStates,
      overallProgress: overallProgress ?? this.overallProgress,
      isLoading: isLoading ?? this.isLoading,
      activeTasks: activeTasks ?? this.activeTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      currentMessage: currentMessage ?? this.currentMessage,
      currentPriority: currentPriority ?? this.currentPriority,
      lastUpdateTime: lastUpdateTime ?? DateTime.now(),
    );
  }

  /// 获取特定任务的状态
  LoadingState? getTaskState(String taskId) {
    return taskStates[taskId];
  }

  /// 检查是否有关键任务正在加载
  bool get hasCriticalTasksLoading {
    return activeTasks.any((taskId) {
      final state = taskStates[taskId];
      return state is LoadingInProgress &&
          state.priority == LoadingPriority.critical;
    });
  }

  /// 获取当前最高优先级
  LoadingPriority? get highestActivePriority {
    LoadingPriority? highest;

    for (final taskId in activeTasks) {
      final state = taskStates[taskId];
      if (state is LoadingInProgress) {
        if (highest == null || state.priority.index < highest.index) {
          highest = state.priority;
        }
      }
    }

    return highest;
  }

  /// 获取加载统计信息
  Map<String, int> get loadingStats {
    int idle = 0, inProgress = 0, success = 0, error = 0, cancelled = 0;

    for (final state in taskStates.values) {
      if (state is LoadingIdle) {
        idle++;
      } else if (state is LoadingInProgress) {
        inProgress++;
      } else if (state is LoadingSuccess) {
        success++;
      } else if (state is LoadingError) {
        error++;
      } else if (state is LoadingCancelled) {
        cancelled++;
      }
    }

    return {
      'idle': idle,
      'inProgress': inProgress,
      'success': success,
      'error': error,
      'cancelled': cancelled,
      'total': taskStates.length,
    };
  }
}
