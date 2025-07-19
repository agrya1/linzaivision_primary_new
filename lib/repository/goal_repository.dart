import '../models/goal.dart';
import '../database/database_helper.dart';

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
}

/// 目标数据仓库实现
class GoalRepositoryImpl implements GoalRepository {
  final DatabaseHelper _dbHelper;
  
  GoalRepositoryImpl(this._dbHelper);
  
  @override
  Future<List<Goal>> getGoals({int? parentId}) async {
    return await _dbHelper.getGoals(parentId: parentId);
  }
  
  @override
  Future<Goal?> getGoal(int id) async {
    final goals = await _dbHelper.getGoals();
    return goals.where((goal) => goal.id == id).firstOrNull;
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
} 