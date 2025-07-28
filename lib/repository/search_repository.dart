import '../models/goal.dart';
import '../database/database_helper.dart';

/// 搜索仓库抽象层
abstract class SearchRepository {
  /// 搜索目标
  Future<List<Goal>> searchGoals(String query);
  
  /// 获取搜索历史
  Future<List<String>> getSearchHistory();
  
  /// 添加搜索历史
  Future<void> addSearchHistory(String query);
  
  /// 清除搜索历史
  Future<void> clearSearchHistory();
}

/// 搜索仓库实现
class SearchRepositoryImpl implements SearchRepository {
  final DatabaseHelper _dbHelper;
  
  SearchRepositoryImpl(this._dbHelper);
  
  @override
  Future<List<Goal>> searchGoals(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 获取所有目标
    final allGoals = await _dbHelper.getGoalTree();
    
    // 扁平化目标树
    final flatGoals = _flattenGoalTree(allGoals);
    
    // 执行搜索
    return flatGoals
        .where((goal) => 
            goal.title.toLowerCase().contains(query.toLowerCase()) || 
            goal.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  /// 扁平化目标树，将所有子目标也放入列表中
  List<Goal> _flattenGoalTree(List<Goal> goals) {
    final result = <Goal>[];
    
    for (var goal in goals) {
      result.add(goal);
      if (goal.subGoals.isNotEmpty) {
        result.addAll(_flattenGoalTree(goal.subGoals));
      }
    }
    
    return result;
  }
  
  @override
  Future<List<String>> getSearchHistory() async {
    // TODO: 实现从SharedPreferences获取搜索历史
    return [];
  }
  
  @override
  Future<void> addSearchHistory(String query) async {
    // TODO: 实现保存搜索历史到SharedPreferences
  }
  
  @override
  Future<void> clearSearchHistory() async {
    // TODO: 实现清除搜索历史
  }
} 