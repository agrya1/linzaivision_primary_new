import 'package:equatable/equatable.dart';
import 'loading_task.dart';
import 'loading_state.dart';

/// 加载事件基类
abstract class LoadingEvent extends Equatable {
  const LoadingEvent();

  @override
  List<Object?> get props => [];
}

/// 注册加载任务事件
class RegisterLoadingTasks extends LoadingEvent {
  final List<LoadingTask> tasks;
  final bool clearExisting;

  const RegisterLoadingTasks(
    this.tasks, {
    this.clearExisting = false,
  });

  @override
  List<Object?> get props => [tasks, clearExisting];
}

/// 开始执行加载任务事件
class StartLoadingTask extends LoadingEvent {
  final String taskId;
  final Map<String, dynamic>? context;

  const StartLoadingTask(
    this.taskId, {
    this.context,
  });

  @override
  List<Object?> get props => [taskId, context];
}

/// 开始执行多个任务事件
class StartLoadingTasks extends LoadingEvent {
  final List<String> taskIds;
  final Map<String, dynamic>? context;

  const StartLoadingTasks(
    this.taskIds, {
    this.context,
  });

  @override
  List<Object?> get props => [taskIds, context];
}

/// 更新任务进度事件
class UpdateTaskProgress extends LoadingEvent {
  final String taskId;
  final double progress;
  final String? message;
  final Map<String, dynamic>? metadata;

  const UpdateTaskProgress({
    required this.taskId,
    required this.progress,
    this.message,
    this.metadata,
  });

  @override
  List<Object?> get props => [taskId, progress, message, metadata];
}

/// 任务完成事件
class CompleteTask extends LoadingEvent {
  final String taskId;
  final dynamic data;
  final Duration duration;
  final Map<String, dynamic>? metadata;

  const CompleteTask({
    required this.taskId,
    required this.data,
    required this.duration,
    this.metadata,
  });

  @override
  List<Object?> get props => [taskId, data, duration, metadata];
}

/// 任务失败事件
class FailTask extends LoadingEvent {
  final String taskId;
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final bool isRetryable;
  final Duration? retryDelay;
  final Map<String, dynamic>? metadata;

  const FailTask({
    required this.taskId,
    required this.error,
    this.errorCode,
    this.stackTrace,
    this.isRetryable = true,
    this.retryDelay,
    this.metadata,
  });

  @override
  List<Object?> get props =>
      [taskId, error, errorCode, isRetryable, retryDelay, metadata];
}

/// 重试失败任务事件
class RetryFailedTask extends LoadingEvent {
  final String taskId;
  final Map<String, dynamic>? context;

  const RetryFailedTask(
    this.taskId, {
    this.context,
  });

  @override
  List<Object?> get props => [taskId, context];
}

/// 重试所有失败任务事件
class RetryAllFailedTasks extends LoadingEvent {
  final Map<String, dynamic>? context;

  const RetryAllFailedTasks({this.context});

  @override
  List<Object?> get props => [context];
}

/// 取消加载任务事件
class CancelLoadingTask extends LoadingEvent {
  final String taskId;
  final String reason;

  const CancelLoadingTask(
    this.taskId, {
    this.reason = '用户取消',
  });

  @override
  List<Object?> get props => [taskId, reason];
}

/// 取消所有任务事件
class CancelAllTasks extends LoadingEvent {
  final String reason;

  const CancelAllTasks({
    this.reason = '用户取消所有任务',
  });

  @override
  List<Object?> get props => [reason];
}

/// 清除已完成任务事件
class ClearCompletedTasks extends LoadingEvent {
  const ClearCompletedTasks();
}

/// 清除失败任务事件
class ClearFailedTasks extends LoadingEvent {
  const ClearFailedTasks();
}

/// 重置加载状态事件
class ResetLoadingState extends LoadingEvent {
  const ResetLoadingState();
}

/// 暂停任务执行事件
class PauseTaskExecution extends LoadingEvent {
  final String? taskId; // null表示暂停所有任务

  const PauseTaskExecution({this.taskId});

  @override
  List<Object?> get props => [taskId];
}

/// 恢复任务执行事件
class ResumeTaskExecution extends LoadingEvent {
  final String? taskId; // null表示恢复所有任务

  const ResumeTaskExecution({this.taskId});

  @override
  List<Object?> get props => [taskId];
}

/// 设置任务优先级事件
class SetTaskPriority extends LoadingEvent {
  final String taskId;
  final LoadingPriority priority;

  const SetTaskPriority({
    required this.taskId,
    required this.priority,
  });

  @override
  List<Object?> get props => [taskId, priority];
}

/// 批量执行任务事件
class BatchExecuteTasks extends LoadingEvent {
  final List<String> taskIds;
  final int? maxConcurrent; // 最大并发数，null表示无限制
  final Map<String, dynamic>? context;

  const BatchExecuteTasks({
    required this.taskIds,
    this.maxConcurrent,
    this.context,
  });

  @override
  List<Object?> get props => [taskIds, maxConcurrent, context];
}

/// 执行依赖任务链事件
class ExecuteDependencyChain extends LoadingEvent {
  final String rootTaskId;
  final Map<String, dynamic>? context;

  const ExecuteDependencyChain({
    required this.rootTaskId,
    this.context,
  });

  @override
  List<Object?> get props => [rootTaskId, context];
}

/// 获取任务状态事件
class GetTaskStatus extends LoadingEvent {
  final String taskId;

  const GetTaskStatus(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 获取加载统计事件
class GetLoadingStats extends LoadingEvent {
  const GetLoadingStats();
}

/// 设置全局加载配置事件
class SetLoadingConfig extends LoadingEvent {
  final int maxConcurrentTasks;
  final Duration defaultTimeout;
  final int defaultMaxRetries;
  final Duration defaultRetryDelay;
  final bool enablePerformanceMonitoring;

  const SetLoadingConfig({
    this.maxConcurrentTasks = 5,
    this.defaultTimeout = const Duration(seconds: 30),
    this.defaultMaxRetries = 3,
    this.defaultRetryDelay = const Duration(seconds: 1),
    this.enablePerformanceMonitoring = true,
  });

  @override
  List<Object?> get props => [
        maxConcurrentTasks,
        defaultTimeout,
        defaultMaxRetries,
        defaultRetryDelay,
        enablePerformanceMonitoring
      ];
}

/// 内部事件：任务超时
class TaskTimeout extends LoadingEvent {
  final String taskId;

  const TaskTimeout(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

/// 内部事件：检查依赖任务
class CheckDependencies extends LoadingEvent {
  const CheckDependencies();
}

/// 内部事件：执行下一批任务
class ExecuteNextBatch extends LoadingEvent {
  const ExecuteNextBatch();
}
