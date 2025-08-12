import '../models/goal.dart';
import '../database/database_helper.dart';
import '../bloc/transaction/database_batch_optimizer.dart';

/// 目标数据仓库抽象层
abstract class GoalRepository {
  /// 获取目标列表
  Future<List<Goal>> getGoals({int? parentId});

  /// 获取单个目标
  Future<Goal?> getGoal(int id);

  /// 插入目标
  Future<int> insertGoal(Goal goal);

  /// 更新目标
  Future<int> updateGoal(Goal goal);

  /// 删除目标
  Future<int> deleteGoal(int id);

  /// 获取目标树结构
  Future<List<Goal>> getGoalTree();

  /// 批量插入目标树
  Future<void> batchInsertGoalTree(List<Goal> rootGoals);

  /// 批量操作方法
  /// 批量插入目标
  Future<List<int>> batchInsertGoals(List<Goal> goals);

  /// 批量更新目标
  Future<List<int>> batchUpdateGoals(List<Goal> goals);

  /// 批量删除目标
  Future<List<int>> batchDeleteGoals(List<int> goalIds);

  /// 事务性批量操作
  Future<T> executeInTransaction<T>(Future<T> Function() operation);

  /// 获取批量操作统计
  Map<String, dynamic> getBatchOperationStats();
}

/// 目标数据仓库实现
class GoalRepositoryImpl implements GoalRepository {
  final DatabaseHelper _dbHelper;

  // 数据库批量操作优化器
  late final DatabaseBatchOptimizer _batchOptimizer;

  GoalRepositoryImpl(this._dbHelper) {
    // 初始化批量操作优化器
    _batchOptimizer = DatabaseBatchOptimizer(
      databaseHelper: _dbHelper,
      config: DatabaseBatchConfig.highPerformance(),
    );
  }

  @override
  Future<List<Goal>> getGoals({int? parentId}) async {
    return await _dbHelper.getGoals(parentId: parentId);
  }

  @override
  Future<Goal?> getGoal(int id) async {
    print('【GoalRepository】开始获取目标，ID: $id');
    final goal = await _dbHelper.getGoal(id);
    if (goal != null) {
      print('【GoalRepository】成功获取目标，ID: ${goal.id}, 标题: ${goal.title}');
    } else {
      print('【GoalRepository】未找到目标，ID: $id');
    }
    return goal;
  }

  @override
  Future<int> insertGoal(Goal goal) async {
    return await _dbHelper.insertGoal(goal);
  }

  @override
  Future<int> updateGoal(Goal goal) async {
    return await _dbHelper.updateGoal(goal);
  }

  @override
  Future<int> deleteGoal(int id) async {
    return await _dbHelper.deleteGoal(id);
  }

  @override
  Future<List<Goal>> getGoalTree() async {
    return await _dbHelper.getGoalTree();
  }

  @override
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {
    await _dbHelper.batchInsertGoalTree(rootGoals);
  }

  @override
  Future<List<int>> batchInsertGoals(List<Goal> goals) async {
    final result = await _batchOptimizer.batchInsertGoals(goals);
    return List.generate(result.successfulItems, (index) => index + 1);
  }

  @override
  Future<List<int>> batchUpdateGoals(List<Goal> goals) async {
    final result = await _batchOptimizer.batchUpdateGoals(goals);
    return List.generate(result.successfulItems, (index) => index + 1);
  }

  @override
  Future<List<int>> batchDeleteGoals(List<int> goalIds) async {
    final result = await _batchOptimizer.batchDeleteGoals(goalIds);
    return List.generate(result.successfulItems, (index) => index + 1);
  }

  @override
  Future<T> executeInTransaction<T>(Future<T> Function() operation) async {
    // 使用DatabaseHelper的事务功能
    final database = await _dbHelper.database;
    return await database.transaction((txn) async {
      return await operation();
    });
  }

  @override
  Map<String, dynamic> getBatchOperationStats() {
    final stats = _batchOptimizer.getStats();
    return {
      'totalOperations': stats.totalOperations,
      'batchedOperations': stats.batchedOperations,
      'successfulBatches': stats.successfulBatches,
      'failedBatches': stats.failedBatches,
      'averageExecutionTime': stats.averageExecutionTime.inMilliseconds,
      'batchSuccessRate': stats.batchSuccessRate,
      'pendingOperations': stats.pendingOperations,
      'performanceLevel': stats.performanceLevel,
    };
  }

  /// 智能批量操作 - 根据操作类型和数据量选择最佳策略
  Future<List<int>> smartBatchOperation(
    DatabaseOperationType type,
    List<dynamic> items,
  ) async {
    switch (type) {
      case DatabaseOperationType.insert:
        final goals = items.cast<Goal>();
        return await batchInsertGoals(goals);
      case DatabaseOperationType.update:
        final goals = items.cast<Goal>();
        return await batchUpdateGoals(goals);
      case DatabaseOperationType.delete:
        final goalIds = items.cast<int>();
        return await batchDeleteGoals(goalIds);
      default:
        throw ArgumentError('Unsupported operation type: $type');
    }
  }

  /// 批量同步操作 - 用于数据同步场景
  Future<Map<String, dynamic>> batchSyncGoals({
    List<Goal>? goalsToInsert,
    List<Goal>? goalsToUpdate,
    List<int>? goalIdsToDelete,
  }) async {
    return await executeInTransaction(() async {
      final results = <String, dynamic>{};

      // 批量删除
      if (goalIdsToDelete != null && goalIdsToDelete.isNotEmpty) {
        final deleteResults = await batchDeleteGoals(goalIdsToDelete);
        results['deleted'] = deleteResults.length;
      }

      // 批量更新
      if (goalsToUpdate != null && goalsToUpdate.isNotEmpty) {
        final updateResults = await batchUpdateGoals(goalsToUpdate);
        results['updated'] = updateResults.length;
      }

      // 批量插入
      if (goalsToInsert != null && goalsToInsert.isNotEmpty) {
        final insertResults = await batchInsertGoals(goalsToInsert);
        results['inserted'] = insertResults.length;
      }

      results['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      return results;
    });
  }

  /// 清理资源
  void dispose() {
    _batchOptimizer.dispose();
  }
}
