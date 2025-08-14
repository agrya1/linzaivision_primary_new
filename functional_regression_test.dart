/// 阶段6批次3功能回归测试脚本
/// 验证所有核心功能在BLoC架构重构后仍然正常工作

import 'dart:io';

void main() async {
  print('🔍 阶段6批次3功能回归测试开始...\n');
  
  // 1. CRUD操作流程测试
  await testCRUDOperations();
  
  // 2. 图片管理功能测试
  await testImageManagement();
  
  // 3. 日期编辑功能测试
  await testDateEditing();
  
  // 4. 目标状态切换测试
  await testGoalStatusToggle();
  
  // 5. 数据加载和刷新测试
  await testDataLoadingAndRefresh();
  
  print('\n🎉 阶段6批次3功能回归测试完成！');
}

/// 任务6.2.1：完整的CRUD操作流程测试
Future<void> testCRUDOperations() async {
  print('📋 任务6.2.1：完整的CRUD操作流程测试');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查Create操作
  final hasCreateGoal = content.contains('_onCreateGoal') &&
                       content.contains('CreateGoal') &&
                       content.contains('repository.insertGoal');
  
  // 检查Read操作
  final hasReadGoals = content.contains('_onLoadGoals') &&
                      content.contains('LoadGoals') &&
                      content.contains('repository.getGoals');
  
  // 检查Update操作
  final hasUpdateGoal = content.contains('_onUpdateGoal') &&
                       content.contains('UpdateGoal') &&
                       content.contains('repository.updateGoal');
  
  // 检查Delete操作
  final hasDeleteGoal = content.contains('_onDeleteGoal') &&
                       content.contains('DeleteGoal') &&
                       content.contains('repository.deleteGoal');
  
  final crudResults = [
    ('Create操作', hasCreateGoal),
    ('Read操作', hasReadGoals),
    ('Update操作', hasUpdateGoal),
    ('Delete操作', hasDeleteGoal),
  ];
  
  bool allCrudPassed = true;
  for (final result in crudResults) {
    final status = result.$2 ? '✅' : '❌';
    print('$status ${result.$1}');
    if (!result.$2) allCrudPassed = false;
  }
  
  if (allCrudPassed) {
    print('✅ 6.2.1 完整的CRUD操作流程测试通过');
  } else {
    print('❌ 6.2.1 CRUD操作流程测试失败');
  }
  
  print('');
}

/// 任务6.2.2：图片管理功能测试
Future<void> testImageManagement() async {
  print('📋 任务6.2.2：图片管理功能测试');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查图片保存功能
  final hasSaveImage = content.contains('_onSaveImage') &&
                      content.contains('SaveImage') &&
                      content.contains('imagePath');
  
  // 检查图片更新的emit策略
  final hasImageEmitStrategy = content.contains('立即emit确保UI及时反馈') &&
                              content.contains('图片更新是关键用户交互');
  
  // 检查UI层图片处理
  final goalPageFile = File('lib/pages/goal_page.dart');
  final uiContent = await goalPageFile.readAsString();
  
  final hasImageUI = uiContent.contains('imagePath') &&
                    uiContent.contains('_getImageProvider');
  
  final imageResults = [
    ('图片保存BLoC事件', hasSaveImage),
    ('图片emit策略优化', hasImageEmitStrategy),
    ('UI层图片处理', hasImageUI),
  ];
  
  bool allImagePassed = true;
  for (final result in imageResults) {
    final status = result.$2 ? '✅' : '❌';
    print('$status ${result.$1}');
    if (!result.$2) allImagePassed = false;
  }
  
  if (allImagePassed) {
    print('✅ 6.2.2 图片管理功能测试通过');
  } else {
    print('❌ 6.2.2 图片管理功能测试失败');
  }
  
  print('');
}

