/// 批量处理集成模块
///
/// 将批量处理功能集成到现有的BLoC架构中，提供统一的批量操作接口
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'batch_processor.dart';
import 'transaction_manager.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart';

/// 批量操作集成器
class BatchOperationIntegrator {
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  final TransactionManager transactionManager;
  final BatchProcessor<Goal> _goalProcessor;

  BatchOperationIntegrator({
    required this.databaseHelper,
    required this.goalBloc,
    required this.transactionManager,
    BatchProcessingConfig? config,
  }) : _goalProcessor = BatchProcessor<Goal>(
          processor: (item) =>
              _processGoalOperation(item, databaseHelper, goalBloc),
          config: config ?? const BatchProcessingConfig(),
        );

  /// 批量创建目标
  Future<BatchProcessingResult<Goal>> batchCreateGoals(List<Goal> goals) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'create_${goal.title}_${DateTime.now().millisecondsSinceEpoch}',
              data: goal,
              type: BatchOperationType.create,
              priority: goal.parentId == null ? 10 : 5,
            ))
        .toList();

    return await _goalProcessor.processBatch(items);
  }

  /// 批量更新目标
  Future<BatchProcessingResult<Goal>> batchUpdateGoals(List<Goal> goals) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'update_${goal.id}',
              data: goal,
              type: BatchOperationType.update,
              priority: goal.status == GoalStatus.completed ? 8 : 5,
            ))
        .toList();

    return await _goalProcessor.processBatch(items);
  }

  /// 批量删除目标
  Future<BatchProcessingResult<Goal>> batchDeleteGoals(List<Goal> goals) async {
    // 按层级排序，深层级的先删除
    final sortedGoals = List<Goal>.from(goals);
    sortedGoals.sort((a, b) {
      final aLevel = _calculateGoalLevel(a);
      final bLevel = _calculateGoalLevel(b);
      return bLevel.compareTo(aLevel);
    });

    final items = sortedGoals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'delete_${goal.id}',
              data: goal,
              type: BatchOperationType.delete,
              priority: _calculateGoalLevel(goal),
            ))
        .toList();

    return await _goalProcessor.processBatch(items);
  }

  /// 批量状态变更
  Future<BatchProcessingResult<Goal>> batchChangeStatus(
    List<Goal> goals,
    GoalStatus newStatus,
  ) async {
    final items = goals
        .map((goal) => BatchOperationItem<Goal>(
              id: 'status_${goal.id}',
              data: goal.copyWith(status: newStatus),
              type: BatchOperationType.update,
              priority: newStatus == GoalStatus.completed ? 10 : 5,
              metadata: {'originalStatus': goal.status.toString()},
            ))
        .toList();

    return await _goalProcessor.processBatch(items);
  }

  /// 智能批量操作
  /// 根据操作类型和复杂度自动选择最优策略
  Future<BatchProcessingResult<Goal>> smartBatchOperation(
    List<BatchOperationItem<Goal>> items,
  ) async {
    // 1. 分析复杂度
    final analysis = BatchOptimizer.analyzeComplexity(items);

    // 2. 优化操作序列
    final optimizedItems = BatchOptimizer.optimizeOperations(items);

    // 3. 选择合适的配置
    final config = _selectOptimalConfig(analysis);

    // 4. 创建专用处理器
    final processor = BatchProcessor<Goal>(
      processor: (item) =>
          _processGoalOperation(item, databaseHelper, goalBloc),
      config: config,
    );

    // 5. 执行批量处理
    return await processor.processBatch(optimizedItems);
  }

  /// 事务化批量操作
  /// 将批量操作包装在事务中，确保原子性
  Future<TransactionResult> transactionalBatchOperation(
      List<BatchOperationItem<Goal>> items,
      {String? description}) async {
    // 创建批量操作事务
    final operations =
        items.map((item) => _createTransactionOperation(item)).toList();

    final transaction = transactionManager.createTransaction(
      description: description ?? '批量目标操作',
      operations: operations,
      priority: TransactionPriority.normal,
      metadata: {
        'batchSize': items.length,
        'operationTypes': items.map((i) => i.type.toString()).toSet().toList(),
      },
    );

    return await transactionManager.commitTransaction(transaction.id);
  }

  /// 计算目标层级
  int _calculateGoalLevel(Goal goal) {
    int level = 0;

    // 简化实现：通过parentId判断层级
    if (goal.parentId != null) {
      level++;
      // 在实际实现中需要递归查询父目标
    }

    return level;
  }

  /// 选择最优配置
  BatchProcessingConfig _selectOptimalConfig(BatchComplexityAnalysis analysis) {
    if (analysis.complexity < 10) {
      return const BatchProcessingConfig(
        maxBatchSize: 50,
        maxConcurrency: 2,
        strategy: BatchProcessingStrategy.sequential,
      );
    } else if (analysis.complexity < 50) {
      return const BatchProcessingConfig(
        maxBatchSize: 100,
        maxConcurrency: 4,
        strategy: BatchProcessingStrategy.chunked,
      );
    } else {
      return BatchProcessingConfig.highPerformance();
    }
  }

  /// 创建事务操作
  TransactionOperation _createTransactionOperation(
      BatchOperationItem<Goal> item) {
    switch (item.type) {
      case BatchOperationType.create:
        return _CreateGoalOperation(item.data, databaseHelper, goalBloc);
      case BatchOperationType.update:
        return _UpdateGoalOperation(item.data, databaseHelper, goalBloc);
      case BatchOperationType.delete:
        return _DeleteGoalOperation(item.data, databaseHelper, goalBloc);
      case BatchOperationType.mixed:
        throw ArgumentError('Mixed operations not supported in transactions');
    }
  }

  /// 处理目标操作
  static Future<Goal> _processGoalOperation(
    BatchOperationItem<Goal> item,
    DatabaseHelper databaseHelper,
    GoalBloc goalBloc,
  ) async {
    switch (item.type) {
      case BatchOperationType.create:
        await databaseHelper.insertGoal(item.data);
        goalBloc.add(AddGoal(item.data));
        return item.data;

      case BatchOperationType.update:
        await databaseHelper.updateGoal(item.data);
        goalBloc.add(UpdateGoal(item.data));
        return item.data;

      case BatchOperationType.delete:
        await databaseHelper.deleteGoal(item.data.id!);
        goalBloc.add(DeleteGoal(item.data.id!));
        return item.data;

      case BatchOperationType.mixed:
        throw ArgumentError('Mixed operations not supported');
    }
  }
}

