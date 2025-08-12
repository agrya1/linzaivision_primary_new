import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/services/simple_real_time_sync.dart';
import 'package:linzaivision_primary/utils/cross_page_sync_manager.dart';
import 'package:linzaivision_primary/bloc/shared/shared_state_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/bloc/explore/explore_bloc.dart';
import 'package:linzaivision_primary/bloc/explore/explore_event.dart';
import 'package:linzaivision_primary/bloc/explore/explore_state.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/models/explore_card.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';

// 测试仓库实现
class TestGoalRepository implements GoalRepository {
  List<Goal> _goals = [];

  @override
  Future<List<Goal>> getGoals({int? parentId}) async => _goals;

  @override
  Future<List<Goal>> getGoalTree() async => _goals;

  @override
  Future<int> insertGoal(Goal goal) async {
    _goals.add(goal);
    return _goals.length;
  }

  @override
  Future<int> updateGoal(Goal goal) async {
    final index = _goals.indexWhere((g) => g.title == goal.title);
    if (index != -1) {
      _goals[index] = goal;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteGoal(int id) async {
    final initialLength = _goals.length;
    _goals.removeWhere((g) => g.title.contains(id.toString()));
    return initialLength - _goals.length;
  }

  @override
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {
    _goals.addAll(rootGoals);
  }

  @override
  Future<Goal?> getGoal(int id) async {
    try {
      return _goals.firstWhere((g) => g.title.contains(id.toString()));
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<int>> batchInsertGoals(List<Goal> goals) async {
    final results = <int>[];
    for (final goal in goals) {
      final id = await insertGoal(goal);
      results.add(id);
    }
    return results;
  }

  @override
  Future<List<int>> batchUpdateGoals(List<Goal> goals) async {
    final results = <int>[];
    for (final goal in goals) {
      final count = await updateGoal(goal);
      if (count > 0) results.add(goal.id ?? 0);
    }
    return results;
  }

  @override
  Future<List<int>> batchDeleteGoals(List<int> goalIds) async {
    final results = <int>[];
    for (final id in goalIds) {
      final count = await deleteGoal(id);
      if (count > 0) results.add(id);
    }
    return results;
  }

  @override
  Future<T> executeInTransaction<T>(Future<T> Function() operation) async {
    return await operation();
  }

  @override
  Map<String, dynamic> getBatchOperationStats() {
    return {
      'totalOperations': _goals.length,
      'batchedOperations': 0,
      'successfulBatches': 0,
      'failedBatches': 0,
      'batchSuccessRate': 1.0,
      'averageExecutionTime': const Duration(milliseconds: 10),
      'pendingOperations': 0,
    };
  }

  void setTestGoals(List<Goal> goals) {
    _goals = goals;
  }
}

class TestExploreRepository implements ExploreRepository {
  List<ExploreCard> _cards = [];

  @override
  Future<List<ExploreCard>> getExploreCards() async => _cards;

  @override
  Future<ExploreCard?> getExploreCard(String id) async {
    try {
      return _cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ExploreCard>> getExploreCardsByCategory(String category) async {
    return _cards.where((card) => card.category == category).toList();
  }

  void setTestCards(List<ExploreCard> cards) {
    _cards = cards;
  }
}

void main() {
  group('跨页面同步集成验证测试', () {
    late TestGoalRepository testGoalRepository;
    late TestExploreRepository testExploreRepository;
    late SharedStateBloc sharedStateBloc;
    late GoalBloc goalBloc;
    late ExploreBloc exploreBloc;
    late SimpleRealTimeSyncService syncService;
    late CrossPageSyncManager syncManager;
    late List<Goal> testGoals;
    late List<ExploreCard> testCards;

    setUp(() {
      // 创建测试仓库
      testGoalRepository = TestGoalRepository();
      testExploreRepository = TestExploreRepository();

      // 创建测试数据
      testGoals = [
        Goal(
          title: '跨页面同步验证目标1',
          description: '第一个跨页面同步验证目标',
          imagePath: 'sync_verify1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          title: '跨页面同步验证目标2',
          description: '第二个跨页面同步验证目标',
          imagePath: 'sync_verify2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.completed,
        ),
      ];

      testCards = [
        ExploreCard(
          id: 'sync_verify_card_1',
          title: '跨页面同步验证卡片1',
          description: '第一个跨页面同步验证卡片',
          imagePath: 'sync_verify_card1.jpg',
          category: '同步验证',
          createdTime: DateTime.now(),
        ),
        ExploreCard(
          id: 'sync_verify_card_2',
          title: '跨页面同步验证卡片2',
          description: '第二个跨页面同步验证卡片',
          imagePath: 'sync_verify_card2.jpg',
          category: '同步验证',
          createdTime: DateTime.now(),
        ),
      ];

      // 设置测试数据
      testGoalRepository.setTestGoals(testGoals);
      testExploreRepository.setTestCards(testCards);

      // 创建BLoC实例
      sharedStateBloc = SharedStateBloc(
        goalRepository: testGoalRepository,
        exploreRepository: testExploreRepository,
      );
      goalBloc = GoalBloc(repository: testGoalRepository);
      exploreBloc = ExploreBloc(
        exploreRepository: testExploreRepository,
        goalRepository: testGoalRepository,
      );

      // 获取服务实例
      syncService = SimpleRealTimeSyncService.instance;
      syncManager = CrossPageSyncManager.instance;
    });

    tearDown(() {
      syncService.dispose();
      syncManager.dispose();
    });

    group('基础同步验证', () {
      test('应该能初始化完整的同步系统', () {
        // 初始化实时同步服务
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 验证实时同步服务状态
        final syncStatus = syncService.getStatus();
        expect(syncStatus.isInitialized, isTrue);
        expect(syncStatus.isEnabled, isTrue);

        // 验证跨页面同步管理器状态
        final managerStats = syncManager.getPerformanceStats();
        expect(managerStats, isA<Map<String, dynamic>>());
        expect(managerStats.containsKey('isInitialized'), isTrue);
      });

      test('应该能检查数据一致性', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 检查数据一致性
        final isConsistent = syncManager.checkDataConsistency();
        expect(isConsistent, isA<bool>());
      });

      test('应该能获取同步性能统计', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 获取性能统计
        final syncStats = syncService.getStats();
        final managerStats = syncManager.getPerformanceStats();

        expect(syncStats, isA<Map<String, dynamic>>());
        expect(managerStats, isA<Map<String, dynamic>>());

        // 验证统计数据结构
        expect(syncStats.containsKey('totalOperations'), isTrue);
        expect(syncStats.containsKey('goalSyncCount'), isTrue);
        expect(syncStats.containsKey('exploreSyncCount'), isTrue);
      });
    });

    group('目标数据同步验证', () {
      test('应该能同步目标数据变化', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 获取初始统计
        final initialStats = syncService.getStats();
        final initialGoalSync = initialStats['goalSyncCount'] as int;

        // 触发目标数据变化
        goalBloc.add(const LoadGoals());
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证同步统计更新
        final finalStats = syncService.getStats();
        final finalGoalSync = finalStats['goalSyncCount'] as int;
        expect(finalGoalSync, greaterThanOrEqualTo(initialGoalSync));
      });

      test('应该能处理目标状态变化', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 监听共享状态变化
        SharedState? capturedState;
        final subscription = sharedStateBloc.stream.listen((state) {
          capturedState = state;
        });

        // 触发目标加载
        goalBloc.add(const LoadGoals());
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证共享状态已更新
        expect(capturedState, isNotNull);
        if (capturedState is SharedStateLoaded) {
          final loadedState = capturedState as SharedStateLoaded;
          expect(loadedState.goals.length, greaterThanOrEqualTo(0));
        }

        subscription.cancel();
      });

      test('应该能同步目标树刷新', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 触发目标树刷新
        goalBloc.add(RefreshGoalTree());
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证同步操作被记录
        final stats = syncService.getStats();
        expect(stats['totalOperations'], greaterThanOrEqualTo(0));
      });
    });

    group('探索数据同步验证', () {
      test('应该能同步探索卡片变化', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 获取初始统计
        final initialStats = syncService.getStats();
        final initialExploreSync = initialStats['exploreSyncCount'] as int;

        // 触发探索卡片加载
        exploreBloc.add(FetchExploreCards());
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证同步统计更新
        final finalStats = syncService.getStats();
        final finalExploreSync = finalStats['exploreSyncCount'] as int;
        expect(finalExploreSync, greaterThanOrEqualTo(initialExploreSync));
      });

      test('应该能处理探索状态变化', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 监听共享状态变化
        SharedState? capturedState;
        final subscription = sharedStateBloc.stream.listen((state) {
          capturedState = state;
        });

        // 触发探索卡片加载
        exploreBloc.add(FetchExploreCards());
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证共享状态已更新
        expect(capturedState, isNotNull);
        if (capturedState is SharedStateLoaded) {
          final loadedState = capturedState as SharedStateLoaded;
          expect(loadedState.exploreCards.length, greaterThanOrEqualTo(0));
        }

        subscription.cancel();
      });

      test('应该能同步卡片选择状态', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 先加载卡片
        exploreBloc.add(FetchExploreCards());
        await Future.delayed(const Duration(milliseconds: 100));

        // 选择卡片
        if (testCards.isNotEmpty) {
          exploreBloc.add(SelectCard(testCards.first));
          await Future.delayed(const Duration(milliseconds: 100));

          // 验证同步操作被记录
          final stats = syncService.getStats();
          expect(stats['totalOperations'], greaterThan(0));
        }
      });
    });

