/// 批量处理优化器
///
/// 提供高效的批量操作处理，包括批量合并、分块处理、并行执行等优化策略
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'transaction_manager.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';

/// 批量处理策略
enum BatchProcessingStrategy {
  sequential, // 顺序处理
  parallel, // 并行处理
  chunked, // 分块处理
  adaptive, // 自适应处理
  prioritized, // 优先级处理
}

/// 批量操作类型
enum BatchOperationType {
  create, // 批量创建
  update, // 批量更新
  delete, // 批量删除
  mixed, // 混合操作
}

/// 批量处理配置
class BatchProcessingConfig {
  final int maxBatchSize;
  final int maxConcurrency;
  final Duration timeout;
  final BatchProcessingStrategy strategy;
  final bool enableOptimization;
  final bool enableRetry;
  final int maxRetries;
  final Duration retryDelay;

  const BatchProcessingConfig({
    this.maxBatchSize = 100,
    this.maxConcurrency = 4,
    this.timeout = const Duration(minutes: 10),
    this.strategy = BatchProcessingStrategy.adaptive,
    this.enableOptimization = true,
    this.enableRetry = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  /// 创建高性能配置
  factory BatchProcessingConfig.highPerformance() {
    return const BatchProcessingConfig(
      maxBatchSize: 200,
      maxConcurrency: 8,
      strategy: BatchProcessingStrategy.parallel,
      enableOptimization: true,
    );
  }

  /// 创建保守配置
  factory BatchProcessingConfig.conservative() {
    return const BatchProcessingConfig(
      maxBatchSize: 50,
      maxConcurrency: 2,
      strategy: BatchProcessingStrategy.sequential,
      enableOptimization: false,
    );
  }
}

/// 批量操作项
class BatchOperationItem<T> {
  final String id;
  final T data;
  final BatchOperationType type;
  final int priority;
  final Map<String, dynamic> metadata;

  const BatchOperationItem({
    required this.id,
    required this.data,
    required this.type,
    this.priority = 0,
    this.metadata = const {},
  });
}

/// 批量处理结果
class BatchProcessingResult<T> {
  final List<BatchOperationResult<T>> results;
  final Duration totalDuration;
  final int successCount;
  final int failureCount;
  final double successRate;
  final Map<String, dynamic> statistics;

  BatchProcessingResult({
    required this.results,
    required this.totalDuration,
    required this.successCount,
    required this.failureCount,
    required this.statistics,
  }) : successRate = results.isEmpty ? 0.0 : successCount / results.length;

  /// 获取成功的结果
  List<BatchOperationResult<T>> get successfulResults =>
      results.where((r) => r.success).toList();

  /// 获取失败的结果
  List<BatchOperationResult<T>> get failedResults =>
      results.where((r) => !r.success).toList();
}

/// 单个操作结果
class BatchOperationResult<T> {
  final String itemId;
  final bool success;
  final T? result;
  final String? error;
  final Duration duration;
  final int retryCount;

  const BatchOperationResult({
    required this.itemId,
    required this.success,
    this.result,
    this.error,
    required this.duration,
    this.retryCount = 0,
  });

  factory BatchOperationResult.success(
      String itemId, T result, Duration duration) {
    return BatchOperationResult(
      itemId: itemId,
      success: true,
      result: result,
      duration: duration,
    );
  }

  factory BatchOperationResult.failure(
      String itemId, String error, Duration duration,
      {int retryCount = 0}) {
    return BatchOperationResult(
      itemId: itemId,
      success: false,
      error: error,
      duration: duration,
      retryCount: retryCount,
    );
  }
}

/// 批量处理器
class BatchProcessor<T> {
  final BatchProcessingConfig config;
  final Future<T> Function(BatchOperationItem<T>) processor;
  final TransactionManager _transactionManager = TransactionManager();

  BatchProcessor({
    required this.processor,
    this.config = const BatchProcessingConfig(),
  });

  /// 处理批量操作
  Future<BatchProcessingResult<T>> processBatch(
      List<BatchOperationItem<T>> items) async {
    if (items.isEmpty) {
      return BatchProcessingResult<T>(
        results: [],
        totalDuration: Duration.zero,
        successCount: 0,
        failureCount: 0,
        statistics: {},
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 1. 预处理和优化
      final optimizedItems =
          config.enableOptimization ? _optimizeItems(items) : items;

      // 2. 选择处理策略
      final strategy = _selectStrategy(optimizedItems);

      // 3. 执行批量处理
      final results = await _executeWithStrategy(optimizedItems, strategy);

      stopwatch.stop();

      // 4. 统计结果
      final successCount = results.where((r) => r.success).length;
      final failureCount = results.length - successCount;

      final statistics = _calculateStatistics(results, stopwatch.elapsed);

      return BatchProcessingResult<T>(
        results: results,
        totalDuration: stopwatch.elapsed,
        successCount: successCount,
        failureCount: failureCount,
        statistics: statistics,
      );
    } catch (e) {
      stopwatch.stop();

      // 创建全部失败的结果
      final failedResults = items
          .map((item) => BatchOperationResult<T>.failure(
              item.id, e.toString(), stopwatch.elapsed))
          .toList();

      return BatchProcessingResult<T>(
        results: failedResults,
        totalDuration: stopwatch.elapsed,
        successCount: 0,
        failureCount: items.length,
        statistics: {'error': e.toString()},
      );
    }
  }

  /// 优化操作项
  List<BatchOperationItem<T>> _optimizeItems(
      List<BatchOperationItem<T>> items) {
    // 1. 去重
    final uniqueItems = _deduplicateItems(items);

    // 2. 按类型分组
    final groupedItems = _groupItemsByType(uniqueItems);

    // 3. 按优先级排序
    final sortedItems = _sortItemsByPriority(groupedItems);

    // 4. 合并相似操作
    final mergedItems = _mergeSimilarOperations(sortedItems);

    return mergedItems;
  }

  /// 去重操作项
  List<BatchOperationItem<T>> _deduplicateItems(
      List<BatchOperationItem<T>> items) {
    final seen = <String>{};
    final uniqueItems = <BatchOperationItem<T>>[];

    for (final item in items) {
      if (!seen.contains(item.id)) {
        seen.add(item.id);
        uniqueItems.add(item);
      }
    }

    return uniqueItems;
  }

  /// 按类型分组
  List<BatchOperationItem<T>> _groupItemsByType(
      List<BatchOperationItem<T>> items) {
    final grouped = <BatchOperationType, List<BatchOperationItem<T>>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    // 按类型优先级重新排列：delete -> update -> create
    final result = <BatchOperationItem<T>>[];

    if (grouped.containsKey(BatchOperationType.delete)) {
      result.addAll(grouped[BatchOperationType.delete]!);
    }
    if (grouped.containsKey(BatchOperationType.update)) {
      result.addAll(grouped[BatchOperationType.update]!);
    }
    if (grouped.containsKey(BatchOperationType.create)) {
      result.addAll(grouped[BatchOperationType.create]!);
    }
    if (grouped.containsKey(BatchOperationType.mixed)) {
      result.addAll(grouped[BatchOperationType.mixed]!);
    }

    return result;
  }

  /// 按优先级排序
  List<BatchOperationItem<T>> _sortItemsByPriority(
      List<BatchOperationItem<T>> items) {
    final sorted = List<BatchOperationItem<T>>.from(items);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  /// 合并相似操作
  List<BatchOperationItem<T>> _mergeSimilarOperations(
      List<BatchOperationItem<T>> items) {
    // 简化实现：直接返回原列表
    // 在实际应用中，可以根据具体业务逻辑合并相似操作
    return items;
  }

  /// 选择处理策略
  BatchProcessingStrategy _selectStrategy(List<BatchOperationItem<T>> items) {
    if (config.strategy != BatchProcessingStrategy.adaptive) {
      return config.strategy;
    }

    // 自适应策略选择
    final itemCount = items.length;
    final hasHighPriorityItems = items.any((item) => item.priority > 5);
    final hasMixedTypes = items.map((item) => item.type).toSet().length > 1;

    if (itemCount <= 10) {
      return BatchProcessingStrategy.sequential;
    } else if (hasHighPriorityItems) {
      return BatchProcessingStrategy.prioritized;
    } else if (hasMixedTypes) {
      return BatchProcessingStrategy.chunked;
    } else if (itemCount > 100) {
      return BatchProcessingStrategy.parallel;
    } else {
      return BatchProcessingStrategy.chunked;
    }
  }

  /// 根据策略执行处理
  Future<List<BatchOperationResult<T>>> _executeWithStrategy(
    List<BatchOperationItem<T>> items,
    BatchProcessingStrategy strategy,
  ) async {
    switch (strategy) {
      case BatchProcessingStrategy.sequential:
        return await _executeSequential(items);
      case BatchProcessingStrategy.parallel:
        return await _executeParallel(items);
      case BatchProcessingStrategy.chunked:
        return await _executeChunked(items);
      case BatchProcessingStrategy.adaptive:
        return await _executeAdaptive(items);
      case BatchProcessingStrategy.prioritized:
        return await _executePrioritized(items);
    }
  }

  /// 顺序执行
  Future<List<BatchOperationResult<T>>> _executeSequential(
      List<BatchOperationItem<T>> items) async {
    final results = <BatchOperationResult<T>>[];

    for (final item in items) {
      final result = await _processItem(item);
      results.add(result);
    }

    return results;
  }

  /// 并行执行
  Future<List<BatchOperationResult<T>>> _executeParallel(
      List<BatchOperationItem<T>> items) async {
    final futures = items.map((item) => _processItem(item));
    return await Future.wait(futures);
  }

  /// 分块执行
  Future<List<BatchOperationResult<T>>> _executeChunked(
      List<BatchOperationItem<T>> items) async {
    final results = <BatchOperationResult<T>>[];
    final chunkSize = min(config.maxBatchSize, items.length);

    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, min(i + chunkSize, items.length));
      final chunkResults = await _executeParallel(chunk);
      results.addAll(chunkResults);
    }

    return results;
  }

  /// 自适应执行
  Future<List<BatchOperationResult<T>>> _executeAdaptive(
      List<BatchOperationItem<T>> items) async {
    // 根据系统负载动态调整策略
    final systemLoad = await _getSystemLoad();

    if (systemLoad > 0.8) {
      return await _executeSequential(items);
    } else if (systemLoad > 0.5) {
      return await _executeChunked(items);
    } else {
      return await _executeParallel(items);
    }
  }

  /// 优先级执行
  Future<List<BatchOperationResult<T>>> _executePrioritized(
      List<BatchOperationItem<T>> items) async {
    // 按优先级分组
    final priorityGroups = <int, List<BatchOperationItem<T>>>{};

    for (final item in items) {
      priorityGroups.putIfAbsent(item.priority, () => []).add(item);
    }

    final results = <BatchOperationResult<T>>[];
    final sortedPriorities = priorityGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final priority in sortedPriorities) {
      final group = priorityGroups[priority]!;
      final groupResults = await _executeParallel(group);
      results.addAll(groupResults);
    }

    return results;
  }

  /// 处理单个项目
  Future<BatchOperationResult<T>> _processItem(
      BatchOperationItem<T> item) async {
    final stopwatch = Stopwatch()..start();
    int retryCount = 0;

    while (retryCount <= config.maxRetries) {
      try {
        final result = await processor(item).timeout(config.timeout);
        stopwatch.stop();

        return BatchOperationResult.success(item.id, result, stopwatch.elapsed);
      } catch (e) {
        retryCount++;

        if (retryCount > config.maxRetries || !config.enableRetry) {
          stopwatch.stop();
          return BatchOperationResult.failure(
            item.id,
            e.toString(),
            stopwatch.elapsed,
            retryCount: retryCount - 1,
          );
        }

        // 等待重试
        await Future.delayed(config.retryDelay);
      }
    }

    stopwatch.stop();
    return BatchOperationResult.failure(
      item.id,
      'Max retries exceeded',
      stopwatch.elapsed,
      retryCount: config.maxRetries,
    );
  }

  /// 获取系统负载
  Future<double> _getSystemLoad() async {
    // 简化实现：返回随机负载值
    // 在实际应用中，可以通过系统API获取真实负载
    return Random().nextDouble();
  }

  /// 计算统计信息
  Map<String, dynamic> _calculateStatistics(
      List<BatchOperationResult<T>> results, Duration totalDuration) {
    if (results.isEmpty) return {};

    final durations = results.map((r) => r.duration.inMilliseconds).toList();
    final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
    final maxDuration = durations.reduce(max);
    final minDuration = durations.reduce(min);

    final retryCount = results.fold(0, (sum, r) => sum + r.retryCount);

    return {
      'totalItems': results.length,
      'avgDurationMs': avgDuration.round(),
      'maxDurationMs': maxDuration,
      'minDurationMs': minDuration,
      'totalRetries': retryCount,
      'throughput': results.length / totalDuration.inSeconds,
    };
  }
}

/// 批量目标操作处理器
class BatchGoalProcessor {
  final BatchProcessor<Goal> _processor;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;

