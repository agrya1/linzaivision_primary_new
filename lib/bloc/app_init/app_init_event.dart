import 'package:equatable/equatable.dart';
import 'app_init_state.dart';

/// 应用初始化事件基类
abstract class AppInitEvent extends Equatable {
  const AppInitEvent();
  
  @override
  List<Object?> get props => [];
}

/// 开始应用初始化事件
class StartAppInitialization extends AppInitEvent {
  final bool forceRestart; // 是否强制重新初始化
  final Map<String, dynamic> initConfig; // 初始化配置
  final List<String> skipTasks; // 跳过的任务列表
  
  const StartAppInitialization({
    this.forceRestart = false,
    this.initConfig = const {},
    this.skipTasks = const [],
  });
  
  @override
  List<Object?> get props => [forceRestart, initConfig, skipTasks];
}

/// 阶段开始事件
class PhaseStarted extends AppInitEvent {
  final AppInitPhase phase;
  final String message;
  final Map<String, dynamic> phaseConfig;
  
  const PhaseStarted({
    required this.phase,
    required this.message,
    this.phaseConfig = const {},
  });
  
  @override
  List<Object?> get props => [phase, message, phaseConfig];
}

/// 任务完成事件
class TaskCompleted extends AppInitEvent {
  final String taskId;
  final String taskName;
  final Map<String, dynamic> taskResult;
  final Duration taskDuration;
  final AppInitPhase phase;
  
  const TaskCompleted({
    required this.taskId,
    required this.taskName,
    required this.taskResult,
    required this.taskDuration,
    required this.phase,
  });
  
  @override
  List<Object?> get props => [taskId, taskName, taskResult, taskDuration, phase];
}

/// 任务失败事件
class TaskFailed extends AppInitEvent {
  final String taskId;
  final String taskName;
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final AppInitPhase phase;
  final bool isCritical;
  final Map<String, dynamic> debugInfo;
  
  const TaskFailed({
    required this.taskId,
    required this.taskName,
    required this.error,
    this.errorCode,
    this.stackTrace,
    required this.phase,
    this.isCritical = false,
    this.debugInfo = const {},
  });
  
  @override
  List<Object?> get props => [
    taskId, taskName, error, errorCode, phase, isCritical, debugInfo
  ];
}

/// 进度更新事件
class ProgressUpdated extends AppInitEvent {
  final double progress; // 0.0 - 1.0
  final String message;
  final AppInitPhase currentPhase;
  final Map<String, dynamic> progressData;
  
  const ProgressUpdated({
    required this.progress,
    required this.message,
    required this.currentPhase,
    this.progressData = const {},
  });
  
  @override
  List<Object?> get props => [progress, message, currentPhase, progressData];
}

/// 阶段完成事件
class PhaseCompleted extends AppInitEvent {
  final AppInitPhase completedPhase;
  final Map<String, dynamic> phaseResult;
  final Duration phaseDuration;
  final List<String> completedTasks;
  final List<String> skippedTasks;
  
  const PhaseCompleted({
    required this.completedPhase,
    required this.phaseResult,
    required this.phaseDuration,
    this.completedTasks = const [],
    this.skippedTasks = const [],
  });
  
  @override
  List<Object?> get props => [
    completedPhase, phaseResult, phaseDuration, completedTasks, skippedTasks
  ];
}

/// 初始化完成事件
class InitializationCompleted extends AppInitEvent {
  final Map<String, dynamic> initializationData;
  final Duration totalDuration;
  final List<String> completedTasks;
  final Map<String, Duration> taskDurations;
  final Map<String, dynamic> statistics;
  
  const InitializationCompleted({
    required this.initializationData,
    required this.totalDuration,
    required this.completedTasks,
    this.taskDurations = const {},
    this.statistics = const {},
  });
  
  @override
  List<Object?> get props => [
    initializationData, totalDuration, completedTasks, taskDurations, statistics
  ];
}

/// 初始化失败事件
class InitializationFailed extends AppInitEvent {
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final AppInitPhase failedPhase;
  final String failedTask;
  final Map<String, dynamic> debugInfo;
  final bool isRetryable;
  final List<String> completedTasks;
  