/// 任务6.2.3：日期编辑功能测试
Future<void> testDateEditing() async {
  print('📋 任务6.2.3：日期编辑功能测试');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查日期保存功能
  final hasSaveDate = content.contains('_onSaveDate') &&
                     content.contains('SaveDate') &&
                     content.contains('targetDate');
  
  // 检查日期更新的emit策略
  final hasDateEmitStrategy = content.contains('日期编辑是关键用户交互，需要即时响应') &&
                             content.contains('立即emit确保UI及时反馈');
  
  // 检查TimelineView的日期交互优化
  final timelineFile = File('lib/views/timeline_view.dart');
  if (await timelineFile.exists()) {
    final timelineContent = await timelineFile.readAsString();
    
    // 检查是否移除了直接Goal修改
    final hasRemovedDirectModification = !timelineContent.contains('goal.targetDate = newDate') &&
                                        timelineContent.contains('批次3阶段4：移除对Goal实体的直接修改');
    
    if (hasRemovedDirectModification) {
      print('✅ TimelineView直接Goal修改已移除');
    } else {
      print('❌ TimelineView仍有直接Goal修改');
    }
  }
  
  final dateResults = [
    ('日期保存BLoC事件', hasSaveDate),
    ('日期emit策略优化', hasDateEmitStrategy),
  ];
  
  bool allDatePassed = true;
  for (final result in dateResults) {
    final status = result.$2 ? '✅' : '❌';
    print('$status ${result.$1}');
    if (!result.$2) allDatePassed = false;
  }
  
  if (allDatePassed) {
    print('✅ 6.2.3 日期编辑功能测试通过');
  } else {
    print('❌ 6.2.3 日期编辑功能测试失败');
  }
  
  print('');
}

/// 任务6.2.4：目标状态切换测试
Future<void> testGoalStatusToggle() async {
  print('📋 任务6.2.4：目标状态切换测试');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查状态切换功能
  final hasToggleStatus = content.contains('_onToggleGoalStatus') &&
                         content.contains('ToggleGoalStatus') &&
                         content.contains('GoalStatus.completed');
  
  // 检查就地更新策略
  final hasInPlaceUpdate = content.contains('就地更新：使用map操作更新列表中的特定目标') &&
                          content.contains('final updatedGoals = currentState.goals.map');
  
  // 检查立即emit
  final hasImmediateEmit = content.contains('立即emit确保UI及时反馈') &&
                          content.contains('emit(currentState.copyWith(');
  
  final statusResults = [
    ('状态切换BLoC事件', hasToggleStatus),
    ('就地更新策略', hasInPlaceUpdate),
    ('立即emit响应', hasImmediateEmit),
  ];
  
  bool allStatusPassed = true;
  for (final result in statusResults) {
    final status = result.$2 ? '✅' : '❌';
    print('$status ${result.$1}');
    if (!result.$2) allStatusPassed = false;
  }
  
  if (allStatusPassed) {
    print('✅ 6.2.4 目标状态切换测试通过');
  } else {
    print('❌ 6.2.4 目标状态切换测试失败');
  }
  
  print('');
}

/// 任务6.2.5：数据加载和刷新测试
Future<void> testDataLoadingAndRefresh() async {
  print('📋 任务6.2.5：数据加载和刷新测试');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查数据加载功能
  final hasLoadGoals = content.contains('_onLoadGoals') &&
                      content.contains('LoadGoals') &&
                      content.contains('repository.getGoals');
  
  // 检查刷新功能
  final hasRefreshGoalTree = content.contains('_onRefreshGoalTree') &&
                            content.contains('RefreshGoalTree') &&
                            content.contains('repository.getGoalTree');
  
  // 检查特定目标加载
  final hasLoadSpecificGoal = content.contains('_onLoadSpecificGoal') &&
                             content.contains('LoadSpecificGoal');
  
  // 检查UI层的数据加载开关
  final goalPageFile = File('lib/pages/goal_page.dart');
  final uiContent = await goalPageFile.readAsString();
  
  final hasDataLoadingSwitch = uiContent.contains('dataLoadingViaBloc') &&
                              uiContent.contains('LoadGoals') &&
                              uiContent.contains('RefreshGoalTree');
  
  final loadingResults = [
    ('数据加载BLoC事件', hasLoadGoals),
    ('刷新功能', hasRefreshGoalTree),
    ('特定目标加载', hasLoadSpecificGoal),
    ('UI层数据加载开关', hasDataLoadingSwitch),
  ];
  
  bool allLoadingPassed = true;
  for (final result in loadingResults) {
    final status = result.$2 ? '✅' : '❌';
    print('$status ${result.$1}');
    if (!result.$2) allLoadingPassed = false;
  }
  
  if (allLoadingPassed) {
    print('✅ 6.2.5 数据加载和刷新测试通过');
  } else {
    print('❌ 6.2.5 数据加载和刷新测试失败');
  }
  
  print('');
}