  BatchGoalProcessor({
    required this.databaseHelper,
    required this.goalBloc,
    BatchProcessingConfig? config,
  }) : _processor = BatchProcessor<Goal>(
          processor: _processGoalItem,
          config: config ?? const BatchProcessingConfig(),
        );

  /// 批量创建目标
  Future<BatchProcessingResult<Goal>> createGoals(List<Goal> goals) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'create_${goal.title}_${DateTime.now().millisecondsSinceEpoch}',
              data: goal,
              type: BatchOperationType.create,
              priority: goal.parentId == null ? 10 : 5, // 根目标优先级更高
            ))
        .toList();

    return await _processor.processBatch(items);
  }

  /// 批量更新目标
  Future<BatchProcessingResult<Goal>> updateGoals(List<Goal> goals) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'update_${goal.id}',
              data: goal,
              type: BatchOperationType.update,
              priority: goal.status == GoalStatus.completed ? 8 : 5,
            ))
        .toList();

    return await _processor.processBatch(items);
  }

  /// 批量删除目标
  Future<BatchProcessingResult<Goal>> deleteGoals(List<Goal> goals) async {
    // 按层级排序，先删除子目标
    final sortedGoals = List<Goal>.from(goals);
    sortedGoals.sort((a, b) {
      final aLevel = _getGoalLevel(a);
      final bLevel = _getGoalLevel(b);
      return bLevel.compareTo(aLevel); // 深层级的先删除
    });

    final items = sortedGoals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'delete_${goal.id}',
              data: goal,
              type: BatchOperationType.delete,
              priority: _getGoalLevel(goal), // 层级越深优先级越高
            ))
        .toList();

    return await _processor.processBatch(items);
  }

  /// 批量状态变更
  Future<BatchProcessingResult<Goal>> changeGoalStatuses(
    List<Goal> goals,
    GoalStatus newStatus,
  ) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'status_change_${goal.id}',
              data: goal.copyWith(status: newStatus),
              type: BatchOperationType.update,
              priority: newStatus == GoalStatus.completed ? 10 : 5,
              metadata: {'originalStatus': goal.status.toString()},
            ))
        .toList();

    return await _processor.processBatch(items);
  }

  /// 处理单个目标操作项
  static Future<Goal> _processGoalItem(BatchOperationItem<Goal> item) async {
    // 这里需要注入依赖，简化实现
    throw UnimplementedError('需要在实际使用时注入DatabaseHelper和GoalBloc');
  }

  /// 获取目标层级
  int _getGoalLevel(Goal goal) {
    int level = 0;
    Goal? current = goal;

    while (current?.parentId != null) {
      level++;
      // 在实际实现中，需要查询父目标
      // current = await databaseHelper.getGoal(current.parentId!);
      break; // 简化实现
    }

    return level;
  }
}

