import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/transaction/complex_operation_analysis.dart';
import 'package:linzaivision_primary/models/goal.dart';

/// 复杂操作分析测试
void main() {
  group('复杂操作场景分析测试', () {
    late Goal testGoal;
    late Goal parentGoal;
    late Goal childGoal1;
    late Goal childGoal2;

    setUp(() {
      // 创建测试数据
      parentGoal = Goal(
        id: 1,
        title: '父目标',
        description: '这是一个父目标',
        imagePath: 'test_image.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
      );

      childGoal1 = Goal(
        id: 2,
        title: '子目标1',
        description: '这是第一个子目标',
        imagePath: 'test_image1.jpg',
        createdTime: DateTime.now(),
        parentId: 1,
        status: GoalStatus.pending,
      );

      childGoal2 = Goal(
        id: 3,
        title: '子目标2',
        description: '这是第二个子目标',
        imagePath: 'test_image2.jpg',
        createdTime: DateTime.now(),
        parentId: 1,
        status: GoalStatus.pending,
      );

      testGoal = Goal(
        id: 1,
        title: '测试目标',
        description: '这是一个测试目标',
        imagePath: 'test_image.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
        subGoals: [childGoal1, childGoal2],
      );
    });

    group('目标删除操作分析', () {
      test('应该正确分析简单目标删除的影响', () {
        final simpleGoal = Goal(
          id: 100,
          title: '简单目标',
          description: '没有子目标的简单目标',
          imagePath: 'simple_goal.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        );

        final result = ComplexOperationAnalysis.analyzeGoalDeletion(simpleGoal);

        expect(result.operationType, equals(ComplexOperationType.goalDeletion));
        expect(result.effects.length, greaterThan(5));
        expect(result.riskLevel,
            isIn([RiskLevel.low, RiskLevel.medium, RiskLevel.high]));
        expect(result.totalEstimatedDuration.inMilliseconds, greaterThan(0));
      });

      test('应该正确分析带子目标的目标删除影响', () {
        final result = ComplexOperationAnalysis.analyzeGoalDeletion(testGoal);

        expect(result.operationType, equals(ComplexOperationType.goalDeletion));
        expect(result.effects.length, greaterThan(6));

        // 应该包含级联删除效应
        final cascadeEffects = result.effects
            .where((effect) => effect.type == EffectType.cascadeOperation);
        expect(cascadeEffects.length, greaterThan(0));

        // 风险级别应该较高
        expect(result.riskLevel, isIn([RiskLevel.medium, RiskLevel.high]));
        expect(result.rollbackComplexity, equals(RollbackComplexity.high));
      });

      test('应该正确识别关键路径效应', () {
        final result = ComplexOperationAnalysis.analyzeGoalDeletion(testGoal);
        final criticalEffects = result.getCriticalPathEffects();

        expect(criticalEffects.length, greaterThan(0));

        // 关键路径应该包含强一致性或立即一致性的效应
        for (final effect in criticalEffects) {
          expect(effect.consistency,
              isIn([ConsistencyLevel.strong, ConsistencyLevel.immediate]));
        }
      });

      test('应该正确分组并行执行的效应', () {
        final result = ComplexOperationAnalysis.analyzeGoalDeletion(testGoal);
        final parallelGroups = result.getParallelExecutionGroups();

        expect(parallelGroups.length, greaterThan(0));

        // 每个组都应该有至少一个效应
        for (final group in parallelGroups) {
          expect(group.length, greaterThan(0));
        }
      });
    });

    group('目标更新操作分析', () {
      test('应该正确分析简单属性更新', () {
        final oldGoal = testGoal;
        final newGoal = testGoal.copyWith(title: '更新后的标题');

        final result =
            ComplexOperationAnalysis.analyzeGoalUpdate(oldGoal, newGoal);

        expect(result.operationType, equals(ComplexOperationType.goalUpdate));
        expect(result.effects.length, greaterThanOrEqualTo(2));
        expect(result.riskLevel, isIn([RiskLevel.low, RiskLevel.medium]));
      });

      test('应该正确分析状态变更的影响', () {
        final oldGoal = testGoal;
        final newGoal = testGoal.copyWith(status: GoalStatus.completed);

        final result =
            ComplexOperationAnalysis.analyzeGoalUpdate(oldGoal, newGoal);

        // 状态变更应该包含状态传播效应
        final statusEffects = result.effects
            .where((effect) => effect.type == EffectType.statusPropagation);
        expect(statusEffects.length, greaterThan(0));
      });

      test('应该正确分析层级结构变更', () {
        final oldGoal = testGoal;
        final newGoal = testGoal.copyWith(parentId: 999);

        final result =
            ComplexOperationAnalysis.analyzeGoalUpdate(oldGoal, newGoal);

        // 层级变更应该包含层级重构效应
        final hierarchyEffects = result.effects
            .where((effect) => effect.type == EffectType.hierarchyRestructure);
        expect(hierarchyEffects.length, greaterThan(0));
      });
    });

    group('跨页面同步分析', () {
      test('应该正确分析跨页面同步的复杂性', () {
        final result = ComplexOperationAnalysis.analyzeCrossPageSync();

        expect(
            result.operationType, equals(ComplexOperationType.crossPageSync));
        expect(result.effects.length, greaterThan(3));
        expect(result.riskLevel,
            isIn([RiskLevel.low, RiskLevel.medium, RiskLevel.high]));
        expect(result.rollbackComplexity, equals(RollbackComplexity.low));
      });

      test('应该包含状态检测和数据同步效应', () {
        final result = ComplexOperationAnalysis.analyzeCrossPageSync();

        final stateDetectionEffects = result.effects
            .where((effect) => effect.type == EffectType.stateDetection);
        expect(stateDetectionEffects.length, greaterThan(0));

        final syncEffects = result.effects
            .where((effect) => effect.type == EffectType.batchStateUpdate);
        expect(syncEffects.length, greaterThan(0));
      });
    });

    group('操作场景映射测试', () {
      test('应该正确映射已知的操作场景', () {
        final scenarios = OperationScenarioMapping.scenarioMapping.keys;

        expect(scenarios, contains('goal_deletion_with_children'));
        expect(scenarios, contains('goal_status_change_cascade'));
        expect(scenarios, contains('goalpage_to_explore_sync'));
        expect(scenarios, contains('drawer_navigation_sync'));
        expect(scenarios, contains('app_initialization'));
      });

      test('应该能够获取具体场景的分析结果', () {
        final result = OperationScenarioMapping.getScenarioAnalysis(
            'goal_deletion_with_children');

        expect(result.operationType, equals(ComplexOperationType.goalDeletion));
        expect(result.effects.length, greaterThan(5));
        expect(result.totalEstimatedDuration.inMilliseconds, greaterThan(300));
      });

      test('应该正确分析目标状态变更级联场景', () {
        final result = OperationScenarioMapping.getScenarioAnalysis(
            'goal_status_change_cascade');

        expect(result.operationType,
            equals(ComplexOperationType.goalStatusChange));
        expect(result.riskLevel, equals(RiskLevel.medium));
        expect(result.rollbackComplexity, equals(RollbackComplexity.medium));
      });

      test('应该正确分析导航抽屉同步场景', () {
        final result = OperationScenarioMapping.getScenarioAnalysis(
            'drawer_navigation_sync');

        expect(
            result.operationType, equals(ComplexOperationType.crossPageSync));
        expect(result.riskLevel, equals(RiskLevel.low));
        expect(result.totalEstimatedDuration.inMilliseconds, lessThan(100));
      });

      test('应该正确分析应用初始化场景', () {
        final result =
            OperationScenarioMapping.getScenarioAnalysis('app_initialization');

        expect(result.operationType,
            equals(ComplexOperationType.dataImportExport));
        expect(result.riskLevel, equals(RiskLevel.high));
        expect(result.rollbackComplexity, equals(RollbackComplexity.high));
        expect(result.totalEstimatedDuration.inMilliseconds, greaterThan(700));
      });

      test('应该抛出异常当场景未知时', () {
        expect(
          () =>
              OperationScenarioMapping.getScenarioAnalysis('unknown_scenario'),
          throwsArgumentError,
        );
      });
    });

    group('效应类型和属性测试', () {
      test('应该正确设置效应属性', () {
        final effect = OperationEffect(
          type: EffectType.databaseOperation,
          description: '测试数据库操作',
          scope: OperationScope.local,
          consistency: ConsistencyLevel.strong,
          dependencies: ['test_dependency'],
          estimatedDuration: const Duration(milliseconds: 100),
        );

        expect(effect.type, equals(EffectType.databaseOperation));
        expect(effect.description, equals('测试数据库操作'));
        expect(effect.scope, equals(OperationScope.local));
        expect(effect.consistency, equals(ConsistencyLevel.strong));
        expect(effect.dependencies, contains('test_dependency'));
        expect(effect.estimatedDuration.inMilliseconds, equals(100));
      });

      test('应该正确计算总执行时间', () {
        final effects = [
          OperationEffect(
            type: EffectType.databaseOperation,
            description: '操作1',
            scope: OperationScope.local,
            consistency: ConsistencyLevel.strong,
            dependencies: [],
            estimatedDuration: const Duration(milliseconds: 100),
          ),
          OperationEffect(
            type: EffectType.uiStateSync,
            description: '操作2',
            scope: OperationScope.local,
            consistency: ConsistencyLevel.immediate,
            dependencies: ['operation1'],
            estimatedDuration: const Duration(milliseconds: 50),
          ),
        ];

        final result = OperationAnalysisResult(
          operationType: ComplexOperationType.goalUpdate,
          effects: effects,
          totalEstimatedDuration: const Duration(milliseconds: 150),
          riskLevel: RiskLevel.medium,
          rollbackComplexity: RollbackComplexity.medium,
        );

        expect(result.totalEstimatedDuration.inMilliseconds, equals(150));
        expect(result.effects.length, equals(2));
      });
    });
  });
}
