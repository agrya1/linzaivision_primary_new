/// 操作回滚管理器
/// 
/// 实现复杂操作失败时的回滚机制，确保数据一致性和用户体验
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart';

/// 回滚操作类型
enum RollbackOperationType {
  goalCreation,       // 目标创建回滚
  goalUpdate,         // 目标更新回滚
  goalDeletion,       // 目标删除回滚
  statusChange,       // 状态变更回滚
  hierarchyChange,    // 层级变更回滚
  bulkOperation,      // 批量操作回滚
}

/// 回滚策略
enum RollbackStrategy {
  immediate,          // 立即回滚
  delayed,            // 延迟回滚
  manual,             // 手动回滚
  automatic,          // 自动回滚
  conditional,        // 条件回滚
}

/// 回滚点
class RollbackPoint {
  final String id;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> snapshot;
  final RollbackOperationType operationType;
  final List<String> affectedGoalIds;
  final Map<String, dynamic> metadata;
  
  const RollbackPoint({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.snapshot,
    required this.operationType,
    required this.affectedGoalIds,
    this.metadata = const {},
  });
  
  /// 创建目标创建回滚点
  factory RollbackPoint.goalCreation(Goal goal) {
    return RollbackPoint(
      id: 'rollback_create_${goal.id}_${DateTime.now().millisecondsSinceEpoch}',
      description: '目标创建回滚点: ${goal.title}',
      timestamp: DateTime.now(),
      snapshot: {'goal': goal.toJson()},
      operationType: RollbackOperationType.goalCreation,
      affectedGoalIds: [goal.id.toString()],
    );
  }
  
  /// 创建目标更新回滚点
  factory RollbackPoint.goalUpdate(Goal originalGoal, Goal updatedGoal) {
    return RollbackPoint(
      id: 'rollback_update_${originalGoal.id}_${DateTime.now().millisecondsSinceEpoch}',
      description: '目标更新回滚点: ${originalGoal.title}',
      timestamp: DateTime.now(),
      snapshot: {
        'originalGoal': originalGoal.toJson(),
        'updatedGoal': updatedGoal.toJson(),
      },
      operationType: RollbackOperationType.goalUpdate,
      affectedGoalIds: [originalGoal.id.toString()],
    );
  }
  
  /// 创建目标删除回滚点
  factory RollbackPoint.goalDeletion(Goal goal, List<Goal> subGoals) {
    return RollbackPoint(
      id: 'rollback_delete_${goal.id}_${DateTime.now().millisecondsSinceEpoch}',
      description: '目标删除回滚点: ${goal.title}',
      timestamp: DateTime.now(),
      snapshot: {
        'goal': goal.toJson(),
        'subGoals': subGoals.map((g) => g.toJson()).toList(),
      },
      operationType: RollbackOperationType.goalDeletion,
      affectedGoalIds: [goal.id.toString(), ...subGoals.map((g) => g.id.toString())],
    );
  }
  
  /// 创建批量操作回滚点
  factory RollbackPoint.bulkOperation(List<Goal> goals, String description) {
    return RollbackPoint(
      id: 'rollback_bulk_${DateTime.now().millisecondsSinceEpoch}',
      description: '批量操作回滚点: $description',
      timestamp: DateTime.now(),
      snapshot: {
        'goals': goals.map((g) => g.toJson()).toList(),
      },
      operationType: RollbackOperationType.bulkOperation,
      affectedGoalIds: goals.map((g) => g.id.toString()).toList(),
    );
  }
}

/// 回滚操作结果
class RollbackResult {
  final bool success;
  final String rollbackPointId;
  final Duration executionTime;
  final List<String> restoredGoalIds;
  final String? error;
  final Map<String, dynamic> metadata;
  
  const RollbackResult({
    required this.success,
    required this.rollbackPointId,
    required this.executionTime,
    required this.restoredGoalIds,
    this.error,
    this.metadata = const {},
  });
  