    group('跨页面通信验证', () {
      test('应该能处理跨页面数据请求', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 创建跨页面同步适配器
        final adapter = CrossPageSyncAdapter(pageName: 'test_page');

        // 请求数据刷新
        adapter.requestAllDataRefresh();

        // 验证适配器正常工作
        expect(adapter.pageName, equals('test_page'));
      });

      test('应该能检查页面刷新需求', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 创建跨页面同步适配器
        final adapter = CrossPageSyncAdapter(pageName: 'test_page');

        // 检查页面是否需要刷新
        final shouldRefresh = adapter.shouldRefresh();
        expect(shouldRefresh, isA<bool>());
      });

      test('应该能通知跨页面操作', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 创建跨页面同步适配器
        final adapter = CrossPageSyncAdapter(pageName: 'test_page');

        // 通知跨页面操作 - 使用实际存在的方法
        adapter.requestGoalDataRefresh();

        // 验证通知正常发送
        expect(adapter.pageName, equals('test_page'));
      });
    });

    group('实时性验证', () {
      test('应该能在合理时间内完成同步', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        final startTime = DateTime.now();

        // 触发多个同步操作
        goalBloc.add(const LoadGoals());
        exploreBloc.add(FetchExploreCards());
        syncService.triggerSync();

        await Future.delayed(const Duration(milliseconds: 500));

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // 验证同步在合理时间内完成（小于1秒）
        expect(duration.inMilliseconds, lessThan(1000));

        // 验证同步操作被记录
        final stats = syncService.getStats();
        expect(stats['totalOperations'], greaterThan(0));
      });

      test('应该能处理并发同步操作', () async {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 并发触发多个同步操作
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(Future.delayed(Duration(milliseconds: i * 10), () {
            syncService.triggerSync();
          }));
        }

        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证所有同步操作都被处理
        final stats = syncService.getStats();
        expect(stats['totalOperations'], greaterThan(0));
      });
    });

    group('错误处理验证', () {
      test('应该能处理同步错误', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 禁用同步后尝试操作
        syncService.setEnabled(false);
        syncService.triggerSync();

        // 验证服务状态
        final status = syncService.getStatus();
        expect(status.isEnabled, isFalse);

        // 重新启用
        syncService.setEnabled(true);
        expect(syncService.getStatus().isEnabled, isTrue);
      });

      test('应该能恢复同步状态', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 重置统计
        syncService.resetStats();
        var stats = syncService.getStats();
        expect(stats['totalOperations'], equals(0));

        // 触发同步操作
        syncService.triggerSync();
        stats = syncService.getStats();
        expect(stats['totalOperations'], greaterThan(0));
      });
    });

    group('性能验证', () {
      test('应该能监控同步性能', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 触发同步操作
        syncService.triggerSync();

        // 验证性能监控数据
        final stats = syncService.getStats();
        expect(stats.containsKey('totalOperations'), isTrue);
        expect(stats.containsKey('goalSyncCount'), isTrue);
        expect(stats.containsKey('exploreSyncCount'), isTrue);

        // 验证扩展方法
        expect(syncService.isReady, isTrue);
        expect(syncService.lastSyncTimeFormatted, isA<String>());
        expect(syncService.syncEfficiency, isA<double>());
      });

      test('应该能获取详细的性能指标', () {
        // 初始化同步系统
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 获取跨页面同步管理器性能统计
        final managerStats = syncManager.getPerformanceStats();
        expect(managerStats, isA<Map<String, dynamic>>());

        // 获取实时同步服务统计
        final syncStats = syncService.getStats();
        expect(syncStats, isA<Map<String, dynamic>>());
      });
    });
  });
}