/// 批量操作优化器
class BatchOptimizer {
  /// 优化批量操作序列
  static List<BatchOperationItem<T>> optimizeOperations<T>(
    List<BatchOperationItem<T>> items,
  ) {
    // 1. 移除冗余操作
    final deduplicated = _removeDuplicates(items);

    // 2. 合并相关操作
    final merged = _mergeRelatedOperations(deduplicated);

    // 3. 重新排序
    final reordered = _reorderOperations(merged);

    return reordered;
  }

  /// 移除重复操作
  static List<BatchOperationItem<T>> _removeDuplicates<T>(
    List<BatchOperationItem<T>> items,
  ) {
    final seen = <String, BatchOperationItem<T>>{};

    for (final item in items) {
      final key = '${item.type}_${item.id}';

      if (!seen.containsKey(key) || item.priority > seen[key]!.priority) {
        seen[key] = item;
      }
    }

    return seen.values.toList();
  }

  /// 合并相关操作
  static List<BatchOperationItem<T>> _mergeRelatedOperations<T>(
    List<BatchOperationItem<T>> items,
  ) {
    // 简化实现：直接返回原列表
    // 在实际应用中，可以根据业务逻辑合并相关操作
    return items;
  }

  /// 重新排序操作
  static List<BatchOperationItem<T>> _reorderOperations<T>(
    List<BatchOperationItem<T>> items,
  ) {
    final sorted = List<BatchOperationItem<T>>.from(items);

    // 按类型和优先级排序
    sorted.sort((a, b) {
      // 首先按操作类型排序：delete > update > create
      final typeOrder = {
        BatchOperationType.delete: 3,
        BatchOperationType.update: 2,
        BatchOperationType.create: 1,
        BatchOperationType.mixed: 0,
      };

      final aTypeOrder = typeOrder[a.type] ?? 0;
      final bTypeOrder = typeOrder[b.type] ?? 0;

      if (aTypeOrder != bTypeOrder) {
        return bTypeOrder.compareTo(aTypeOrder);
      }

      // 然后按优先级排序
      return b.priority.compareTo(a.priority);
    });

    return sorted;
  }