  factory RollbackResult.success(
    String rollbackPointId,
    Duration executionTime,
    List<String> restoredGoalIds,
  ) {
    return RollbackResult(
      success: true,
      rollbackPointId: rollbackPointId,
      executionTime: executionTime,
      restoredGoalIds: restoredGoalIds,
    );
  }
  
  factory RollbackResult.failure(
    String rollbackPointId,
    Duration executionTime,
    String error,
  ) {
    return RollbackResult(
      success: false,
      rollbackPointId: rollbackPointId,
      executionTime: executionTime,
      restoredGoalIds: [],
      error: error,
    );
  }
}

/// 回滚配置
class RollbackConfig {
  final RollbackStrategy strategy;
  final Duration autoRollbackDelay;
  final int maxRollbackPoints;
  final Duration rollbackPointExpiry;
  final bool enableAutoCleanup;
  final bool enableRollbackChain;
  final Duration operationTimeout;
  
  const RollbackConfig({
    this.strategy = RollbackStrategy.automatic,
    this.autoRollbackDelay = const Duration(seconds: 5),
    this.maxRollbackPoints = 100,
    this.rollbackPointExpiry = const Duration(hours: 24),
    this.enableAutoCleanup = true,
    this.enableRollbackChain = true,
    this.operationTimeout = const Duration(seconds: 30),
  });
}

/// 回滚管理器
class RollbackManager {
  final RollbackConfig config;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  
  // 回滚点存储
  final Queue<RollbackPoint> _rollbackPoints = Queue<RollbackPoint>();
  final Map<String, RollbackPoint> _rollbackPointsMap = {};
  
  // 回滚历史
  final List<RollbackResult> _rollbackHistory = [];
  
  // 自动回滚定时器
  final Map<String, Timer> _autoRollbackTimers = {};
  
  // 统计信息
  int _totalRollbacks = 0;
  int _successfulRollbacks = 0;
  int _failedRollbacks = 0;
  
  RollbackManager({
    required this.databaseHelper,
    required this.goalBloc,
    this.config = const RollbackConfig(),
  }) {
    _startCleanupTimer();
  }
  
  /// 创建回滚点
  String createRollbackPoint(RollbackPoint rollbackPoint) {
    // 检查容量限制
    if (_rollbackPoints.length >= config.maxRollbackPoints) {
      _removeOldestRollbackPoint();
    }
    
    // 添加回滚点
    _rollbackPoints.add(rollbackPoint);
    _rollbackPointsMap[rollbackPoint.id] = rollbackPoint;
    
    // 设置自动回滚（如果启用）
    if (config.strategy == RollbackStrategy.automatic) {
      _scheduleAutoRollback(rollbackPoint);
    }
    
    debugPrint('Created rollback point: ${rollbackPoint.id}');
    return rollbackPoint.id;
  }
  
  /// 执行回滚
  Future<RollbackResult> executeRollback(String rollbackPointId) async {
    final stopwatch = Stopwatch()..start();
    _totalRollbacks++;
    
    try {
      final rollbackPoint = _rollbackPointsMap[rollbackPointId];
      if (rollbackPoint == null) {
        throw Exception('Rollback point not found: $rollbackPointId');
      }
      
      // 取消自动回滚定时器
      _cancelAutoRollback(rollbackPointId);
      
      // 执行回滚操作
      final restoredGoalIds = await _performRollback(rollbackPoint);
      
      // 移除回滚点
      _removeRollbackPoint(rollbackPointId);
      
      stopwatch.stop();
      _successfulRollbacks++;
      
      final result = RollbackResult.success(
        rollbackPointId,
        stopwatch.elapsed,
        restoredGoalIds,
      );
      
      _rollbackHistory.add(result);
      debugPrint('Rollback successful: $rollbackPointId');
      
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _failedRollbacks++;
      
      final result = RollbackResult.failure(
        rollbackPointId,
        stopwatch.elapsed,
        e.toString(),
      );
      
      _rollbackHistory.add(result);
      debugPrint('Rollback failed: $rollbackPointId - $e');
      
      return result;
    }
  }
  
