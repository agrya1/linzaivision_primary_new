/// 阶段6批次3架构一致性验证脚本
/// 验证整个GoalPage BLoC架构重构的一致性和完整性

import 'dart:io';

void main() async {
  print('🔍 阶段6批次3架构一致性验证开始...\n');
  
  // 1. 静态扫描：UI层无DatabaseHelper依赖
  await verifyNoDatabaseHelperDependency();
  
  // 2. 数据流统一验证
  await verifyUnifiedDataFlow();
  
  // 3. 状态单源验证
  await verifySingleSourceOfTruth();
  
  // 4. 错误处理统一验证
  await verifyUnifiedErrorHandling();
  
  print('\n🎉 阶段6批次3架构一致性验证完成！');
}

/// 任务6.1.1：静态扫描通过：UI层无DatabaseHelper依赖
Future<void> verifyNoDatabaseHelperDependency() async {
  print('📋 任务6.1.1：静态扫描通过：UI层无DatabaseHelper依赖');
  
  final uiFiles = [
    'lib/pages/goal_page.dart',
    'lib/views/timeline_view.dart',
    'lib/views/full_screen_view.dart',
    'lib/views/grid_view.dart',
  ];
  
  bool hasDirectDbDependency = false;
  
  for (final filePath in uiFiles) {
    final file = File(filePath);
    if (await file.exists()) {
      final content = await file.readAsString();
      
      // 检查是否有直接的DatabaseHelper调用（在新路径中）
      final directDbCalls = RegExp(r'_dbHelper\.(get|insert|update|delete)').allMatches(content);
      final blocSwitchPattern = RegExp(r'if.*\.(goalCRUDWriteThrough|dataLoadingViaBloc|uiStateWriteThrough)').allMatches(content);
      
      // 如果有直接DB调用但没有BLoC开关保护，则有问题
      if (directDbCalls.isNotEmpty && blocSwitchPattern.isEmpty) {
        print('❌ $filePath: 发现未保护的直接DatabaseHelper调用');
        hasDirectDbDependency = true;
      } else if (directDbCalls.isNotEmpty && blocSwitchPattern.isNotEmpty) {
        print('✅ $filePath: 直接DB调用已被BLoC开关保护');
      } else {
        print('✅ $filePath: 无直接DatabaseHelper依赖');
      }
    }
  }
  
  if (!hasDirectDbDependency) {
    print('✅ 6.1.1 UI层无不受保护的DatabaseHelper依赖');
  } else {
    print('❌ 6.1.1 UI层仍有不受保护的DatabaseHelper依赖');
  }
  
  print('');
}

/// 任务6.1.2：数据流统一：所有操作通过GoalBloc→Repository→DB
Future<void> verifyUnifiedDataFlow() async {
  print('📋 任务6.1.2：数据流统一：所有操作通过GoalBloc→Repository→DB');
  
  // 检查GoalBloc是否使用Repository
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final blocContent = await blocFile.readAsString();
  
  // 检查Repository使用
  final repositoryUsage = blocContent.contains('final GoalRepository repository') &&
                         blocContent.contains('repository.updateGoal') &&
                         blocContent.contains('repository.getGoals');
  
  if (repositoryUsage) {
    print('✅ GoalBloc正确使用Repository层');
  } else {
    print('❌ GoalBloc未正确使用Repository层');
  }
  
  // 检查Repository是否使用DatabaseHelper
  final repoFile = File('lib/repositories/goal_repository.dart');
  if (await repoFile.exists()) {
    final repoContent = await repoFile.readAsString();
    final dbHelperUsage = repoContent.contains('DatabaseHelper') &&
                         repoContent.contains('_dbHelper');
    
    if (dbHelperUsage) {
      print('✅ Repository正确使用DatabaseHelper');
    } else {
      print('❌ Repository未正确使用DatabaseHelper');
    }
  } else {
    print('❌ Repository文件不存在');
  }
  
  // 检查UI层是否使用BLoC事件
  final goalPageFile = File('lib/pages/goal_page.dart');
  final goalPageContent = await goalPageFile.readAsString();
  
  final blocEventUsage = goalPageContent.contains('context.read<GoalBloc>().add(') &&
                        goalPageContent.contains('BlocListener<GoalBloc') &&
                        goalPageContent.contains('BlocBuilder<GoalBloc');
  
  if (blocEventUsage) {
    print('✅ UI层正确使用BLoC事件');
    print('✅ 6.1.2 数据流统一：UI→BLoC→Repository→DB');
  } else {
    print('❌ 6.1.2 数据流不统一');
  }
  
  print('');
}

/// 任务6.1.3：状态单源：UI完全依赖GoalState
Future<void> verifySingleSourceOfTruth() async {
  print('📋 任务6.1.3：状态单源：UI完全依赖GoalState');
  
  final goalPageFile = File('lib/pages/goal_page.dart');
  final content = await goalPageFile.readAsString();
  
  // 检查是否有BlocBuilder实现
  final hasBlocBuilder = content.contains('BlocBuilder<GoalBloc, GoalState>') &&
                        content.contains('buildWhen:') &&
                        content.contains('builder: (context, state)');
  
  // 检查是否有状态依赖GoalState
  final hasStateUsage = content.contains('state.goals') &&
                       content.contains('state.currentGoal') &&
                       content.contains('state.viewMode');
  
  // 检查是否有开关控制的双路径
  final hasSwitchControl = content.contains('uiStateWriteThrough') &&
                          content.contains('_buildWithBlocBuilder') &&
                          content.contains('_buildWithBlocListener');
  
  if (hasBlocBuilder && hasStateUsage && hasSwitchControl) {
    print('✅ UI完全依赖GoalState（在新路径中）');
    print('✅ 双路径架构正确实现');
    print('✅ 6.1.3 状态单源验证通过');
  } else {
    print('❌ 6.1.3 状态单源验证失败');
    if (!hasBlocBuilder) print('  - 缺少BlocBuilder实现');
    if (!hasStateUsage) print('  - 缺少GoalState使用');
    if (!hasSwitchControl) print('  - 缺少开关控制');
  }
  
  print('');
}

/// 任务6.1.4：错误处理统一
Future<void> verifyUnifiedErrorHandling() async {
  print('📋 任务6.1.4：错误处理统一');
  
  final blocFile = File('lib/bloc/goal/goal_bloc.dart');
  final content = await blocFile.readAsString();
  
  // 检查错误处理模式
  final hasErrorHandling = content.contains('try {') &&
                          content.contains('} catch (e)') &&
                          content.contains('emit(GoalError(');
  
  // 检查错误状态的一致性
  final errorStatePattern = RegExp(r'emit\(GoalError\([^)]+\)\)').allMatches(content);
  
  if (hasErrorHandling && errorStatePattern.length >= 3) {
    print('✅ BLoC层错误处理统一');
  } else {
    print('❌ BLoC层错误处理不统一');
  }
  
  // 检查UI层错误处理
  final goalPageFile = File('lib/pages/goal_page.dart');
  final uiContent = await goalPageFile.readAsString();
  
  final hasUIErrorHandling = uiContent.contains('if (state is GoalError)') &&
                            uiContent.contains('_buildErrorView');
  
  if (hasUIErrorHandling) {
    print('✅ UI层错误处理统一');
    print('✅ 6.1.4 错误处理统一验证通过');
  } else {
    print('❌ 6.1.4 错误处理统一验证失败');
  }
  
  print('');
}
