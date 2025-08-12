import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/utils/component_state_manager.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/explore/explore_bloc.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/models/goal.dart';

/// 简化的组件状态传递机制验证测试
void main() {
  group('组件状态传递机制基础验证', () {
    late GoalRepository goalRepository;
    late ExploreRepository exploreRepository;
    late GoalBloc goalBloc;
    late ExploreBloc exploreBloc;
    
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
    });
    
    tearDown(() {
      goalBloc.close();
      exploreBloc.close();
    });
    
    test('ComponentStateManager 基础功能测试', () async {
      // 创建ComponentStateManager
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        pageName: 'test',
      );
      
      // 验证初始化状态
      expect(stateManager.isInitialized, isTrue);
      expect(stateManager.isDisposed, isFalse);
      
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
      expect(listenerCalled, isTrue);
      expect(stateManager.getState<String>(testKey), equals('new_value'));
      
      // 测试事件分发
      expect(() {
        stateManager.dispatchGoalEvent(const LoadGoals());
      }, returnsNormally);
      
      // 清理
      stateManager.dispose();
      expect(stateManager.isDisposed, isTrue);
    });
    
    test('ComponentStateKeys 常量定义测试', () {
      // 验证所有关键状态键都已定义
      expect(ComponentStateKeys.currentGoal, equals('currentGoal'));
      expect(ComponentStateKeys.goals, equals('goals'));
      expect(ComponentStateKeys.allGoals, equals('allGoals'));
      expect(ComponentStateKeys.isEditingTitle, equals('isEditingTitle'));
      expect(ComponentStateKeys.isEditingDescription, equals('isEditingDescription'));
      expect(ComponentStateKeys.viewMode, equals('viewMode'));
      expect(ComponentStateKeys.showCountdown, equals('showCountdown'));
      expect(ComponentStateKeys.showTime, equals('showTime'));
      expect(ComponentStateKeys.showDescription, equals('showDescription'));
      expect(ComponentStateKeys.showTitle, equals('showTitle'));
      expect(ComponentStateKeys.isLoading, equals('isLoading'));
      expect(ComponentStateKeys.error, equals('error'));
    });
    
    test('状态管理器生命周期测试', () {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        pageName: 'lifecycle_test',
      );
      
      // 验证初始状态
      expect(stateManager.isInitialized, isTrue);
      expect(stateManager.isDisposed, isFalse);
      
      // 设置一些状态
      stateManager.setState('test1', 'value1');
      stateManager.setState('test2', 42);
      stateManager.setState('test3', true);
      
      expect(stateManager.getState<String>('test1'), equals('value1'));
      expect(stateManager.getState<int>('test2'), equals(42));
      expect(stateManager.getState<bool>('test3'), equals(true));
      
      // 释放资源
      stateManager.dispose();
      expect(stateManager.isDisposed, isTrue);
      
      // 释放后的操作应该被忽略
      stateManager.setState('test4', 'should_be_ignored');
      expect(stateManager.getState<String>('test4'), isNull);
    });
    
    test('BLoC状态同步测试', () async {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        pageName: 'bloc_sync_test',
      );
      
      // 创建测试目标
      final testGoal = Goal(
        title: '测试目标',
        description: '测试描述',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );
      
      // 监听状态变化
      bool goalsStateChanged = false;
      stateManager.addStateListener(ComponentStateKeys.goals, () {
        goalsStateChanged = true;
      });
      
      // 分发添加目标事件
      stateManager.dispatchGoalEvent(AddGoal(testGoal));
      
      // 等待BLoC处理
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证状态管理器能够正确处理事件分发
      expect(() {
        stateManager.dispatchGoalEvent(const LoadGoals());
      }, returnsNormally);
      
      stateManager.dispose();
    });
    
    test('错误处理测试', () {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        pageName: 'error_test',
      );
      
      // 测试错误状态设置
      stateManager.setState(ComponentStateKeys.error, '测试错误');
      expect(stateManager.getState<String>(ComponentStateKeys.error), equals('测试错误'));
      
      // 测试加载状态
      stateManager.setState(ComponentStateKeys.isLoading, true);
      expect(stateManager.getState<bool>(ComponentStateKeys.isLoading), isTrue);
      
      stateManager.setState(ComponentStateKeys.isLoading, false);
      expect(stateManager.getState<bool>(ComponentStateKeys.isLoading), isFalse);
      
      stateManager.dispose();
    });
    
    test('多监听器管理测试', () {
      final stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        pageName: 'multi_listener_test',
      );
      
      int listener1CallCount = 0;
      int listener2CallCount = 0;
      int listener3CallCount = 0;
      
      void listener1() => listener1CallCount++;
      void listener2() => listener2CallCount++;
      void listener3() => listener3CallCount++;
      
      // 添加多个监听器
      stateManager.addStateListener('test_key', listener1);
      stateManager.addStateListener('test_key', listener2);
      stateManager.addStateListener('other_key', listener3);
      
      // 触发test_key的变化
      stateManager.setState('test_key', 'value1');
      expect(listener1CallCount, equals(1));
      expect(listener2CallCount, equals(1));
      expect(listener3CallCount, equals(0));
      
      // 触发other_key的变化
      stateManager.setState('other_key', 'value2');
      expect(listener1CallCount, equals(1));
      expect(listener2CallCount, equals(1));
      expect(listener3CallCount, equals(1));
      
      // 移除一个监听器
      stateManager.removeStateListener('test_key', listener1);
      stateManager.setState('test_key', 'value3');
      expect(listener1CallCount, equals(1)); // 不应该增加
      expect(listener2CallCount, equals(2)); // 应该增加
      
      stateManager.dispose();
    });
  });
}
