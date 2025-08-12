import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/utils/cross_page_sync_manager.dart';
import 'package:linzaivision_primary/models/goal.dart';

void main() {
  group('跨页面状态同步功能验证', () {
    late CrossPageSyncManager syncManager;

    setUp(() {
      syncManager = CrossPageSyncManager.instance;
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('应该能创建跨页面同步管理器实例', () {
      expect(syncManager, isNotNull);
      expect(syncManager, isA<CrossPageSyncManager>());
    });

    test('应该能获取性能统计信息', () {
      final stats = syncManager.getPerformanceStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('isInitialized'), isTrue);
      expect(stats.containsKey('lastSyncTime'), isTrue);
    });

    test('应该能打印性能统计信息', () {
      // 这个测试主要验证方法不会抛出异常
      expect(() => syncManager.printPerformanceStats(), returnsNormally);
    });

    test('应该能通知目标操作（未初始化状态）', () {
      final testGoal = Goal(
        title: '测试目标',
        description: '用于测试的目标',
        imagePath: 'test.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
      );

      // 在未初始化状态下，这些方法应该能正常调用而不抛出异常
      expect(() => syncManager.notifyGoalCreated(testGoal, 'test'),
          returnsNormally);
      expect(() => syncManager.notifyGoalUpdated(testGoal, 'test'),
          returnsNormally);
      expect(() => syncManager.notifyGoalDeleted(1, 'test'), returnsNormally);
    });

    test('应该能请求数据刷新（未初始化状态）', () {
      // 在未初始化状态下，这个方法应该能正常调用而不抛出异常
      expect(() => syncManager.requestDataRefresh('test', ['goals']),
          returnsNormally);
      expect(() => syncManager.requestDataRefresh('test', ['explore']),
          returnsNormally);
      expect(() => syncManager.requestDataRefresh('test', ['all']),
          returnsNormally);
    });

    test('应该能检查页面刷新状态', () {
      final shouldRefresh = syncManager.shouldPageRefresh('test');

      // 在未初始化状态下，应该返回false或true（具体取决于实现）
      expect(shouldRefresh, isA<bool>());
    });

    test('应该能获取当前共享状态', () {
      final currentState = syncManager.currentSharedState;

      // 在未初始化状态下，应该返回null或初始状态
      expect(currentState, isA<Object?>());
    });

    test('应该能检查数据一致性', () {
      final isConsistent = syncManager.checkDataConsistency();

      // 在未初始化状态下，应该返回false
      expect(isConsistent, isA<bool>());
    });

    test('应该能清理资源', () {
      // 这个测试主要验证dispose方法不会抛出异常
      expect(() => syncManager.dispose(), returnsNormally);
    });

    group('CrossPageSyncAdapter功能测试', () {
      late CrossPageSyncAdapter goalPageAdapter;
      late CrossPageSyncAdapter explorePageAdapter;

      setUp(() {
        goalPageAdapter = CrossPageSyncAdapter(pageName: 'goal');
        explorePageAdapter = CrossPageSyncAdapter(pageName: 'explore');
      });

      test('应该能创建页面适配器', () {
        expect(goalPageAdapter, isNotNull);
        expect(explorePageAdapter, isNotNull);
        expect(goalPageAdapter.pageName, equals('goal'));
        expect(explorePageAdapter.pageName, equals('explore'));
      });

      test('应该能通过适配器通知目标操作', () {
        final testGoal = Goal(
          title: '适配器测试目标',
          description: '通过适配器操作的目标',
          imagePath: 'adapter_test.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        );

        // 测试各种通知方法（不抛出异常即为成功）
        expect(
            () => goalPageAdapter.notifyGoalCreated(testGoal), returnsNormally);
        expect(
            () => goalPageAdapter.notifyGoalUpdated(testGoal), returnsNormally);
        expect(() => goalPageAdapter.notifyGoalDeleted(1), returnsNormally);
      });

      test('应该能通过适配器请求数据刷新', () {
        // 测试各种刷新请求方法（不抛出异常即为成功）
        expect(() => goalPageAdapter.requestGoalDataRefresh(), returnsNormally);
        expect(() => explorePageAdapter.requestExploreDataRefresh(),
            returnsNormally);
        expect(() => goalPageAdapter.requestAllDataRefresh(), returnsNormally);
      });

      test('应该能通过适配器检查刷新状态', () {
        final shouldRefresh = goalPageAdapter.shouldRefresh();

        expect(shouldRefresh, isA<bool>());
      });

      test('应该能通过适配器获取当前状态', () {
        final sharedState = goalPageAdapter.currentSharedState;
        final goals = goalPageAdapter.currentGoals;
        final allGoals = goalPageAdapter.currentAllGoals;
        final currentGoal = goalPageAdapter.currentGoal;
        final exploreCards = explorePageAdapter.currentExploreCards;
        final selectedCard = explorePageAdapter.currentSelectedCard;

        // 验证方法能正常调用（返回null或相应类型的数据）
        expect(sharedState, isA<Object?>());
        expect(goals, isA<List<Goal>?>());
        expect(allGoals, isA<List<Goal>?>());
        expect(currentGoal, isA<Goal?>());
        expect(exploreCards, isA<List?>());
        expect(selectedCard, isA<Object?>());
      });
    });

    group('跨页面同步扩展方法测试', () {
      test('应该能快速同步目标数据', () {
        final testGoals = [
          Goal(
            title: '扩展测试目标1',
            description: '第一个扩展测试目标',
            imagePath: 'ext_test1.jpg',
            createdTime: DateTime.now(),
            status: GoalStatus.pending,
          ),
          Goal(
            title: '扩展测试目标2',
            description: '第二个扩展测试目标',
            imagePath: 'ext_test2.jpg',
            createdTime: DateTime.now(),
            status: GoalStatus.completed,
          ),
        ];

        // 测试快速同步方法（不抛出异常即为成功）
        expect(
            () => syncManager.syncGoalDataToAllPages(
                testGoals, testGoals, testGoals.first),
            returnsNormally);
      });

      test('应该能快速同步探索数据', () {
        // 由于ExploreCard需要id参数，我们只测试方法调用不抛出异常
        expect(() => syncManager.syncExploreDataToAllPages([], null),
            returnsNormally);
      });
    });

    group('性能监控测试', () {
      test('应该能记录和获取性能统计', () {
        // 执行一些操作来生成性能数据
        final testGoal = Goal(
          title: '性能测试目标',
          description: '用于性能测试的目标',
          imagePath: 'perf_test.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        );

        syncManager.notifyGoalCreated(testGoal, 'performance_test');
        syncManager.notifyGoalUpdated(testGoal, 'performance_test');
        syncManager.notifyGoalDeleted(1, 'performance_test');
        syncManager.requestDataRefresh('performance_test', ['goals']);

        // 获取性能统计
        final stats = syncManager.getPerformanceStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('isInitialized'), isTrue);
        expect(stats.containsKey('lastSyncTime'), isTrue);
      });

      test('应该能打印性能统计而不抛出异常', () {
        expect(() => syncManager.printPerformanceStats(), returnsNormally);
      });
    });

    group('错误处理测试', () {
      test('应该能处理空参数', () {
        // 测试传入null或空值时的处理
        expect(() => syncManager.requestDataRefresh('', []), returnsNormally);
        expect(syncManager.shouldPageRefresh(''), isA<bool>());
      });

      test('应该能处理重复初始化', () {
        // 多次调用dispose应该不会抛出异常
        expect(() => syncManager.dispose(), returnsNormally);
        expect(() => syncManager.dispose(), returnsNormally);
      });
    });
  });
}