  /// 分析批量操作的复杂度
  static BatchComplexityAnalysis analyzeComplexity<T>(
    List<BatchOperationItem<T>> items,
  ) {
    final typeCount = <BatchOperationType, int>{};
    final priorityDistribution = <int, int>{};
    int totalPriority = 0;

    for (final item in items) {
      typeCount[item.type] = (typeCount[item.type] ?? 0) + 1;
      priorityDistribution[item.priority] =
          (priorityDistribution[item.priority] ?? 0) + 1;
      totalPriority += item.priority;
    }

    final avgPriority = items.isEmpty ? 0.0 : totalPriority / items.length;
    final complexity =
        _calculateComplexity(items.length, typeCount.length, avgPriority);

    return BatchComplexityAnalysis(
      totalItems: items.length,
      typeCount: typeCount,
      priorityDistribution: priorityDistribution,
      averagePriority: avgPriority,
      complexity: complexity,
    );
  }

  /// 计算复杂度分数
  static double _calculateComplexity(
      int itemCount, int typeCount, double avgPriority) {
    double complexity = 0.0;

    // 项目数量影响
    complexity += itemCount * 0.1;

    // 类型多样性影响
    complexity += typeCount * 2.0;

    // 平均优先级影响
    complexity += avgPriority * 0.5;

    return complexity;
  }
}

/// 批量复杂度分析结果
class BatchComplexityAnalysis {
  final int totalItems;
  final Map<BatchOperationType, int> typeCount;
  final Map<int, int> priorityDistribution;
  final double averagePriority;
  final double complexity;

  const BatchComplexityAnalysis({
    required this.totalItems,
    required this.typeCount,
    required this.priorityDistribution,
    required this.averagePriority,
    required this.complexity,
  });

  /// 获取复杂度级别
  String get complexityLevel {
    if (complexity < 10) return 'Low';
    if (complexity < 50) return 'Medium';
    if (complexity < 100) return 'High';
    return 'Very High';
  }

  /// 获取推荐的处理策略
  BatchProcessingStrategy get recommendedStrategy {
    if (complexity < 10) return BatchProcessingStrategy.sequential;
    if (complexity < 30) return BatchProcessingStrategy.chunked;
    if (averagePriority > 7) return BatchProcessingStrategy.prioritized;
    return BatchProcessingStrategy.parallel;
  }
}