  /// 执行具体的回滚操作
  Future<List<String>> _performRollback(RollbackPoint rollbackPoint) async {
    final restoredGoalIds = <String>[];
    
    switch (rollbackPoint.operationType) {
      case RollbackOperationType.goalCreation:
        await _rollbackGoalCreation(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
        
      case RollbackOperationType.goalUpdate:
        await _rollbackGoalUpdate(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
        
      case RollbackOperationType.goalDeletion:
        await _rollbackGoalDeletion(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
        
      case RollbackOperationType.statusChange:
        await _rollbackStatusChange(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
        
      case RollbackOperationType.hierarchyChange:
        await _rollbackHierarchyChange(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
        
      case RollbackOperationType.bulkOperation:
        await _rollbackBulkOperation(rollbackPoint);
        restoredGoalIds.addAll(rollbackPoint.affectedGoalIds);
        break;
    }
    
    return restoredGoalIds;
  }
  
  /// 回滚目标创建
  Future<void> _rollbackGoalCreation(RollbackPoint rollbackPoint) async {
    final goalData = rollbackPoint.snapshot['goal'] as Map<String, dynamic>;
    final goal = Goal.fromJson(goalData);
    
    // 删除已创建的目标
    await databaseHelper.deleteGoal(goal.id!);
    goalBloc.add(DeleteGoal(goal.id!));
  }
  
  /// 回滚目标更新
  Future<void> _rollbackGoalUpdate(RollbackPoint rollbackPoint) async {
    final originalGoalData = rollbackPoint.snapshot['originalGoal'] as Map<String, dynamic>;
    final originalGoal = Goal.fromJson(originalGoalData);
    
    // 恢复原始目标
    await databaseHelper.updateGoal(originalGoal);
    goalBloc.add(UpdateGoal(originalGoal));
  }
  
  /// 回滚目标删除
  Future<void> _rollbackGoalDeletion(RollbackPoint rollbackPoint) async {
    final goalData = rollbackPoint.snapshot['goal'] as Map<String, dynamic>;
    final goal = Goal.fromJson(goalData);
    
    // 恢复已删除的目标
    await databaseHelper.insertGoal(goal);
    goalBloc.add(AddGoal(goal));
    
    // 恢复子目标
    final subGoalsData = rollbackPoint.snapshot['subGoals'] as List<dynamic>?;
    if (subGoalsData != null) {
      for (final subGoalData in subGoalsData) {
        final subGoal = Goal.fromJson(subGoalData as Map<String, dynamic>);
        await databaseHelper.insertGoal(subGoal);
        goalBloc.add(AddGoal(subGoal));
      }
    }
  }
  
  /// 回滚状态变更
  Future<void> _rollbackStatusChange(RollbackPoint rollbackPoint) async {
    final goalData = rollbackPoint.snapshot['goal'] as Map<String, dynamic>;
    final goal = Goal.fromJson(goalData);
    
    // 恢复原始状态
    await databaseHelper.updateGoal(goal);
    goalBloc.add(UpdateGoal(goal));
  }
  
  /// 回滚层级变更
  Future<void> _rollbackHierarchyChange(RollbackPoint rollbackPoint) async {
    final goalData = rollbackPoint.snapshot['goal'] as Map<String, dynamic>;
    final goal = Goal.fromJson(goalData);
    
    // 恢复原始层级关系
    await databaseHelper.updateGoal(goal);
    goalBloc.add(UpdateGoal(goal));
  }
  
  /// 回滚批量操作
  Future<void> _rollbackBulkOperation(RollbackPoint rollbackPoint) async {
    final goalsData = rollbackPoint.snapshot['goals'] as List<dynamic>;
    
    for (final goalData in goalsData) {
      final goal = Goal.fromJson(goalData as Map<String, dynamic>);
      await databaseHelper.updateGoal(goal);
      goalBloc.add(UpdateGoal(goal));
    }
  }
  
  /// 调度自动回滚
  void _scheduleAutoRollback(RollbackPoint rollbackPoint) {
    final timer = Timer(config.autoRollbackDelay, () async {
      await executeRollback(rollbackPoint.id);
    });
    
    _autoRollbackTimers[rollbackPoint.id] = timer;
  }
  
  /// 取消自动回滚
  void _cancelAutoRollback(String rollbackPointId) {
    final timer = _autoRollbackTimers[rollbackPointId];
    if (timer != null) {
      timer.cancel();
      _autoRollbackTimers.remove(rollbackPointId);
    }
  }
  
  /// 移除回滚点
  void _removeRollbackPoint(String rollbackPointId) {
    final rollbackPoint = _rollbackPointsMap[rollbackPointId];
    if (rollbackPoint != null) {
      _rollbackPoints.remove(rollbackPoint);
      _rollbackPointsMap.remove(rollbackPointId);
      _cancelAutoRollback(rollbackPointId);
    }
  }
  
  /// 移除最旧的回滚点
  void _removeOldestRollbackPoint() {
    if (_rollbackPoints.isNotEmpty) {
      final oldest = _rollbackPoints.removeFirst();
      _rollbackPointsMap.remove(oldest.id);
      _cancelAutoRollback(oldest.id);
    }
  }
  
  /// 启动清理定时器
  void _startCleanupTimer() {
    if (config.enableAutoCleanup) {
      Timer.periodic(const Duration(hours: 1), (_) => _cleanupExpiredRollbackPoints());
    }
  }
  
  /// 清理过期的回滚点
  void _cleanupExpiredRollbackPoints() {
    final now = DateTime.now();
    final expiredPoints = <RollbackPoint>[];
    
    for (final point in _rollbackPoints) {
      if (now.difference(point.timestamp) > config.rollbackPointExpiry) {
        expiredPoints.add(point);
      }
    }
    
    for (final point in expiredPoints) {
      _removeRollbackPoint(point.id);
    }
    
    if (expiredPoints.isNotEmpty) {
      debugPrint('Cleaned up ${expiredPoints.length} expired rollback points');
    }
  }
  
  /// 获取所有回滚点
  List<RollbackPoint> getAllRollbackPoints() {
    return List.unmodifiable(_rollbackPoints);
  }
  
  /// 获取回滚点
  RollbackPoint? getRollbackPoint(String rollbackPointId) {
    return _rollbackPointsMap[rollbackPointId];
  }
  
  /// 获取回滚历史
  List<RollbackResult> getRollbackHistory() {
    return List.unmodifiable(_rollbackHistory);
  }
  
  /// 获取统计信息
  RollbackStats getStats() {
    final successRate = _totalRollbacks == 0 ? 0.0 : _successfulRollbacks / _totalRollbacks;
    
    return RollbackStats(
      totalRollbacks: _totalRollbacks,
      successfulRollbacks: _successfulRollbacks,
      failedRollbacks: _failedRollbacks,
      successRate: successRate,
      activeRollbackPoints: _rollbackPoints.length,
      rollbackHistory: _rollbackHistory.length,
    );
  }
  
  /// 清理所有回滚点
  void clearAllRollbackPoints() {
    for (final timer in _autoRollbackTimers.values) {
      timer.cancel();
    }
    
    _rollbackPoints.clear();
    _rollbackPointsMap.clear();
    _autoRollbackTimers.clear();
  }
  
  /// 释放资源
  void dispose() {
    clearAllRollbackPoints();
  }
}

/// 回滚统计
class RollbackStats {
  final int totalRollbacks;
  final int successfulRollbacks;
  final int failedRollbacks;
  final double successRate;
  final int activeRollbackPoints;
  final int rollbackHistory;
  
  const RollbackStats({
    required this.totalRollbacks,
    required this.successfulRollbacks,
    required this.failedRollbacks,
    required this.successRate,
    required this.activeRollbackPoints,
    required this.rollbackHistory,
  });
}
