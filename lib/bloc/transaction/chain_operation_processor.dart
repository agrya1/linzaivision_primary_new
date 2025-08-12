/// 连锁操作处理器
/// 
/// 处理复杂的连锁操作，如目标删除的连锁效应、状态变更的级联更新等
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'transaction_manager.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart';

/// 连锁操作类型
enum ChainOperationType {
  goalDeletion,       // 目标删除连锁
  statusChange,       // 状态变更连锁
  parentUpdate,       // 父目标更新连锁
  childUpdate,        // 子目标更新连锁
  hierarchyReorder,   // 层级重排连锁
}

/// 连锁操作配置
class ChainOperationConfig {
  final bool enableCascadeDelete;     // 启用级联删除
  final bool enableStatusPropagation; // 启用状态传播
  final bool enableHierarchyUpdate;   // 启用层级更新
  final int maxChainDepth;            // 最大连锁深度
  final Duration operationTimeout;    // 操作超时时间
  final bool enableRollback;          // 启用回滚
  
  const ChainOperationConfig({
    this.enableCascadeDelete = true,
    this.enableStatusPropagation = true,
    this.enableHierarchyUpdate = true,
    this.maxChainDepth = 10,
    this.operationTimeout = const Duration(seconds: 30),
    this.enableRollback = true,
  });
}

/// 连锁操作步骤
class ChainOperationStep {
  final String id;
  final String description;
  final ChainOperationType type;
  final Goal targetGoal;
  final Map<String, dynamic> parameters;
  final List<String> dependencies;
  
  const ChainOperationStep({
    required this.id,
    required this.description,
    required this.type,
    required this.targetGoal,
    this.parameters = const {},
    this.dependencies = const [],
  });
}

/// 连锁操作结果
class ChainOperationResult {
  final bool success;
  final List<ChainOperationStep> executedSteps;
  final List<ChainOperationStep> failedSteps;
  final Duration totalDuration;
  final String? error;
  final Map<String, dynamic> metadata;
  
  const ChainOperationResult({
    required this.success,
    required this.executedSteps,
    required this.failedSteps,
    required this.totalDuration,
    this.error,
    this.metadata = const {},
  });
  
  int get totalSteps => executedSteps.length + failedSteps.length;
  double get successRate => totalSteps == 0 ? 0.0 : executedSteps.length / totalSteps;
}

/// 连锁操作处理器
class ChainOperationProcessor {
  final ChainOperationConfig config;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  final TransactionManager transactionManager;
  
  // 操作历史记录
  final List<ChainOperationResult> _operationHistory = [];
  
  ChainOperationProcessor({
    required this.databaseHelper,
    required this.goalBloc,
    required this.transactionManager,
    this.config = const ChainOperationConfig(),
  });
  
  /// 处理目标删除连锁操作
  Future<ChainOperationResult> processGoalDeletionChain(Goal goal) async {
    final stopwatch = Stopwatch()..start();
    final executedSteps = <ChainOperationStep>[];
    final failedSteps = <ChainOperationStep>[];
    
    try {
      // 1. 分析删除连锁影响
      final chainSteps = await _analyzeGoalDeletionChain(goal);
      
      // 2. 按依赖关系排序
      final sortedSteps = _sortStepsByDependencies(chainSteps);
      
      // 3. 执行连锁操作
      for (final step in sortedSteps) {
        try {
          await _executeChainStep(step);
          executedSteps.add(step);
        } catch (e) {
          failedSteps.add(step);
          
          // 如果启用回滚，回滚已执行的步骤
          if (config.enableRollback) {
            await _rollbackExecutedSteps(executedSteps);
          }
          
          stopwatch.stop();
          final result = ChainOperationResult(
            success: false,
            executedSteps: executedSteps,
            failedSteps: failedSteps,
            totalDuration: stopwatch.elapsed,
            error: 'Chain operation failed at step ${step.id}: $e',
          );
          
          _operationHistory.add(result);
          return result;
        }
      }
      
      stopwatch.stop();
      final result = ChainOperationResult(
        success: true,
        executedSteps: executedSteps,
        failedSteps: failedSteps,
        totalDuration: stopwatch.elapsed,
        metadata: {
          'deletedGoalId': goal.id,
          'affectedGoalsCount': executedSteps.length,
        },
      );
      
      _operationHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      final result = ChainOperationResult(
        success: false,
        executedSteps: executedSteps,
        failedSteps: failedSteps,
        totalDuration: stopwatch.elapsed,
        error: e.toString(),
      );
      
      _operationHistory.add(result);
      return result;
    }
  }
  
