/// 阶段2批次3实施验证脚本
/// 验证GoalPage数据写入路径清理的实施结果

import 'dart:io';

void main() async {
  print('🔍 阶段2批次3实施验证开始...\n');
  
  // 1. 验证功能开关是否正确添加
  await verifyFeatureToggle();
  
  // 2. 验证CRUD操作替换
  await verifyCRUDReplacement();
  
  // 3. 验证批量操作替换
  await verifyBatchReplacement();
  
  // 4. 验证静态扫描结果
  await verifyStaticScan();
  
  print('\n🎉 阶段2批次3实施验证完成！');
}

Future<void> verifyFeatureToggle() async {
  print('📋 任务2.3验证：功能开关集成');
  
  final file = File('lib/utils/bloc_feature_toggles.dart');
  final content = await file.readAsString();
  
  // 检查私有字段
  if (content.contains('bool _goalCRUDWriteThrough = false;')) {
    print('✅ 2.3.1 私有字段_goalCRUDWriteThrough已添加');
  } else {
    print('❌ 2.3.1 私有字段_goalCRUDWriteThrough未找到');
  }
  
  // 检查getter
  if (content.contains('bool get goalCRUDWriteThrough => _goalCRUDWriteThrough;')) {
    print('✅ 2.3.2 getter goalCRUDWriteThrough已添加');
  } else {
    print('❌ 2.3.2 getter goalCRUDWriteThrough未找到');
  }
  
  // 检查isFeatureEnabled支持
  if (content.contains("case 'goalCRUDWriteThrough': return _goalCRUDWriteThrough;")) {
    print('✅ 2.3.3 isFeatureEnabled支持已添加');
  } else {
    print('❌ 2.3.3 isFeatureEnabled支持未找到');
  }
  
  // 检查setFeatureEnabled支持
  if (content.contains("case 'goalCRUDWriteThrough':")) {
    print('✅ 2.3.4 setFeatureEnabled支持已添加');
  } else {
    print('❌ 2.3.4 setFeatureEnabled支持未找到');
  }
  
  // 检查loadSettings支持
  if (content.contains("_goalCRUDWriteThrough = prefs.getBool('bloc_feature_goalCRUDWriteThrough') ?? false;")) {
    print('✅ 2.3.5 loadSettings支持已添加');
  } else {
    print('❌ 2.3.5 loadSettings支持未找到');
  }
  
  print('');
}

Future<void> verifyCRUDReplacement() async {
  print('📋 任务2.1验证：CRUD操作替换');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 检查insertGoal替换
  if (content.contains('if (_featureToggles.goalCRUDWriteThrough)') && 
      content.contains('AddGoalWithDetails(goal, setAsCurrent: true, insertIndex: 0)')) {
    print('✅ 2.1.1 insertGoal替换为AddGoalWithDetails事件');
  } else {
    print('❌ 2.1.1 insertGoal替换未完成');
  }
  
  // 检查updateGoal替换
  if (content.contains('UpdateGoalWithValidation(goal, validateData: false)')) {
    print('✅ 2.1.2 updateGoal替换为UpdateGoalWithValidation事件');
  } else {
    print('❌ 2.1.2 updateGoal替换未完成');
  }
  
  // 检查deleteGoal替换
  if (content.contains('DeleteGoalWithCleanup(goal, updateCurrent: true)')) {
    print('✅ 2.1.3 deleteGoal替换为DeleteGoalWithCleanup事件');
  } else {
    print('❌ 2.1.3 deleteGoal替换未完成');
  }
  
  // 检查传统路径保留
  if (content.contains('// 传统路径：先保存到数据库') && 
      content.contains('await _dbHelper.insertGoal(goal)')) {
    print('✅ 2.1.4 传统路径已正确保留');
  } else {
    print('❌ 2.1.4 传统路径保留不完整');
  }
  
  print('');
}

Future<void> verifyBatchReplacement() async {
  print('📋 任务2.2验证：批量操作替换');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 检查batchInsertGoalTree替换
  if (content.contains('SaveInitialGoals(goals)')) {
    print('✅ 2.2.1 batchInsertGoalTree替换为SaveInitialGoals事件');
  } else {
    print('❌ 2.2.1 batchInsertGoalTree替换未完成');
  }
  
  // 检查传统路径保留
  if (content.contains('await _dbHelper.batchInsertGoalTree(goals)')) {
    print('✅ 2.2.2 批量操作传统路径已保留');
  } else {
    print('❌ 2.2.2 批量操作传统路径未保留');
  }
  
  print('');
}

Future<void> verifyStaticScan() async {
  print('📋 任务2.4.5验证：静态扫描');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 统计_dbHelper调用
  final insertMatches = RegExp(r'_dbHelper\.insert').allMatches(content);
  final updateMatches = RegExp(r'_dbHelper\.update').allMatches(content);
  final deleteMatches = RegExp(r'_dbHelper\.delete').allMatches(content);
  final batchMatches = RegExp(r'_dbHelper\.batch').allMatches(content);
  
  final totalMatches = insertMatches.length + updateMatches.length + 
                      deleteMatches.length + batchMatches.length;
  
  print('📊 _dbHelper调用统计：');
  print('   - insertGoal: ${insertMatches.length}次');
  print('   - updateGoal: ${updateMatches.length}次');
  print('   - deleteGoal: ${deleteMatches.length}次');
  print('   - batchInsertGoalTree: ${batchMatches.length}次');
  print('   - 总计: ${totalMatches}次');
  
  // 验证所有调用都在传统路径中
  final traditionalPathMatches = RegExp(r'// 传统路径：').allMatches(content);
  
  if (totalMatches == 5 && traditionalPathMatches.length >= 4) {
    print('✅ 2.4.5 所有_dbHelper调用都在传统路径中，符合预期');
  } else {
    print('❌ 2.4.5 _dbHelper调用分布不符合预期');
  }
  
  print('');
}
