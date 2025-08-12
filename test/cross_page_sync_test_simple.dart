import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/shared/shared_state_bloc.dart';
import 'package:linzaivision_primary/utils/cross_page_sync_manager.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/models/explore_card.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';

/// 简化的跨页面同步测试
/// 这个版本移除了复杂的BLoC依赖，专注于测试核心同步功能

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
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteGoal(int id) async {
    final initialLength = _goals.length;
    _goals.removeWhere((g) => g.id == id);
    return initialLength - _goals.length;
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
  group('跨页面状态同步基础测试', () {
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

      // 创建SharedStateBloc（简化版本）
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

    test('应该能创建跨页面同步管理器实例', () {
      expect(syncManager, isNotNull);
      expect(syncManager, isA<CrossPageSyncManager>());
    });

    test('应该能获取单例实例', () {
      final instance1 = CrossPageSyncManager.instance;
      final instance2 = CrossPageSyncManager.instance;

      expect(instance1, same(instance2));
    });

    test('SharedStateBloc应该能正确初始化', () {
      expect(sharedStateBloc, isNotNull);
      expect(sharedStateBloc.state, isA<SharedStateInitial>());
    });

    test('测试仓库应该能正确返回数据', () async {
      final goals = await testGoalRepository.getGoals();
      final cards = await testExploreRepository.getExploreCards();

      expect(goals.length, equals(2));
      expect(cards.length, equals(2));
      expect(goals.first.title, equals('测试目标1'));
      expect(cards.first.title, equals('探索卡片1'));
    });

    test('应该能添加新的目标', () async {
      final newGoal = Goal(
        id: 3,
        title: '新测试目标',
        description: '新添加的测试目标',
        imagePath: 'new_test.jpg',
        createdTime: DateTime.now(),
        status: GoalStatus.pending,
      );

      await testGoalRepository.insertGoal(newGoal);
      final goals = await testGoalRepository.getGoals();

      expect(goals.length, equals(3));
      expect(goals.last.title, equals('新测试目标'));
    });

    test('应该能更新现有目标', () async {
      final updatedGoal = Goal(
        id: 1,
        title: '更新的测试目标1',
        description: '已更新的第一个测试目标',
        imagePath: 'updated_test1.jpg',
        createdTime: testGoals.first.createdTime,
        status: GoalStatus.completed,
      );

      final result = await testGoalRepository.updateGoal(updatedGoal);
      expect(result, equals(1));

      final goals = await testGoalRepository.getGoals();
      final updatedGoalFromRepo = goals.firstWhere((g) => g.id == 1);
      expect(updatedGoalFromRepo.title, equals('更新的测试目标1'));
      expect(updatedGoalFromRepo.status, equals(GoalStatus.completed));
    });

    test('应该能删除目标', () async {
      final result = await testGoalRepository.deleteGoal(1);
      expect(result, equals(1));

      final goals = await testGoalRepository.getGoals();
      expect(goals.length, equals(1));
      expect(goals.first.id, equals(2));
    });

    test('应该能按分类获取探索卡片', () async {
      final recommendedCards =
          await testExploreRepository.getExploreCardsByCategory('推荐');
      final hotCards =
          await testExploreRepository.getExploreCardsByCategory('热门');

      expect(recommendedCards.length, equals(1));
      expect(hotCards.length, equals(1));
      expect(recommendedCards.first.title, equals('探索卡片1'));
      expect(hotCards.first.title, equals('探索卡片2'));
    });

    test('应该能通过ID获取特定的探索卡片', () async {
      final card = await testExploreRepository.getExploreCard('card1');

      expect(card, isNotNull);
      expect(card!.title, equals('探索卡片1'));
      expect(card.category, equals('推荐'));
    });

    test('获取不存在的卡片应该返回null', () async {
      final card = await testExploreRepository.getExploreCard('nonexistent');
      expect(card, isNull);
    });

    test('获取不存在的目标应该返回null', () async {
      final goal = await testGoalRepository.getGoal(999);
      expect(goal, isNull);
    });

    test('批量插入目标树应该正确工作', () async {
      final newGoals = [
        Goal(
          id: 10,
          title: '批量目标1',
          description: '批量插入的目标1',
          imagePath: 'batch1.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
        Goal(
          id: 11,
          title: '批量目标2',
          description: '批量插入的目标2',
          imagePath: 'batch2.jpg',
          createdTime: DateTime.now(),
          status: GoalStatus.pending,
        ),
      ];

      await testGoalRepository.batchInsertGoalTree(newGoals);
      final goals = await testGoalRepository.getGoals();

      expect(goals.length, equals(4)); // 原来2个 + 新增2个
      expect(goals.any((g) => g.title == '批量目标1'), isTrue);
      expect(goals.any((g) => g.title == '批量目标2'), isTrue);
    });
  });
}