  const InitializationFailed({
    required this.error,
    this.errorCode,
    this.stackTrace,
    required this.failedPhase,
    required this.failedTask,
    this.debugInfo = const {},
    this.isRetryable = true,
    this.completedTasks = const [],
  });
  
  @override
  List<Object?> get props => [
    error, errorCode, failedPhase, failedTask, debugInfo, 
    isRetryable, completedTasks
  ];
}

/// 重试初始化事件
class RetryInitialization extends AppInitEvent {
  final AppInitPhase? fromPhase; // 从哪个阶段开始重试，null表示从头开始
  final Map<String, dynamic> retryConfig;
  final List<String> skipFailedTasks; // 跳过之前失败的任务
  
  const RetryInitialization({
    this.fromPhase,
    this.retryConfig = const {},
    this.skipFailedTasks = const [],
  });
  
  @override
  List<Object?> get props => [fromPhase, retryConfig, skipFailedTasks];
}

/// 跳过当前任务事件
class SkipCurrentTask extends AppInitEvent {
  final String taskId;
  final String reason;
  final bool continueWithPhase;
  
  const SkipCurrentTask({
    required this.taskId,
    required this.reason,
    this.continueWithPhase = true,
  });
  
  @override
  List<Object?> get props => [taskId, reason, continueWithPhase];
}

/// 取消初始化事件
class CancelInitialization extends AppInitEvent {
  final String reason;
  final bool saveProgress; // 是否保存当前进度
  
  const CancelInitialization({
    required this.reason,
    this.saveProgress = false,
  });
  
  @override
  List<Object?> get props => [reason, saveProgress];
}

/// 暂停初始化事件
class PauseInitialization extends AppInitEvent {
  final String reason;
  final Duration? resumeAfter; // 自动恢复时间
  
  const PauseInitialization({
    required this.reason,
    this.resumeAfter,
  });
  
  @override
  List<Object?> get props => [reason, resumeAfter];
}

/// 恢复初始化事件
class ResumeInitialization extends AppInitEvent {
  final Map<String, dynamic> resumeConfig;
  
  const ResumeInitialization({
    this.resumeConfig = const {},
  });
  
  @override
  List<Object?> get props => [resumeConfig];
}

/// 更新初始化配置事件
class UpdateInitConfig extends AppInitEvent {
  final Map<String, dynamic> configUpdates;
  final bool applyImmediately; // 是否立即应用配置
  
  const UpdateInitConfig({
    required this.configUpdates,
    this.applyImmediately = false,
  });
  
  @override
  List<Object?> get props => [configUpdates, applyImmediately];
}

/// 请求初始化状态事件
class RequestInitStatus extends AppInitEvent {
  final bool includeDebugInfo;
  final bool includeStatistics;
  
  const RequestInitStatus({
    this.includeDebugInfo = false,
    this.includeStatistics = true,
  });
  
  @override
  List<Object?> get props => [includeDebugInfo, includeStatistics];
}

/// 清理初始化数据事件
class CleanupInitData extends AppInitEvent {
  final bool keepStatistics; // 是否保留统计信息
  final bool keepErrorLogs; // 是否保留错误日志
  
  const CleanupInitData({
    this.keepStatistics = true,
    this.keepErrorLogs = true,
  });
  
  @override
  List<Object?> get props => [keepStatistics, keepErrorLogs];
}

/// 设置初始化超时事件
class SetInitTimeout extends AppInitEvent {
  final Duration timeout;
  final AppInitPhase? forPhase; // 为特定阶段设置超时，null表示全局超时
  
  const SetInitTimeout({
    required this.timeout,
    this.forPhase,
  });
  
  @override
  List<Object?> get props => [timeout, forPhase];
}

/// 初始化超时事件
class InitializationTimeout extends AppInitEvent {
  final AppInitPhase timeoutPhase;
  final String currentTask;
  final Duration elapsedTime;
  final Duration timeoutDuration;
  
  const InitializationTimeout({
    required this.timeoutPhase,
    required this.currentTask,
    required this.elapsedTime,
    required this.timeoutDuration,
  });
  
  @override
  List<Object?> get props => [timeoutPhase, currentTask, elapsedTime, timeoutDuration];
}
