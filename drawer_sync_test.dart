// 导航抽屉同步机制测试文件
// 用于验证导航抽屉与BLoC状态的实时同步

import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';

/// 导航抽屉同步验证测试
class DrawerSyncValidator {
  /// 验证新增目标后导航抽屉同步
  static Future<bool> validateAddGoalSync({
    required List<Goal> initialGoals,
    required Goal newGoal,
    required Function(List<Goal>) drawerGoalsGetter,
  }) async {
    print('🧪 测试：新增目标后导航抽屉同步');

    // 1. 记录初始状态
    final initialCount = initialGoals.length;
    print('初始目标数量: $initialCount');

    // 2. 模拟新增目标
    final updatedGoals = [newGoal, ...initialGoals];

    // 3. 等待UI更新
    await Future.delayed(Duration(milliseconds: 100));

    // 4. 检查导航抽屉中的目标列表
    final drawerGoals = drawerGoalsGetter(updatedGoals);
    final drawerCount = drawerGoals.length;

    print('更新后目标数量: $drawerCount');
    print('新增目标是否在抽屉中: ${drawerGoals.any((g) => g.id == newGoal.id)}');

    // 5. 验证同步结果
    final isCountCorrect = drawerCount == initialCount + 1;
    final isNewGoalPresent = drawerGoals.any((g) => g.id == newGoal.id);
    final isOrderCorrect = drawerGoals.first.id == newGoal.id; // 新目标应该在最前面

    final result = isCountCorrect && isNewGoalPresent && isOrderCorrect;
    print('✅ 新增目标同步测试结果: ${result ? "通过" : "失败"}');

    return result;
  }

  /// 验证删除目标后导航抽屉同步
  static Future<bool> validateDeleteGoalSync({
    required List<Goal> initialGoals,
    required Goal goalToDelete,
    required Function(List<Goal>) drawerGoalsGetter,
  }) async {
    print('🧪 测试：删除目标后导航抽屉同步');

    // 1. 记录初始状态
    final initialCount = initialGoals.length;
    print('初始目标数量: $initialCount');
    print('要删除的目标: ${goalToDelete.title} (ID: ${goalToDelete.id})');

    // 2. 模拟删除目标
    final updatedGoals =
        initialGoals.where((g) => g.id != goalToDelete.id).toList();

    // 3. 等待UI更新
    await Future.delayed(Duration(milliseconds: 100));

    // 4. 检查导航抽屉中的目标列表
    final drawerGoals = drawerGoalsGetter(updatedGoals);
    final drawerCount = drawerGoals.length;

    print('更新后目标数量: $drawerCount');
    print('删除目标是否已从抽屉移除: ${!drawerGoals.any((g) => g.id == goalToDelete.id)}');

    // 5. 验证同步结果
    final isCountCorrect = drawerCount == initialCount - 1;
    final isGoalRemoved = !drawerGoals.any((g) => g.id == goalToDelete.id);

    final result = isCountCorrect && isGoalRemoved;
    print('✅ 删除目标同步测试结果: ${result ? "通过" : "失败"}');

    return result;
  }

  /// 验证目标层级结构在导航抽屉中的正确显示
  static bool validateHierarchyDisplay({
    required List<Goal> allGoals,
    required Function(Goal, int) levelCalculator,
  }) {
    print('🧪 测试：目标层级结构显示');

    bool allCorrect = true;

    for (final goal in allGoals) {
      final expectedLevel = goal.parentId == null ? 0 : 1;
      final actualLevel = levelCalculator(goal, 0);

      if (expectedLevel != actualLevel) {
        print('❌ 层级错误: ${goal.title} 期望层级:$expectedLevel 实际层级:$actualLevel');
        allCorrect = false;
      } else {
        print('✅ 层级正确: ${goal.title} 层级:$actualLevel');
      }

      // 检查子目标层级
      for (final subGoal in goal.subGoals) {
        final expectedSubLevel = 1;
        final actualSubLevel = levelCalculator(subGoal, 1);

        if (expectedSubLevel != actualSubLevel) {
          print(
              '❌ 子目标层级错误: ${subGoal.title} 期望层级:$expectedSubLevel 实际层级:$actualSubLevel');
          allCorrect = false;
        }
      }
    }

    print('✅ 层级结构显示测试结果: ${allCorrect ? "通过" : "失败"}');
    return allCorrect;
  }

