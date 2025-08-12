import 'package:equatable/equatable.dart';

/// 应用初始化阶段枚举
enum AppInitPhase {
  notStarted, // 未开始
  infrastructure, // 基础设施初始化
  coreData, // 核心数据加载
  userData, // 用户数据加载
  services, // 服务初始化
  completed, // 完成
  failed, // 失败
}

/// 应用初始化状态基类
abstract class AppInitState extends Equatable {
  const AppInitState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class AppInitInitial extends AppInitState {
  const AppInitInitial();
}

/// 初始化进行中状态
class AppInitInProgress extends AppInitState {
  final AppInitPhase currentPhase;
  final String currentMessage;
  final double overallProgress; // 0.0 - 1.0
  final Map<String, dynamic> phaseData; // 各阶段的数据
  final List<String> completedTasks;
  final List<String> failedTasks;
  final DateTime startTime;

  const AppInitInProgress({
    required this.currentPhase,
    required this.currentMessage,
    required this.overallProgress,
    this.phaseData = const {},
    this.completedTasks = const [],
    this.failedTasks = const [],
    required this.startTime,
  });

  factory AppInitInProgress.now({
    required AppInitPhase currentPhase,
    required String currentMessage,
    required double overallProgress,
    Map<String, dynamic> phaseData = const {},
    List<String> completedTasks = const [],
    List<String> failedTasks = const [],
  }) {
    return AppInitInProgress(
      currentPhase: currentPhase,
      currentMessage: currentMessage,
      overallProgress: overallProgress,
      phaseData: phaseData,
      completedTasks: completedTasks,
      failedTasks: failedTasks,
      startTime: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        currentPhase,
        currentMessage,
        overallProgress,
        phaseData,
        completedTasks,
        failedTasks,
        startTime
      ];

  AppInitInProgress copyWith({
    AppInitPhase? currentPhase,
    String? currentMessage,
    double? overallProgress,
    Map<String, dynamic>? phaseData,
    List<String>? completedTasks,
    List<String>? failedTasks,
    DateTime? startTime,
  }) {
    return AppInitInProgress(
      currentPhase: currentPhase ?? this.currentPhase,
      currentMessage: currentMessage ?? this.currentMessage,
      overallProgress: overallProgress ?? this.overallProgress,
      phaseData: phaseData ?? this.phaseData,
      completedTasks: completedTasks ?? this.completedTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      startTime: startTime ?? this.startTime,
    );
  }

  /// 获取当前阶段的进度描述
  String get phaseDescription {
    switch (currentPhase) {
      case AppInitPhase.notStarted:
        return '准备启动应用...';
      case AppInitPhase.infrastructure:
        return '初始化基础设施...';
      case AppInitPhase.coreData:
        return '加载核心数据...';
      case AppInitPhase.userData:
        return '加载用户数据...';
      case AppInitPhase.services:
        return '启动后台服务...';
      case AppInitPhase.completed:
        return '初始化完成';
      case AppInitPhase.failed:
        return '初始化失败';
    }
  }

  /// 获取阶段权重（用于计算总进度）
  double get phaseWeight {
    switch (currentPhase) {
      case AppInitPhase.notStarted:
        return 0.0;
      case AppInitPhase.infrastructure:
        return 0.2;
      case AppInitPhase.coreData:
        return 0.4;
      case AppInitPhase.userData:
        return 0.3;
      case AppInitPhase.services:
        return 0.1;
      case AppInitPhase.completed:
        return 1.0;
      case AppInitPhase.failed:
        return 0.0;
    }
  }

  /// 检查是否有关键任务失败
  bool get hasCriticalFailures {
    return failedTasks.any((task) =>
        task.contains('database') ||
        task.contains('storage') ||
        task.contains('auth'));
  }

  /// 获取初始化耗时
  Duration get elapsedTime {
    if (startTime.microsecondsSinceEpoch == 0) {
      return Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }
}

/// 初始化成功状态
class AppInitSuccess extends AppInitState {
  final Map<String, dynamic> initializationData;
  final Duration totalDuration;
  final List<String> completedTasks;
  final Map<String, Duration> taskDurations;
  final DateTime completedAt;

  AppInitSuccess({
    required this.initializationData,
    required this.totalDuration,
    required this.completedTasks,
    this.taskDurations = const {},
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  @override
  List<Object?> get props => [
        initializationData,
        totalDuration,
        completedTasks,
        taskDurations,
        completedAt
      ];

  /// 获取初始化统计信息
  Map<String, dynamic> get statistics {
    return {
      'totalTasks': completedTasks.length,
      'totalDuration': totalDuration.inMilliseconds,
      'averageTaskDuration': taskDurations.isNotEmpty
          ? taskDurations.values
                  .map((d) => d.inMilliseconds)
                  .reduce((a, b) => a + b) /
              taskDurations.length
          : 0,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}

/// 初始化失败状态
class AppInitFailure extends AppInitState {
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final AppInitPhase failedPhase;
  final String failedTask;
  final Map<String, dynamic> debugInfo;
  final bool isRetryable;
  final List<String> completedTasks;
  final Duration elapsedTime;

  const AppInitFailure({
    required this.error,
    this.errorCode,
    this.stackTrace,
    required this.failedPhase,
    required this.failedTask,
    this.debugInfo = const {},
    this.isRetryable = true,
    this.completedTasks = const [],
    this.elapsedTime = Duration.zero,
  });

  @override
  List<Object?> get props => [
        error,
        errorCode,
        failedPhase,
        failedTask,
        debugInfo,
        isRetryable,
        completedTasks,
        elapsedTime
      ];

  /// 获取用户友好的错误消息
  String get userFriendlyMessage {
    switch (failedPhase) {
      case AppInitPhase.infrastructure:
        return '应用基础组件初始化失败，请重试';
      case AppInitPhase.coreData:
        return '核心数据加载失败，请检查网络连接';
      case AppInitPhase.userData:
        return '用户数据加载失败，将使用默认设置';
      case AppInitPhase.services:
        return '后台服务启动失败，部分功能可能受限';
      default:
        return '应用初始化失败，请重试';
    }
  }

  /// 获取错误严重程度
  ErrorSeverity get severity {
    if (failedTask.contains('database') || failedTask.contains('storage')) {
      return ErrorSeverity.critical;
    } else if (failedTask.contains('auth') || failedTask.contains('settings')) {
      return ErrorSeverity.high;
    } else if (failedTask.contains('sync') || failedTask.contains('cache')) {
      return ErrorSeverity.medium;
    } else {
      return ErrorSeverity.low;
    }
  }

  /// 获取建议的恢复操作
  List<String> get recoveryActions {
    switch (severity) {
      case ErrorSeverity.critical:
        return ['重启应用', '清除应用数据', '联系技术支持'];
      case ErrorSeverity.high:
        return ['重试初始化', '检查网络连接', '重新登录'];
      case ErrorSeverity.medium:
        return ['重试初始化', '跳过可选功能'];
      case ErrorSeverity.low:
        return ['继续使用', '稍后重试'];
    }
  }
}

/// 错误严重程度枚举
enum ErrorSeverity {
  critical, // 关键错误，应用无法正常使用
  high, // 高级错误，核心功能受影响
  medium, // 中级错误，部分功能受影响
  low, // 低级错误，不影响主要功能
}

/// 初始化重试状态
class AppInitRetrying extends AppInitState {
  final int retryCount;
  final String lastError;
  final AppInitPhase retryPhase;
  final Duration retryDelay;
  final DateTime retryAt;

  AppInitRetrying({
    required this.retryCount,
    required this.lastError,
    required this.retryPhase,
    this.retryDelay = const Duration(seconds: 3),
    DateTime? retryAt,
  }) : retryAt = retryAt ?? DateTime.now().add(retryDelay);

  @override
  List<Object?> get props =>
      [retryCount, lastError, retryPhase, retryDelay, retryAt];

  /// 获取重试倒计时
  Duration get remainingDelay {
    final now = DateTime.now();
    if (now.isAfter(retryAt)) {
      return Duration.zero;
    }
    return retryAt.difference(now);
  }

  /// 检查是否可以重试
  bool get canRetry {
    return DateTime.now().isAfter(retryAt);
  }
}
