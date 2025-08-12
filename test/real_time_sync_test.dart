import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/services/real_time_sync_service.dart';
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
  group('实时数据同步服务测试', () {
    late TestGoalRepository testGoalRepository;
    late TestExploreRepository testExploreRepository;
    late SharedStateBloc sharedStateBloc;
    late GoalBloc goalBloc;
    late ExploreBloc exploreBloc;
    late RealTimeSyncService syncService;
    late List<Goal> testGoals;
    late List<ExploreCard> testCards;

    setUp(() {
      // 创建测试仓库
      testGoalRepository = TestGoalRepository();
      testExploreRepository = TestExploreRepository();

      // 创建测试数据
      testGoals = [
        Goal(
          title: '实时同步测试目标1',
          description: '第一个实时同步测试目标',
          imagePath: 'sync_test1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          title: '实时同步测试目标2',
          description: '第二个实时同步测试目标',
          imagePath: 'sync_test2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.completed,
        ),
      ];

      testCards = [
        ExploreCard(
          id: 'sync_card_1',
          title: '实时同步测试卡片1',
          description: '第一个实时同步测试卡片',
          imagePath: 'sync_card1.jpg',
          category: '同步测试',
          createdTime: DateTime.now(),
        ),
        ExploreCard(
          id: 'sync_card_2',
          title: '实时同步测试卡片2',
          description: '第二个实时同步测试卡片',
          imagePath: 'sync_card2.jpg',
          category: '同步测试',
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
      syncService = RealTimeSyncService.instance;
    });

    tearDown(() {
      syncService.dispose();
    });

    test('应该能创建实时同步服务实例', () {
      expect(syncService, isNotNull);
      expect(syncService, isA<RealTimeSyncService>());
    });

    test('应该能初始化实时同步服务', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 验证初始化状态
      final status = syncService.getSyncStatus();
      expect(status.isInitialized, isTrue);
      expect(status.isRealTimeSyncEnabled, isTrue);
    });

    test('应该能获取同步状态', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取同步状态
      final status = syncService.getSyncStatus();

      expect(status, isA<SyncStatus>());
      expect(status.isInitialized, isTrue);
      expect(status.queueSize, isA<int>());
      expect(status.consecutiveErrorCount, isA<int>());
      expect(status.totalOperations, isA<int>());
      expect(status.averageLatency, isA<Duration>());
    });

    test('应该能获取性能统计', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 获取性能统计
      final stats = syncService.getPerformanceStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('syncStatus'), isTrue);
      expect(stats.containsKey('errorCount'), isTrue);
      expect(stats.containsKey('recentErrors'), isTrue);
    });

    test('应该能启用和禁用实时同步', () {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 禁用实时同步
      syncService.setRealTimeSyncEnabled(false);
      var status = syncService.getSyncStatus();
      expect(status.isRealTimeSyncEnabled, isFalse);

      // 启用实时同步
      syncService.setRealTimeSyncEnabled(true);
      status = syncService.getSyncStatus();
      expect(status.isRealTimeSyncEnabled, isTrue);
    });

    test('应该能处理目标状态变化', () async {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 触发目标加载
      goalBloc.add(const LoadGoals());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证同步操作被记录
      final stats = syncService.getPerformanceStats();
      expect(stats['syncStatus']['totalOperations'], greaterThan(0));
    });

    test('应该能处理探索状态变化', () async {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 触发探索卡片加载
      exploreBloc.add(FetchExploreCards());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证同步操作被记录
      final stats = syncService.getPerformanceStats();
      expect(stats['syncStatus']['totalOperations'], greaterThan(0));
    });

    test('应该能处理共享状态变化', () async {
      // 初始化同步服务
      syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      // 触发共享状态初始化
      sharedStateBloc.add(const InitializeSharedState());
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证同步操作被记录
      final stats = syncService.getPerformanceStats();
      expect(stats['syncStatus']['totalOperations'], greaterThan(0));
    });

    group('同步操作类型测试', () {
      test('应该能创建不同类型的同步操作', () {
        final goalOperation = SyncOperation(
          type: SyncOperationType.goalStateUpdate,
          data: 'test_data',
          timestamp: DateTime.now(),
          priority: SyncPriority.high,
        );

        final exploreOperation = SyncOperation(
          type: SyncOperationType.exploreStateUpdate,
          data: 'test_data',
          timestamp: DateTime.now(),
          priority: SyncPriority.medium,
        );

        final sharedOperation = SyncOperation(
          type: SyncOperationType.sharedStateUpdate,
          data: 'test_data',
          timestamp: DateTime.now(),
          priority: SyncPriority.low,
        );

        expect(goalOperation.type, equals(SyncOperationType.goalStateUpdate));
        expect(exploreOperation.type,
            equals(SyncOperationType.exploreStateUpdate));
        expect(
            sharedOperation.type, equals(SyncOperationType.sharedStateUpdate));
      });

      test('应该能正确设置同步优先级', () {
        final highPriorityOp = SyncOperation(
          type: SyncOperationType.goalStateUpdate,
          data: 'test',
          timestamp: DateTime.now(),
          priority: SyncPriority.high,
        );

        final lowPriorityOp = SyncOperation(
          type: SyncOperationType.exploreStateUpdate,
          data: 'test',
          timestamp: DateTime.now(),
          priority: SyncPriority.low,
        );

        expect(highPriorityOp.priority.index,
            greaterThan(lowPriorityOp.priority.index));
      });
    });

    group('错误处理测试', () {
      test('应该能创建同步错误对象', () {
        final syncError = SyncError(
          error: '测试错误',
          timestamp: DateTime.now(),
          consecutiveCount: 1,
        );

        expect(syncError.error, equals('测试错误'));
        expect(syncError.consecutiveCount, equals(1));
        expect(syncError.timestamp, isA<DateTime>());
      });

      test('应该能将同步错误转换为Map', () {
        final syncError = SyncError(
          error: '测试错误',
          timestamp: DateTime.now(),
          consecutiveCount: 2,
        );

        final map = syncError.toMap();

        expect(map, isA<Map<String, dynamic>>());
        expect(map['error'], equals('测试错误'));
        expect(map['consecutiveCount'], equals(2));
        expect(map['timestamp'], isA<String>());
      });
    });

    group('性能指标测试', () {
      test('应该能创建性能指标对象', () {
        final metric = SyncPerformanceMetric(
          operationType: 'test_operation',
          duration: const Duration(milliseconds: 100),
          timestamp: DateTime.now(),
        );

        expect(metric.operationType, equals('test_operation'));
        expect(metric.duration.inMilliseconds, equals(100));
        expect(metric.timestamp, isA<DateTime>());
      });
    });

    group('同步状态测试', () {
      test('应该能创建同步状态对象', () {
        final status = SyncStatus(
          isInitialized: true,
          isRealTimeSyncEnabled: true,
          lastSyncTime: DateTime.now(),
          queueSize: 5,
          consecutiveErrorCount: 0,
          totalOperations: 100,
          averageLatency: const Duration(milliseconds: 50),
        );

        expect(status.isInitialized, isTrue);
        expect(status.isRealTimeSyncEnabled, isTrue);
        expect(status.queueSize, equals(5));
        expect(status.consecutiveErrorCount, equals(0));
        expect(status.totalOperations, equals(100));
        expect(status.averageLatency.inMilliseconds, equals(50));
      });

      test('应该能将同步状态转换为Map', () {
        final status = SyncStatus(
          isInitialized: true,
          isRealTimeSyncEnabled: false,
          queueSize: 3,
          consecutiveErrorCount: 1,
          totalOperations: 50,
          averageLatency: const Duration(milliseconds: 75),
        );

        final map = status.toMap();

        expect(map, isA<Map<String, dynamic>>());
        expect(map['isInitialized'], isTrue);
        expect(map['isRealTimeSyncEnabled'], isFalse);
        expect(map['queueSize'], equals(3));
        expect(map['consecutiveErrorCount'], equals(1));
        expect(map['totalOperations'], equals(50));
        expect(map['averageLatency'], equals(75));
      });
    });

    group('集成测试', () {
      test('应该能完整运行同步流程', () async {
        // 初始化同步服务
        syncService.initialize(
          sharedStateBloc: sharedStateBloc,
          goalBloc: goalBloc,
          exploreBloc: exploreBloc,
        );

        // 触发一系列状态变化
        sharedStateBloc.add(const InitializeSharedState());
        await Future.delayed(const Duration(milliseconds: 50));

        goalBloc.add(const LoadGoals());
        await Future.delayed(const Duration(milliseconds: 50));

        exploreBloc.add(FetchExploreCards());
        await Future.delayed(const Duration(milliseconds: 50));

        // 验证同步服务正常工作
        final status = syncService.getSyncStatus();
        expect(status.isInitialized, isTrue);
        expect(status.totalOperations, greaterThan(0));

        final stats = syncService.getPerformanceStats();
        expect(stats['syncStatus']['totalOperations'], greaterThan(0));
      });
    });
  });
}
