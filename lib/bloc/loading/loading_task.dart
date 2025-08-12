import 'dart:async';
import 'package:equatable/equatable.dart';
import 'loading_state.dart';

/// 任务执行器类型定义
typedef TaskExecutor<T> = Future<T> Function(Map<String, dynamic> context);

/// 进度回调类型定义
typedef ProgressCallback = void Function(double progress, String? message);

/// 加载任务定义
class LoadingTask<T> extends Equatable {
  final String id;
  final String name;
  final String description;
  final LoadingPriority priority;
  final List<String> dependencies;
  final TaskExecutor<T> executor;
  final Duration? timeout;
  final int maxRetries;
  final Duration retryDelay;
  final Map<String, dynamic> metadata;
  final bool canBeCancelled;
  final bool requiresNetwork;
  final List<String> tags;

  const LoadingTask({
    required this.id,
    required this.name,
    required this.executor,
    this.description = '',
    this.priority = LoadingPriority.normal,
    this.dependencies = const [],
    this.timeout,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.metadata = const {},
    this.canBeCancelled = true,
    this.requiresNetwork = false,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        priority,
        dependencies,
        timeout,
        maxRetries,
        retryDelay,
        metadata,
        canBeCancelled,
        requiresNetwork,
        tags
      ];

  /// 创建任务的副本，可以修改部分属性
  LoadingTask<T> copyWith({
    String? id,
    String? name,
    String? description,
    LoadingPriority? priority,
    List<String>? dependencies,
    TaskExecutor<T>? executor,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    Map<String, dynamic>? metadata,
    bool? canBeCancelled,
    bool? requiresNetwork,
    List<String>? tags,
  }) {
    return LoadingTask<T>(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dependencies: dependencies ?? this.dependencies,
      executor: executor ?? this.executor,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      metadata: metadata ?? this.metadata,
      canBeCancelled: canBeCancelled ?? this.canBeCancelled,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      tags: tags ?? this.tags,
    );
  }

  /// 检查任务是否有特定标签
  bool hasTag(String tag) {
    return tags.contains(tag);
  }

  /// 检查任务是否依赖于另一个任务
  bool dependsOn(String taskId) {
    return dependencies.contains(taskId);
  }

  /// 获取任务的估计执行时间（基于超时时间）
  Duration get estimatedDuration {
    return timeout ?? const Duration(seconds: 30);
  }
}
