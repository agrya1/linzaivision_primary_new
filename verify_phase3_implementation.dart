/// 阶段3批次3实施验证脚本
/// 验证GoalPage数据读取路径清理的实施结果

import 'dart:io';

void main() async {
  print('🔍 阶段3批次3实施验证开始...\n');
  
  // 1. 验证功能开关是否正确添加
  await verifyFeatureToggle();
  
  // 2. 验证读取操作替换
  await verifyReadReplacement();
  
  // 3. 验证BlocListener集成
  await verifyBlocListenerIntegration();
  
  // 4. 验证静态扫描结果
  await verifyStaticScan();
  
  print('\n🎉 阶段3批次3实施验证完成！');
}

Future<void> verifyFeatureToggle() async {
  print('📋 任务3.3验证：功能开关集成');
  
  final file = File('lib/utils/bloc_feature_toggles.dart');
  final content = await file.readAsString();
  
  // 检查私有字段
  if (content.contains('bool _dataLoadingViaBloc = false;')) {
    print('✅ 3.3.1 私有字段_dataLoadingViaBloc已添加');
  } else {
    print('❌ 3.3.1 私有字段_dataLoadingViaBloc未找到');
  }
  
  // 检查getter
  if (content.contains('bool get dataLoadingViaBloc => _dataLoadingViaBloc;')) {
    print('✅ 3.3.2 getter dataLoadingViaBloc已添加');
  } else {
    print('❌ 3.3.2 getter dataLoadingViaBloc未找到');
  }
  
  // 检查isFeatureEnabled支持
  if (content.contains("case 'dataLoadingViaBloc': return _dataLoadingViaBloc;")) {
    print('✅ 3.3.3 isFeatureEnabled支持已添加');
  } else {
    print('❌ 3.3.3 isFeatureEnabled支持未找到');
  }
  
  // 检查setFeatureEnabled支持
  if (content.contains("case 'dataLoadingViaBloc':")) {
    print('✅ 3.3.4 setFeatureEnabled支持已添加');
  } else {
    print('❌ 3.3.4 setFeatureEnabled支持未找到');
  }
  
  // 检查loadSettings支持
  if (content.contains("_dataLoadingViaBloc = prefs.getBool('bloc_feature_dataLoadingViaBloc') ?? false;")) {
    print('✅ 3.3.5 loadSettings支持已添加');
  } else {
    print('❌ 3.3.5 loadSettings支持未找到');
  }
  
  print('');
}

Future<void> verifyReadReplacement() async {
  print('📋 任务3.1验证：读取操作替换');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 检查getGoalTree替换
  if (content.contains('if (_featureToggles.dataLoadingViaBloc)') && 
      content.contains('context.read<GoalBloc>().add(const LoadGoals())')) {
    print('✅ 3.1.1 getGoalTree替换为LoadGoals + RefreshGoalTree事件');
  } else {
    print('❌ 3.1.1 getGoalTree替换未完成');
  }
  
  // 检查getGoal替换
  if (content.contains('context.read<GoalBloc>().add(LoadSpecificGoal(goalId))')) {
    print('✅ 3.1.2 getGoal替换为LoadSpecificGoal事件');
  } else {
    print('❌ 3.1.2 getGoal替换未完成');
  }
  
  // 检查getGoals替换
  if (content.contains('context.read<GoalBloc>().add(LoadGoals(parentId:')) {
    print('✅ 3.1.3 getGoals替换为LoadGoals事件');
  } else {
    print('❌ 3.1.3 getGoals替换未完成');
  }
  
  // 检查传统路径保留
  if (content.contains('// 传统路径：直接从数据库获取') && 
      content.contains('await _dbHelper.getGoalTree()')) {
    print('✅ 3.1.4 传统路径已正确保留');
  } else {
    print('❌ 3.1.4 传统路径保留不完整');
  }
  
  print('');
}

Future<void> verifyBlocListenerIntegration() async {
  print('📋 任务3.2验证：BlocListener集成');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 检查Completer使用
  if (content.contains('final completer = Completer<')) {
    print('✅ 3.2.1 Completer异步处理已集成');
  } else {
    print('❌ 3.2.1 Completer异步处理未找到');
  }
  
  // 检查StreamSubscription使用
  if (content.contains('late final StreamSubscription<GoalState> subscription;')) {
    print('✅ 3.2.2 StreamSubscription监听已集成');
  } else {
    print('❌ 3.2.2 StreamSubscription监听未找到');
  }
  
  // 检查状态监听
  if (content.contains('if (state is GoalsLoaded)') && 
      content.contains('else if (state is GoalError)')) {
    print('✅ 3.2.3 成功和错误状态监听已集成');
  } else {
    print('❌ 3.2.3 状态监听集成不完整');
  }
  
  print('');
}

Future<void> verifyStaticScan() async {
  print('📋 任务3.4.5验证：静态扫描');
  
  final file = File('lib/pages/goal_page.dart');
  final content = await file.readAsString();
  
  // 统计_dbHelper.get调用
  final getGoalTreeMatches = RegExp(r'_dbHelper\.getGoalTree\(').allMatches(content);
  final getGoalMatches = RegExp(r'_dbHelper\.getGoal\(').allMatches(content);
  final getGoalsMatches = RegExp(r'_dbHelper\.getGoals\(').allMatches(content);
  
  final totalMatches = getGoalTreeMatches.length + getGoalMatches.length + getGoalsMatches.length;
  
  print('📊 _dbHelper读取调用统计：');
  print('   - getGoalTree: ${getGoalTreeMatches.length}次');
  print('   - getGoal: ${getGoalMatches.length}次');
  print('   - getGoals: ${getGoalsMatches.length}次');
  print('   - 总计: ${totalMatches}次');
  
  // 验证所有调用都在传统路径中
  final traditionalPathMatches = RegExp(r'// 传统路径：').allMatches(content);
  
  if (totalMatches == 10 && traditionalPathMatches.length >= 6) {
    print('✅ 3.4.5 所有_dbHelper读取调用都在传统路径中，符合预期');
  } else {
    print('❌ 3.4.5 _dbHelper读取调用分布不符合预期');
  }
  
  print('');
}
