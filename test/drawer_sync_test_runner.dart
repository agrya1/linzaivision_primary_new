import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import '../drawer_sync_test.dart';

void main() {
  group('DrawerSyncValidator Tests', () {
    late List<Goal> testGoals;
    late GoalsLoaded testBlocState;

    setUp(() {
      // 创建测试数据
      testGoals = [
        Goal(
          id: 1,
          title: '测试目标1',
          description: '第一个测试目标',
          imagePath: 'test1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          id: 2,
          title: '测试目标2',
          description: '第二个测试目标',
          imagePath: 'test2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.completed,
        ),
      ];

      testBlocState = GoalsLoaded(
        goals: testGoals,
        allGoals: testGoals,
        currentGoal: testGoals.first,
      );
    });

    test('应该能创建测试目标', () {
      expect(testGoals.length, equals(2));
      expect(testGoals.first.title, equals('测试目标1'));
      expect(testGoals.last.title, equals('测试目标2'));
    });

    test('应该能创建BLoC状态', () {
      expect(testBlocState.goals.length, equals(2));
      expect(testBlocState.currentGoal?.title, equals('测试目标1'));
    });

    test('应该能验证新增目标同步', () async {
      final newGoal = Goal(
        id: 3,
        title: '新增测试目标',
        description: '用于测试新增功能的目标',
        imagePath: 'new_test.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
      );

      final result = await DrawerSyncValidator.validateAddGoalSync(
        initialGoals: testGoals,
        newGoal: newGoal,
        drawerGoalsGetter: (goals) => goals,
      );

      expect(result, isTrue);
    });

    test('应该能验证删除目标同步', () async {
      final result = await DrawerSyncValidator.validateDeleteGoalSync(
        initialGoals: testGoals,
        goalToDelete: testGoals.first,
        drawerGoalsGetter: (goals) => goals,
      );

      expect(result, isTrue);
    });

    test('应该能验证层级结构显示', () {
      final result = DrawerSyncValidator.validateHierarchyDisplay(
        allGoals: testGoals,
        levelCalculator: (goal, baseLevel) => goal.parentId == null ? 0 : baseLevel + 1,
      );

      expect(result, isTrue);
    });

    test('应该能验证BLoC状态同步', () async {
      final result = await DrawerSyncValidator.validateBlocStateSync(
        blocState: testBlocState,
        drawerGoals: testGoals,
      );

      expect(result, isTrue);
    });

    test('应该能运行综合测试', () async {
      final results = await DrawerSyncValidator.runComprehensiveTest(
        initialGoals: testGoals,
        initialBlocState: testBlocState,
      );

      expect(results, isNotEmpty);
      expect(results.keys, contains('addGoalSync'));
      expect(results.keys, contains('deleteGoalSync'));
      expect(results.keys, contains('hierarchyDisplay'));
      expect(results.keys, contains('blocStateSync'));
    });
  });

  group('DrawerSyncCriteria Tests', () {
    test('应该包含新增目标验证标准', () {
      expect(DrawerSyncCriteria.addGoalCriteria, isNotEmpty);
      expect(DrawerSyncCriteria.addGoalCriteria.keys, contains('immediate_update'));
      expect(DrawerSyncCriteria.addGoalCriteria.keys, contains('correct_position'));
    });

    test('应该包含删除目标验证标准', () {
      expect(DrawerSyncCriteria.deleteGoalCriteria, isNotEmpty);
      expect(DrawerSyncCriteria.deleteGoalCriteria.keys, contains('immediate_removal'));
      expect(DrawerSyncCriteria.deleteGoalCriteria.keys, contains('cascade_deletion'));
    });

    test('应该包含层级结构验证标准', () {
      expect(DrawerSyncCriteria.hierarchyCriteria, isNotEmpty);
      expect(DrawerSyncCriteria.hierarchyCriteria.keys, contains('correct_indentation'));
      expect(DrawerSyncCriteria.hierarchyCriteria.keys, contains('visual_hierarchy'));
    });

    test('应该包含BLoC同步验证标准', () {
      expect(DrawerSyncCriteria.blocSyncCriteria, isNotEmpty);
      expect(DrawerSyncCriteria.blocSyncCriteria.keys, contains('data_consistency'));
      expect(DrawerSyncCriteria.blocSyncCriteria.keys, contains('real_time_update'));
    });
  });
}
