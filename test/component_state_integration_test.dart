import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linzaivision_primary/utils/component_state_manager.dart';
import 'package:linzaivision_primary/widgets/component_state_provider.dart';
import 'package:linzaivision_primary/widgets/goal_status_badge.dart';
import 'package:linzaivision_primary/pages/component_state_test_page.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/explore/explore_bloc.dart';
import 'package:linzaivision_primary/bloc/shared/shared_state_bloc.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/models/goal.dart';

/// 组件状态传递机制集成测试
///
/// 验证新的组件状态传递机制的正确性和有效性
void main() {
  group('组件状态传递机制集成测试', () {
    late GoalRepository goalRepository;
    late ExploreRepository exploreRepository;
    late GoalBloc goalBloc;
    late ExploreBloc exploreBloc;
    late SharedStateBloc sharedStateBloc;

    setUp(() {
      // 创建测试用的Repository
      final databaseHelper = DatabaseHelper(isTest: true);
      goalRepository = GoalRepositoryImpl(databaseHelper);
      exploreRepository = ExploreRepositoryImpl();

      // 创建BLoC实例
      goalBloc = GoalBloc(repository: goalRepository);
      exploreBloc = ExploreBloc(
        exploreRepository: exploreRepository,
        goalRepository: goalRepository,
      );
      sharedStateBloc = SharedStateBloc(
        goalRepository: goalRepository,
        exploreRepository: exploreRepository,
      );
    });

    tearDown(() {
      goalBloc.close();
      exploreBloc.close();
      sharedStateBloc.close();
    });

    testWidgets('ComponentStateManager 基础功能测试', (WidgetTester tester) async {
      // 创建ComponentStateManager
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'test',
      );

      // 测试状态设置和获取
      const testKey = 'test_key';
      const testValue = 'test_value';

      stateManager.setState(testKey, testValue);
      expect(stateManager.getState<String>(testKey), equals(testValue));

      // 测试状态监听
      bool listenerCalled = false;
      stateManager.addStateListener(testKey, () {
        listenerCalled = true;
      });

      stateManager.setState(testKey, 'new_value');
      await tester.pump();

      expect(listenerCalled, isTrue);
      expect(stateManager.getState<String>(testKey), equals('new_value'));

      stateManager.dispose();
    });

    testWidgets('ComponentStateProvider 组件树集成测试', (WidgetTester tester) async {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'test',
      );

      bool builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ComponentStateProvider(
            stateManager: stateManager,
            child: ComponentStateBuilder(
              builder: (context, manager) {
                builderCalled = true;
                expect(manager, equals(stateManager));
                return const Text('Test');
              },
            ),
          ),
        ),
      );

      expect(builderCalled, isTrue);
      expect(find.text('Test'), findsOneWidget);

      stateManager.dispose();
    });

    testWidgets('GoalStatusBadge 新旧状态管理对比测试', (WidgetTester tester) async {
      final testGoal = Goal(
        id: 1,
        title: '测试目标',
        description: '测试描述',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'test',
      );

      // 设置当前目标
      stateManager.setState(ComponentStateKeys.currentGoal, testGoal);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComponentStateProvider(
              stateManager: stateManager,
              child: Column(
                children: [
                  // 传统方式
                  GoalStatusBadge(
                    goal: testGoal,
                    useNewStateManagement: false,
                  ),
                  // 新状态管理方式
                  const GoalStatusBadge(
                    useNewStateManagement: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 验证两个徽章都显示正确的状态
      expect(find.text('待开始'), findsNWidgets(2));
      expect(find.byIcon(Icons.schedule), findsNWidgets(2));

      // 验证新状态管理徽章有特殊标识
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      stateManager.dispose();
    });

    testWidgets('ComponentStateConsumer 状态监听测试', (WidgetTester tester) async {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'test',
      );

      final testGoal = Goal(
        id: 1,
        title: '测试目标',
        description: '测试描述',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComponentStateProvider(
              stateManager: stateManager,
              child: ComponentStateConsumer<Goal>(
                stateKey: ComponentStateKeys.currentGoal,
                builder: (context, goal) {
                  if (goal == null) {
                    return const Text('未选择目标');
                  }
                  return Text('当前目标: ${goal.title}');
                },
              ),
            ),
          ),
        ),
      );

      // 初始状态
      expect(find.text('未选择目标'), findsOneWidget);

      // 设置目标
      stateManager.setState(ComponentStateKeys.currentGoal, testGoal);
      await tester.pump();

      // 验证状态更新
      expect(find.text('当前目标: 测试目标'), findsOneWidget);
      expect(find.text('未选择目标'), findsNothing);

      stateManager.dispose();
    });

    testWidgets('AutoComponentStateProvider 自动创建测试',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: goalBloc),
              BlocProvider.value(value: exploreBloc),
              BlocProvider.value(value: sharedStateBloc),
            ],
            child: const AutoComponentStateProvider(
              pageName: 'auto_test',
              child: ComponentStateBuilder(
                builder: _testBuilder,
              ),
            ),
          ),
        ),
      );

      // 验证自动创建的状态管理器可用
      expect(find.text('状态管理器可用'), findsOneWidget);
    });

    testWidgets('状态同步性能测试', (WidgetTester tester) async {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'performance_test',
      );

      // 创建多个监听器
      final listeners = <VoidCallback>[];
      int callCount = 0;

      for (int i = 0; i < 100; i++) {
        final listener = () => callCount++;
        listeners.add(listener);
        stateManager.addStateListener('test_key', listener);
      }

      final stopwatch = Stopwatch()..start();

      // 快速更新状态
      for (int i = 0; i < 10; i++) {
        stateManager.setState('test_key', 'value_$i');
        await tester.pump(const Duration(milliseconds: 1));
      }

      stopwatch.stop();

      // 验证性能（应该在合理时间内完成）
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      // 验证防抖机制（由于防抖，实际调用次数应该少于预期）
      expect(callCount, lessThan(1000)); // 100个监听器 * 10次更新 = 1000次

      // 清理
      for (final listener in listeners) {
        stateManager.removeStateListener('test_key', listener);
      }

      stateManager.dispose();
    });

    testWidgets('错误处理测试', (WidgetTester tester) async {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: 'error_test',
      );

      // 测试无效事件处理
      expect(() {
        stateManager.dispatchGoalEvent(const LoadGoals(parentId: -1));
      }, returnsNormally);

      // 测试状态管理器释放后的操作
      stateManager.dispose();

      expect(() {
        stateManager.setState('test', 'value');
      }, returnsNormally); // 应该优雅处理，不抛出异常

      expect(stateManager.isDisposed, isTrue);
    });
  });
}

Widget _testBuilder(BuildContext context, ComponentStateManager stateManager) {
  return Text(stateManager.isInitialized ? '状态管理器可用' : '状态管理器不可用');
}