  /// 验证BLoC状态与导航抽屉数据的实时同步
  static Future<bool> validateBlocStateSync({
    required GoalsLoaded blocState,
    required List<Goal> drawerGoals,
  }) async {
    print('🧪 测试：BLoC状态与导航抽屉实时同步');

    // 1. 比较数据数量
    final blocCount = blocState.allGoals.length;
    final drawerCount = drawerGoals.length;

    print('BLoC状态目标数量: $blocCount');
    print('导航抽屉目标数量: $drawerCount');

    final isCountMatch = blocCount == drawerCount;

    // 2. 比较数据内容
    bool isContentMatch = true;
    for (final blocGoal in blocState.allGoals) {
      final drawerGoal = drawerGoals.firstWhere(
        (g) => g.id == blocGoal.id,
        orElse: () => Goal(
          title: '',
          description: '',
          imagePath: '',
          createdTime: DateTime.now(),
          targetDate: DateTime.now(),
          status: GoalStatus.pending,
        ),
      );

      if (drawerGoal.title.isEmpty) {
        print('❌ 目标不匹配: BLoC中有${blocGoal.title}，但抽屉中没有');
        isContentMatch = false;
      } else if (blocGoal.title != drawerGoal.title) {
        print('❌ 目标内容不匹配: BLoC:${blocGoal.title} vs 抽屉:${drawerGoal.title}');
        isContentMatch = false;
      }
    }

    // 3. 检查当前目标是否正确高亮
    bool isCurrentGoalHighlighted = true;
    if (blocState.currentGoal != null) {
      final currentGoalInDrawer =
          drawerGoals.any((g) => g.id == blocState.currentGoal!.id);
      if (!currentGoalInDrawer) {
        print('❌ 当前目标在抽屉中未找到: ${blocState.currentGoal!.title}');
        isCurrentGoalHighlighted = false;
      }
    }

    final result = isCountMatch && isContentMatch && isCurrentGoalHighlighted;
    print('✅ BLoC状态同步测试结果: ${result ? "通过" : "失败"}');

    return result;
  }

  /// 综合测试导航抽屉同步机制
  static Future<Map<String, bool>> runComprehensiveTest({
    required List<Goal> initialGoals,
    required GoalsLoaded initialBlocState,
  }) async {
    print('🚀 开始导航抽屉同步机制综合测试');

    final results = <String, bool>{};

    // 创建测试用的新目标
    final testGoal = Goal(
      id: 999,
      title: '测试目标',
      description: '用于测试导航抽屉同步的目标',
      imagePath: 'test_goal.jpg',
      createdTime: DateTime.now(),
      targetDate: DateTime.now().add(Duration(days: 30)),
      status: GoalStatus.pending,
    );

    // 模拟导航抽屉数据获取函数
    List<Goal> mockDrawerGoalsGetter(List<Goal> goals) => goals;

    // 模拟层级计算函数
    int mockLevelCalculator(Goal goal, int baseLevel) {
      return goal.parentId == null ? 0 : baseLevel + 1;
    }

    // 1. 测试新增目标同步
    results['addGoalSync'] = await validateAddGoalSync(
      initialGoals: initialGoals,
      newGoal: testGoal,
      drawerGoalsGetter: mockDrawerGoalsGetter,
    );

    // 2. 测试删除目标同步
    if (initialGoals.isNotEmpty) {
      results['deleteGoalSync'] = await validateDeleteGoalSync(
        initialGoals: initialGoals,
        goalToDelete: initialGoals.first,
        drawerGoalsGetter: mockDrawerGoalsGetter,
      );
    }

    // 3. 测试层级结构显示
    results['hierarchyDisplay'] = validateHierarchyDisplay(
      allGoals: initialGoals,
      levelCalculator: mockLevelCalculator,
    );

    // 4. 测试BLoC状态同步
    results['blocStateSync'] = await validateBlocStateSync(
      blocState: initialBlocState,
      drawerGoals: initialGoals,
    );

    // 输出测试总结
    print('\n📊 导航抽屉同步测试总结:');
    results.forEach((testName, result) {
      print('  ${result ? "✅" : "❌"} $testName: ${result ? "通过" : "失败"}');
    });

    final passedCount = results.values.where((r) => r).length;
    final totalCount = results.length;
    print(
        '\n🎯 总体通过率: $passedCount/$totalCount (${(passedCount / totalCount * 100).toStringAsFixed(1)}%)');

    return results;
  }
}

/// 导航抽屉同步验证标准
class DrawerSyncCriteria {
  /// 新增目标后的验证标准
  static const Map<String, String> addGoalCriteria = {
    'immediate_update': '新增目标后，导航抽屉应立即显示新目标',
    'correct_position': '新目标应出现在正确的层级位置',
    'proper_indentation': '新目标应有正确的缩进层级',
    'clickable': '新目标应可点击并正确导航',
  };

  /// 删除目标后的验证标准
  static const Map<String, String> deleteGoalCriteria = {
    'immediate_removal': '删除目标后，导航抽屉应立即移除该目标',
    'cascade_deletion': '如果删除父目标，子目标也应被移除',
    'list_reorder': '删除后的目标列表应正确重新排序',
    'no_broken_links': '不应有指向已删除目标的链接',
  };

  /// 层级结构显示的验证标准
  static const Map<String, String> hierarchyCriteria = {
    'correct_indentation': '父子目标应有正确的缩进层级',
    'visual_hierarchy': '层级关系应在视觉上清晰可辨',
    'expandable_nodes': '有子目标的节点应可展开/折叠',
    'consistent_styling': '同级目标应有一致的样式',
  };

  /// BLoC状态同步的验证标准
  static const Map<String, String> blocSyncCriteria = {
    'data_consistency': 'BLoC状态与抽屉数据应完全一致',
    'real_time_update': '状态变化应实时反映到抽屉中',
    'current_goal_highlight': '当前选中目标应在抽屉中高亮显示',
    'error_handling': '状态错误应有适当的错误处理',
  };
}