  /// 处理状态变更连锁操作
  Future<ChainOperationResult> processStatusChangeChain(
    Goal goal, 
    GoalStatus newStatus,
  ) async {
    final stopwatch = Stopwatch()..start();
    final executedSteps = <ChainOperationStep>[];
    final failedSteps = <ChainOperationStep>[];
    
    try {
      // 1. 分析状态变更连锁影响
      final chainSteps = await _analyzeStatusChangeChain(goal, newStatus);
      
      // 2. 按依赖关系排序
      final sortedSteps = _sortStepsByDependencies(chainSteps);
      
      // 3. 执行连锁操作
      for (final step in sortedSteps) {
        try {
          await _executeChainStep(step);
          executedSteps.add(step);
        } catch (e) {
          failedSteps.add(step);
          
          if (config.enableRollback) {
            await _rollbackExecutedSteps(executedSteps);
          }
          
          stopwatch.stop();
          final result = ChainOperationResult(
            success: false,
            executedSteps: executedSteps,
            failedSteps: failedSteps,
            totalDuration: stopwatch.elapsed,
            error: 'Status change chain failed at step ${step.id}: $e',
          );
          
          _operationHistory.add(result);
          return result;
        }
      }
      
      stopwatch.stop();
      final result = ChainOperationResult(
        success: true,
        executedSteps: executedSteps,
        failedSteps: failedSteps,
        totalDuration: stopwatch.elapsed,
        metadata: {
          'goalId': goal.id,
          'oldStatus': goal.status.toString(),
          'newStatus': newStatus.toString(),
          'affectedGoalsCount': executedSteps.length,
        },
      );
      
      _operationHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      final result = ChainOperationResult(
        success: false,
        executedSteps: executedSteps,
        failedSteps: failedSteps,
        totalDuration: stopwatch.elapsed,
        error: e.toString(),
      );
      
      _operationHistory.add(result);
      return result;
    }
  }
  
  /// 分析目标删除连锁影响
  Future<List<ChainOperationStep>> _analyzeGoalDeletionChain(Goal goal) async {
    final steps = <ChainOperationStep>[];
    
    // 1. 删除所有子目标
    if (goal.subGoals.isNotEmpty) {
      for (int i = 0; i < goal.subGoals.length; i++) {
        final subGoal = goal.subGoals[i];
        steps.add(ChainOperationStep(
          id: 'delete_subgoal_${subGoal.id}',
          description: '删除子目标: ${subGoal.title}',
          type: ChainOperationType.goalDeletion,
          targetGoal: subGoal,
          dependencies: i > 0 ? ['delete_subgoal_${goal.subGoals[i-1].id}'] : [],
        ));
      }
    }
    
    // 2. 从父目标中移除引用
    if (goal.parentId != null) {
      final parentGoal = await databaseHelper.getGoal(goal.parentId!);
      if (parentGoal != null) {
        steps.add(ChainOperationStep(
          id: 'update_parent_${goal.parentId}',
          description: '更新父目标: ${parentGoal.title}',
          type: ChainOperationType.parentUpdate,
          targetGoal: parentGoal,
          parameters: {'removedChildId': goal.id},
          dependencies: goal.subGoals.isNotEmpty 
              ? ['delete_subgoal_${goal.subGoals.last.id}']
              : [],
        ));
      }
    }
    
    // 3. 删除目标本身
    steps.add(ChainOperationStep(
      id: 'delete_goal_${goal.id}',
      description: '删除目标: ${goal.title}',
      type: ChainOperationType.goalDeletion,
      targetGoal: goal,
      dependencies: [
        if (goal.subGoals.isNotEmpty) 'delete_subgoal_${goal.subGoals.last.id}',
        if (goal.parentId != null) 'update_parent_${goal.parentId}',
      ],
    ));
    
    return steps;
  }
  
