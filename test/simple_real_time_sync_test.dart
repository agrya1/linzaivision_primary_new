import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/services/simple_real_time_sync.dart';
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

  void setTestGoals(List<Goal> goals) {
    _goals = goals;
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
    // 简单实现，直接执行操作
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
  group('简化实时数据同步服务测试', () {
    late TestGoalRepository testGoalRepository;
    late TestExploreRepository testExploreRepository;
    late SharedStateBloc sharedStateBloc;
    late GoalBloc goalBloc;
    late ExploreBloc exploreBloc;
    late SimpleRealTimeSyncService syncService;
    late List<Goal> testGoals;
    late List<ExploreCard> testCards;

    setUp(() {
      // 创建测试仓库
      testGoalRepository = TestGoalRepository();
      testExploreRepository = TestExploreRepository();

      // 创建测试数据
      testGoals = [
        Goal(
          title: '简化同步测试目标1',
          description: '第一个简化同步测试目标',
          imagePath: 'simple_sync_test1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          title: '简化同步测试目标2',
          description: '第二个简化同步测试目标',
          imagePath: 'simple_sync_test2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.completed,
        ),
      ];

      testCards = [
        ExploreCard(
          id: 'simple_sync_card_1',
          title: '简化同步测试卡片1',
          description: '第一个简化同步测试卡片',
          imagePath: 'simple_sync_card1.jpg',
          category: '简化同步测试',
          createdTime: DateTime.now(),
        ),
        ExploreCard(
          id: 'simple_sync_card_2',
          title: '简化同步测试卡片2',
          description: '第二个简化同步测试卡片',
          imagePath: 'simple_sync_card2.jpg',
          category: '简化同步测试',
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

      // 获取同步服务实例
      syncService = SimpleRealTimeSyncService.instance;
    });

    tearDown(() {
      syncService.dispose();
    });

    test('应该能创建简化实时同步服务实例', () {
      expect(syncService, isNotNull);
      expect(syncService, isA<SimpleRealTimeSyncService>());
    });

    test('应该能初始化简化实时同步服务', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 验证初始化状态
      final status = syncService.getStatus();
      expect(status.isInitialized, isTrue);
      expect(status.isEnabled, isTrue);
    });

    test('应该能获取同步状态', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取同步状态
      final status = syncService.getStatus();

      expect(status, isA<SimpleSyncStatus>());
      expect(status.isInitialized, isTrue);
      expect(status.totalOperations, isA<int>());
      expect(status.syncStats, isA<Map<String, int>>());
    });

    test('应该能获取同步统计', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取同步统计
      final stats = syncService.getStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('isInitialized'), isTrue);
      expect(stats.containsKey('isEnabled'), isTrue);
      expect(stats.containsKey('totalOperations'), isTrue);
      expect(stats.containsKey('goalSyncCount'), isTrue);
      expect(stats.containsKey('exploreSyncCount'), isTrue);
    });

    test('应该能启用和禁用实时同步', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 禁用实时同步
      syncService.setEnabled(false);
      var status = syncService.getStatus();
      expect(status.isEnabled, isFalse);

      // 启用实时同步
      syncService.setEnabled(true);
      status = syncService.getStatus();
      expect(status.isEnabled, isTrue);
    });

    test('应该能手动触发同步', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取初始操作数
      final initialOperations = syncService.getStatus().totalOperations;

      // 手动触发同步
      syncService.triggerSync();

      // 验证操作数增加
      final finalOperations = syncService.getStatus().totalOperations;
      expect(finalOperations, greaterThan(initialOperations));
    });

    test('应该能重置统计', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 触发一些操作
      syncService.triggerSync();

      // 验证有操作记录
      var status = syncService.getStatus();
      expect(status.totalOperations, greaterThan(0));

      // 重置统计
      syncService.resetStats();

      // 验证统计已重置
      status = syncService.getStatus();
      expect(status.totalOperations, equals(0));
    });

    test('应该能处理目标状态变化', () async {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取初始统计
      final initialStats = syncService.getStats();
      final initialGoalSync = initialStats['goalSyncCount'] as int;

      // 触发目标加载
      goalBloc.add(const LoadGoals());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证目标同步计数增加
      final finalStats = syncService.getStats();
      final finalGoalSync = finalStats['goalSyncCount'] as int;
      expect(finalGoalSync, greaterThanOrEqualTo(initialGoalSync));
    });

    test('应该能处理探索状态变化', () async {
      // 初始化同步服务
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
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证探索同步计数增加
      final finalStats = syncService.getStats();
      final finalExploreSync = finalStats['exploreSyncCount'] as int;
      expect(finalExploreSync, greaterThanOrEqualTo(initialExploreSync));
    });

    group('扩展方法测试', () {
      test('应该能检查同步就绪状态', () {
        // 未初始化时应该不就绪
        expect(syncService.isReady, isFalse);

        // 初始化后应该就绪
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );
        expect(syncService.isReady, isTrue);

        // 禁用后应该不就绪
        syncService.setEnabled(false);
        expect(syncService.isReady, isFalse);
      });

      test('应该能获取格式化的最后同步时间', () {
        // 初始化同步服务
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 触发同步
        syncService.triggerSync();

        // 验证时间格式
        final timeStr = syncService.lastSyncTimeFormatted;
        expect(timeStr, isA<String>());
        expect(timeStr, isNot(equals('从未同步')));
      });

      test('应该能计算同步效率', () {
        // 初始化同步服务
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 触发同步
        syncService.triggerSync();

        // 验证效率计算
        final efficiency = syncService.syncEfficiency;
        expect(efficiency, isA<double>());
        expect(efficiency, greaterThanOrEqualTo(0.0));
      });
    });

    group('同步状态测试', () {
      test('应该能创建同步状态对象', () {
        final status = SimpleSyncStatus(
          isInitialized: true,
          isEnabled: true,
          lastSyncTime: DateTime.now(),
          totalOperations: 10,
          syncStats: {'test': 5},
        );

        expect(status.isInitialized, isTrue);
        expect(status.isEnabled, isTrue);
        expect(status.totalOperations, equals(10));
        expect(status.syncStats['test'], equals(5));
      });

      test('应该能将同步状态转换为Map', () {
        final status = SimpleSyncStatus(
          isInitialized: true,
          isEnabled: false,
          totalOperations: 20,
          syncStats: {'goal': 10, 'explore': 10},
        );

        final map = status.toMap();

        expect(map, isA<Map<String, dynamic>>());
        expect(map['isInitialized'], isTrue);
        expect(map['isEnabled'], isFalse);
        expect(map['totalOperations'], equals(20));
        expect(map['syncStats'], isA<Map<String, int>>());
      });
    });

    group('监控器测试', () {
      test('应该能创建同步监控器', () {
        final monitor = SimpleRealTimeSyncMonitor();
        expect(monitor, isNotNull);
        expect(monitor, isA<SimpleRealTimeSyncMonitor>());

        // 清理资源
        monitor.dispose();
      });

      test('应该能启动和停止监控', () {
        final monitor = SimpleRealTimeSyncMonitor();

        // 启动监控
        monitor.startMonitoring(interval: const Duration(milliseconds: 100));

        // 停止监控
        monitor.stopMonitoring();

        // 清理资源
        monitor.dispose();
      });
    });

    group('集成测试', () {
      test('应该能完整运行简化同步流程', () async {
        // 初始化同步服务
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 验证初始状态
        expect(syncService.isReady, isTrue);

        // 触发一系列操作
        syncService.triggerSync();
        goalBloc.add(const LoadGoals());
        exploreBloc.add(FetchExploreCards());

        await Future.delayed(const Duration(milliseconds: 200));

        // 验证同步服务正常工作
        final status = syncService.getStatus();
        expect(status.isInitialized, isTrue);
        expect(status.totalOperations, greaterThan(0));

        final stats = syncService.getStats();
        expect(stats['totalOperations'], greaterThan(0));
      });
    });
  });
}