/// 创建目标事务操作
class _CreateGoalOperation extends TransactionOperation {
  final Goal goal;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;

  _CreateGoalOperation(this.goal, this.databaseHelper, this.goalBloc)
      : super(
          id: 'create_goal_${goal.title}',
          description: '创建目标: ${goal.title}',
        );

  @override
  Future<TransactionOperationResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      await databaseHelper.insertGoal(goal);
      goalBloc.add(AddGoal(goal));

      stopwatch.stop();
      return TransactionOperationResult.success(
        data: {'goalId': goal.id},
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TransactionOperationResult.failure(
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (goal.id != null) {
      await databaseHelper.deleteGoal(goal.id!);
      goalBloc.add(DeleteGoal(goal.id!));
    }
  }

  @override
  Future<bool> validate() async {
    return goal.title.isNotEmpty;
  }

  @override
  Set<String> getAffectedResources() {
    return {'goal_create', if (goal.parentId != null) 'goal_${goal.parentId}'};
  }
}

/// 更新目标事务操作
class _UpdateGoalOperation extends TransactionOperation {
  final Goal goal;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  Goal? _originalGoal;

  _UpdateGoalOperation(this.goal, this.databaseHelper, this.goalBloc)
      : super(
          id: 'update_goal_${goal.id}',
          description: '更新目标: ${goal.title}',
        );

  @override
  Future<TransactionOperationResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 备份原始目标
      _originalGoal = await databaseHelper.getGoal(goal.id!);

      await databaseHelper.updateGoal(goal);
      goalBloc.add(UpdateGoal(goal));

      stopwatch.stop();
      return TransactionOperationResult.success(
        data: {'goalId': goal.id},
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TransactionOperationResult.failure(
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (_originalGoal != null) {
      await databaseHelper.updateGoal(_originalGoal!);
      goalBloc.add(UpdateGoal(_originalGoal!));
    }
  }

  @override
  Future<bool> validate() async {
    final existingGoal = await databaseHelper.getGoal(goal.id!);
    return existingGoal != null;
  }

  @override
  Set<String> getAffectedResources() {
    return {'goal_${goal.id}'};
  }
}

/// 删除目标事务操作
class _DeleteGoalOperation extends TransactionOperation {
  final Goal goal;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;

  _DeleteGoalOperation(this.goal, this.databaseHelper, this.goalBloc)
      : super(
          id: 'delete_goal_${goal.id}',
          description: '删除目标: ${goal.title}',
        );

  @override
  Future<TransactionOperationResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      await databaseHelper.deleteGoal(goal.id!);
      goalBloc.add(DeleteGoal(goal.id!));

      stopwatch.stop();
      return TransactionOperationResult.success(
        data: {'goalId': goal.id},
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TransactionOperationResult.failure(
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> rollback() async {
    await databaseHelper.insertGoal(goal);
    goalBloc.add(AddGoal(goal));
  }

  @override
  Future<bool> validate() async {
    final existingGoal = await databaseHelper.getGoal(goal.id!);
    return existingGoal != null;
  }

  @override
  Set<String> getAffectedResources() {
    return {'goal_${goal.id}'};
  }
}

/// 批量操作统计
class BatchOperationStats {
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final Duration totalDuration;
  final double averageDuration;
  final double successRate;
  final Map<BatchOperationType, int> operationTypeCount;

  BatchOperationStats({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.totalDuration,
    required this.averageDuration,
    required this.successRate,
    required this.operationTypeCount,
  });

  factory BatchOperationStats.fromResult(BatchProcessingResult result) {
    final operationTypeCount = <BatchOperationType, int>{};

    // 这里需要从结果中提取操作类型信息
    // 简化实现

    return BatchOperationStats(
      totalOperations: result.results.length,
      successfulOperations: result.successCount,
      failedOperations: result.failureCount,
      totalDuration: result.totalDuration,
      averageDuration: result.results.isEmpty
          ? 0.0
          : result.results
                  .fold(0.0, (sum, r) => sum + r.duration.inMilliseconds) /
              result.results.length,
      successRate: result.successRate,
      operationTypeCount: operationTypeCount,
    );
  }
}