  /// 分析状态变更连锁影响
  Future<List<ChainOperationStep>> _analyzeStatusChangeChain(
    Goal goal, 
    GoalStatus newStatus,
  ) async {
    final steps = <ChainOperationStep>[];
    
    // 1. 更新目标状态
    steps.add(ChainOperationStep(
      id: 'update_status_${goal.id}',
      description: '更新目标状态: ${goal.title}',
      type: ChainOperationType.statusChange,
      targetGoal: goal,
      parameters: {'newStatus': newStatus},
    ));
    
    // 2. 如果启用状态传播，更新子目标状态
    if (config.enableStatusPropagation && goal.subGoals.isNotEmpty) {
      for (final subGoal in goal.subGoals) {
        // 根据业务逻辑决定是否需要更新子目标状态
        if (_shouldPropagateStatus(goal.status, newStatus, subGoal.status)) {
          steps.add(ChainOperationStep(
            id: 'propagate_status_${subGoal.id}',
            description: '传播状态到子目标: ${subGoal.title}',
            type: ChainOperationType.statusChange,
            targetGoal: subGoal,
            parameters: {'newStatus': newStatus},
            dependencies: ['update_status_${goal.id}'],
          ));
        }
      }
    }
    
    // 3. 更新父目标状态（如果所有子目标都完成）
    if (goal.parentId != null && newStatus == GoalStatus.completed) {
      final parentGoal = await databaseHelper.getGoal(goal.parentId!);
      if (parentGoal != null) {
        steps.add(ChainOperationStep(
          id: 'check_parent_completion_${goal.parentId}',
          description: '检查父目标完成状态: ${parentGoal.title}',
          type: ChainOperationType.parentUpdate,
          targetGoal: parentGoal,
          parameters: {'checkCompletion': true},
          dependencies: ['update_status_${goal.id}'],
        ));
      }
    }
    
    return steps;
  }
  
  /// 按依赖关系排序步骤
  List<ChainOperationStep> _sortStepsByDependencies(List<ChainOperationStep> steps) {
    final sorted = <ChainOperationStep>[];
    final remaining = List<ChainOperationStep>.from(steps);
    final completed = <String>{};
    
    while (remaining.isNotEmpty) {
      bool found = false;
      
      for (int i = 0; i < remaining.length; i++) {
        final step = remaining[i];
        final canExecute = step.dependencies.every((dep) => completed.contains(dep));
        
        if (canExecute) {
          sorted.add(step);
          completed.add(step.id);
          remaining.removeAt(i);
          found = true;
          break;
        }
      }
      
      if (!found) {
        throw Exception('Circular dependency detected in chain operations');
      }
    }
    
    return sorted;
  }
  
  /// 执行连锁操作步骤
  Future<void> _executeChainStep(ChainOperationStep step) async {
    switch (step.type) {
      case ChainOperationType.goalDeletion:
        await _executeGoalDeletion(step);
        break;
      case ChainOperationType.statusChange:
        await _executeStatusChange(step);
        break;
      case ChainOperationType.parentUpdate:
        await _executeParentUpdate(step);
        break;
      case ChainOperationType.childUpdate:
        await _executeChildUpdate(step);
        break;
      case ChainOperationType.hierarchyReorder:
        await _executeHierarchyReorder(step);
        break;
    }
  }
  
  /// 执行目标删除
  Future<void> _executeGoalDeletion(ChainOperationStep step) async {
    await databaseHelper.deleteGoal(step.targetGoal.id!);
    goalBloc.add(DeleteGoal(step.targetGoal.id!));
  }
  
  /// 执行状态变更
  Future<void> _executeStatusChange(ChainOperationStep step) async {
    final newStatus = step.parameters['newStatus'] as GoalStatus;
    final updatedGoal = step.targetGoal.copyWith(status: newStatus);
    
    await databaseHelper.updateGoal(updatedGoal);
    goalBloc.add(UpdateGoal(updatedGoal));
  }
  
  /// 执行父目标更新
  Future<void> _executeParentUpdate(ChainOperationStep step) async {
    if (step.parameters.containsKey('removedChildId')) {
      // 从父目标中移除子目标引用
      final removedChildId = step.parameters['removedChildId'] as int;
      final updatedSubGoals = step.targetGoal.subGoals
          .where((sg) => sg.id != removedChildId)
          .toList();
      
      final updatedParent = step.targetGoal.copyWith(subGoals: updatedSubGoals);
      await databaseHelper.updateGoal(updatedParent);
      goalBloc.add(UpdateGoal(updatedParent));
      
    } else if (step.parameters.containsKey('checkCompletion')) {
      // 检查是否所有子目标都已完成
      final allSubGoalsCompleted = step.targetGoal.subGoals
          .every((sg) => sg.status == GoalStatus.completed);
      
      if (allSubGoalsCompleted && step.targetGoal.status != GoalStatus.completed) {
        final updatedParent = step.targetGoal.copyWith(status: GoalStatus.completed);
        await databaseHelper.updateGoal(updatedParent);
        goalBloc.add(UpdateGoal(updatedParent));
      }
    }
  }
  
