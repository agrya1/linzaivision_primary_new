import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/shared/shared_state_bloc.dart';
import 'package:linzaivision_primary/utils/cross_page_sync_manager.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/models/explore_card.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';

// 简单的测试仓库实现
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
      return 1; // 返回受影响的行数
    }
    return 0;
  }

  @override
  Future<int> deleteGoal(int id) async {
    final initialLength = _goals.length;
    _goals.removeWhere((g) => g.title.contains(id.toString()));
    return initialLength - _goals.length; // 返回删除的行数
  }

  @override
  Future<Goal?> getGoal(int id) async {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {
    _goals.addAll(rootGoals);
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
  Future<List<ExploreCard>> getExploreCardsByCategory(String category) async {
    return _cards.where((card) => card.category == category).toList();
  }

  @override
  Future<ExploreCard?> getExploreCard(String id) async {
    try {
      return _cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }

  void setTestCards(List<ExploreCard> cards) {
    _cards = cards;
  }
}

void main() {
  group('跨页面状态共享基础测试', () {
    late TestGoalRepository testGoalRepository;
    late TestExploreRepository testExploreRepository;
    late SharedStateBloc sharedStateBloc;
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
          title: '测试目标1',
          description: '第一个测试目标',
          imagePath: 'test1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          title: '测试目标2',
          description: '第二个测试目标',
          imagePath: 'test2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.completed,
        ),
      ];

      testCards = [
        ExploreCard(
          id: 'card1',
          title: '探索卡片1',
          description: '第一个探索卡片',
          imagePath: 'card1.jpg',
          category: '推荐',
          createdTime: DateTime.now(),
        ),
        ExploreCard(
          id: 'card2',
          title: '探索卡片2',
          description: '第二个探索卡片',
          imagePath: 'card2.jpg',
          category: '热门',
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

      // 获取同步管理器实例
      syncManager = CrossPageSyncManager.instance;
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('应该能创建共享状态BLoC', () {
      expect(sharedStateBloc, isNotNull);
      expect(sharedStateBloc.state, isA<SharedStateInitial>());
    });

    test('应该能创建跨页面同步管理器', () {
      expect(syncManager, isNotNull);
    });

    test('应该能初始化共享状态', () async {
      // 发送初始化事件
      sharedStateBloc.add(const InitializeSharedState());

      // 等待状态变化
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态已加载
      expect(sharedStateBloc.state, isA<SharedStateLoaded>());

      final state = sharedStateBloc.state as SharedStateLoaded;
      expect(state.goals.length, equals(2));
      expect(state.exploreCards.length, equals(2));
    });

    test('应该能同步目标数据', () async {
      // 初始化状态
      sharedStateBloc.add(const InitializeSharedState());
      await Future.delayed(const Duration(milliseconds: 100));

      // 创建新的目标数据
      final newGoals = [
        ...testGoals,
        Goal(
          title: '新目标',
          description: '新创建的目标',
          imagePath: 'new.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
      ];

      // 同步目标数据
      sharedStateBloc.add(SyncGoalData(
        goals: newGoals,
        allGoals: newGoals,
        currentGoal: newGoals.last,
      ));

      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态已更新
      final state = sharedStateBloc.state as SharedStateLoaded;
      expect(state.goals.length, equals(3));
      expect(state.currentGoal?.title, equals('新目标'));
    });

    test('应该能同步探索数据', () async {
      // 初始化状态
      sharedStateBloc.add(const InitializeSharedState());
      await Future.delayed(const Duration(milliseconds: 100));

      // 创建新的探索卡片数据
      final newCards = [
        ...testCards,
        ExploreCard(
          id: 'new_card',
          title: '新卡片',
          description: '新创建的卡片',
          imagePath: 'new_card.jpg',
          category: '新分类',
          createdTime: DateTime.now(),
        ),
      ];

      // 同步探索数据
      sharedStateBloc.add(SyncExploreData(
        cards: newCards,
        selectedCard: newCards.last,
      ));

      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态已更新
      final state = sharedStateBloc.state as SharedStateLoaded;
      expect(state.exploreCards.length, equals(3));
      expect(state.selectedCard?.title, equals('新卡片'));
    });

    test('应该能处理跨页面目标创建', () async {
      // 初始化状态
      sharedStateBloc.add(const InitializeSharedState());
      await Future.delayed(const Duration(milliseconds: 100));

      // 创建新目标
      final newGoal = Goal(
        title: '跨页面目标',
        description: '通过跨页面创建的目标',
        imagePath: 'cross_page.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
      );

      // 更新测试仓库数据
      testGoalRepository.setTestGoals([...testGoals, newGoal]);

      // 发送跨页面目标创建事件
      sharedStateBloc.add(CrossPageGoalCreated(
        goal: newGoal,
        sourcePage: 'explore',
      ));

      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态已更新
      final state = sharedStateBloc.state as SharedStateLoaded;
      expect(state.goals.length, equals(3));
      expect(state.currentGoal?.title, equals('跨页面目标'));
    });

    test('应该能处理数据刷新请求', () async {
      // 初始化状态
      sharedStateBloc.add(const InitializeSharedState());
      await Future.delayed(const Duration(milliseconds: 100));

      // 发送数据刷新请求
      sharedStateBloc.add(const RequestDataRefresh(
        requestingPage: 'goal',
        dataTypes: ['goals', 'explore'],
      ));

      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证状态仍然是已加载状态
      expect(sharedStateBloc.state, isA<SharedStateLoaded>());
    });

    group('CrossPageSyncAdapter测试', () {
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

      test('应该能通过适配器获取当前状态', () {
        // 获取当前状态（可能为null，因为还未初始化）
        final sharedState = goalPageAdapter.currentSharedState;
        final goals = goalPageAdapter.currentGoals;
        final exploreCards = explorePageAdapter.currentExploreCards;

        // 验证方法能正常调用（不抛出异常）
        expect(sharedState, isA<SharedState?>());
        expect(goals, isA<List<Goal>?>());
        expect(exploreCards, isA<List<ExploreCard>?>());
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
    });
  });
}