  /// 执行子目标更新
  Future<void> _executeChildUpdate(ChainOperationStep step) async {
    // 实现子目标更新逻辑
    await databaseHelper.updateGoal(step.targetGoal);
    goalBloc.add(UpdateGoal(step.targetGoal));
  }
  
  /// 执行层级重排
  Future<void> _executeHierarchyReorder(ChainOperationStep step) async {
    // 实现层级重排逻辑
    await databaseHelper.updateGoal(step.targetGoal);
    goalBloc.add(UpdateGoal(step.targetGoal));
  }
  
  /// 回滚已执行的步骤
  Future<void> _rollbackExecutedSteps(List<ChainOperationStep> executedSteps) async {
    // 按相反顺序回滚
    for (final step in executedSteps.reversed) {
      try {
        await _rollbackChainStep(step);
      } catch (e) {
        debugPrint('Failed to rollback step ${step.id}: $e');
      }
    }
  }
  
  /// 回滚单个步骤
  Future<void> _rollbackChainStep(ChainOperationStep step) async {
    switch (step.type) {
      case ChainOperationType.goalDeletion:
        // 恢复已删除的目标
        await databaseHelper.insertGoal(step.targetGoal);
        goalBloc.add(AddGoal(step.targetGoal));
        break;
      case ChainOperationType.statusChange:
        // 恢复原始状态
        await databaseHelper.updateGoal(step.targetGoal);
        goalBloc.add(UpdateGoal(step.targetGoal));
        break;
      case ChainOperationType.parentUpdate:
      case ChainOperationType.childUpdate:
      case ChainOperationType.hierarchyReorder:
        // 恢复原始目标状态
        await databaseHelper.updateGoal(step.targetGoal);
        goalBloc.add(UpdateGoal(step.targetGoal));
        break;
    }
  }
  
  /// 判断是否应该传播状态
  bool _shouldPropagateStatus(GoalStatus oldStatus, GoalStatus newStatus, GoalStatus childStatus) {
    // 简化的状态传播逻辑
    // 实际应用中可以根据业务需求定制
    if (newStatus == GoalStatus.completed && childStatus == GoalStatus.pending) {
      return true;
    }
    return false;
  }
  
  /// 获取操作历史
  List<ChainOperationResult> getOperationHistory() {
    return List.unmodifiable(_operationHistory);
  }
  
  /// 清理操作历史
  void clearOperationHistory() {
    _operationHistory.clear();
  }
  
  /// 获取统计信息
  ChainOperationStats getStats() {
    if (_operationHistory.isEmpty) {
      return const ChainOperationStats(
        totalOperations: 0,
        successfulOperations: 0,
        failedOperations: 0,
        averageSteps: 0.0,
        averageDuration: Duration.zero,
        successRate: 0.0,
      );
    }
    
    final successful = _operationHistory.where((r) => r.success).length;
    final failed = _operationHistory.length - successful;
    final totalSteps = _operationHistory.fold(0, (sum, r) => sum + r.totalSteps);
    final totalDuration = _operationHistory.fold(Duration.zero, (sum, r) => sum + r.totalDuration);
    
    return ChainOperationStats(
      totalOperations: _operationHistory.length,
      successfulOperations: successful,
      failedOperations: failed,
      averageSteps: totalSteps / _operationHistory.length,
      averageDuration: Duration(milliseconds: 
          (totalDuration.inMilliseconds / _operationHistory.length).round()),
      successRate: successful / _operationHistory.length,
    );
  }
}

/// 连锁操作统计
class ChainOperationStats {
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final double averageSteps;
  final Duration averageDuration;
  final double successRate;
  
  const ChainOperationStats({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.averageSteps,
    required this.averageDuration,
    required this.successRate,
  });
}
