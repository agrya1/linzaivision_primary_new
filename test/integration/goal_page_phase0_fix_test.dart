import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/bloc/transaction/immediate_ui_batch_updater.dart';

/// 简易内存仓库用于阶段0验证（模拟 UI 已写 DB 后，通过 Load/Refresh/Select 同步 BLoC 状态）
class InMemoryGoalRepository implements GoalRepository {
  final Map<int, Goal> _store = {};
  int _id = 0;

  @override
  Future<List<Goal>> getGoals({int? parentId}) async => _store.values.toList();

  @override
  Future<Goal?> getGoal(int id) async => _store[id];

  @override
  Future<int> insertGoal(Goal goal) async {
    final id = ++_id;
    final newGoal = Goal(
      id: id,
      title: goal.title,
      description: goal.description,
      imagePath: goal.imagePath,
      createdTime: goal.createdTime,
      targetDate: goal.targetDate,
      status: goal.status,
      subGoals: goal.subGoals,
      parentId: goal.parentId,
      videoPath: goal.videoPath,
      hasVideo: goal.hasVideo,
      videoMuted: goal.videoMuted,
      customCountdownDays: goal.customCountdownDays,
      hasCustomCountdown: goal.hasCustomCountdown,
    );
    _store[id] = newGoal;
    return id;
  }

  @override
  Future<int> updateGoal(Goal goal) async {
    if (goal.id == null) return 0;
    _store[goal.id!] = goal;
    return 1;
  }

  @override
  Future<int> deleteGoal(int id) async {
    return _store.remove(id) != null ? 1 : 0;
  }

  @override
  Future<List<Goal>> getGoalTree() async => _store.values.toList();

  @override
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {
    for (final g in rootGoals) {
      final id = ++_id;
      _store[id] = Goal(
        id: id,
        title: g.title,
        description: g.description,
        imagePath: g.imagePath,
        createdTime: g.createdTime,
        targetDate: g.targetDate,
        status: g.status,
        subGoals: g.subGoals,
        parentId: g.parentId,
        videoPath: g.videoPath,
        hasVideo: g.hasVideo,
        videoMuted: g.videoMuted,
        customCountdownDays: g.customCountdownDays,
        hasCustomCountdown: g.hasCustomCountdown,
      );
    }
  }

  @override
  Future<List<int>> batchInsertGoals(List<Goal> goals) async {
    final ids = <int>[];
    for (final g in goals) {
      final id = ++_id;
      _store[id] = Goal(
        id: id,
        title: g.title,
        description: g.description,
        imagePath: g.imagePath,
        createdTime: g.createdTime,
        targetDate: g.targetDate,
        status: g.status,
        subGoals: g.subGoals,
        parentId: g.parentId,
        videoPath: g.videoPath,
        hasVideo: g.hasVideo,
        videoMuted: g.videoMuted,
        customCountdownDays: g.customCountdownDays,
        hasCustomCountdown: g.hasCustomCountdown,
      );
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<List<int>> batchUpdateGoals(List<Goal> goals) async {
    for (final g in goals) {
      if (g.id != null) _store[g.id!] = g;
    }
    return goals.where((g) => g.id != null).map((g) => g.id!).toList();
  }

  @override
  Future<List<int>> batchDeleteGoals(List<int> goalIds) async {
    for (final id in goalIds) {
      _store.remove(id);
    }
    return goalIds;
  }

  @override
  Future<T> executeInTransaction<T>(Future<T> Function() operation) async {
    return await operation();
  }

  @override
  Map<String, dynamic> getBatchOperationStats() => {
        'totalOperations': _store.length,
        'batchedOperations': 0,
        'successfulBatches': 0,
        'failedBatches': 0,
        'averageExecutionTime': const Duration(milliseconds: 1),
        'batchSuccessRate': 1.0,
        'pendingOperations': 0,
        'performanceLevel': 'Good',
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GoalPage 阶段0修复 聚焦验证', () {
    late InMemoryGoalRepository repo;
    late GoalBloc bloc;

    // 使用流等待某状态，确保监听在事件前建立，避免错过发射
    Future<void> waitForLoaded({Duration timeout = const Duration(seconds: 2)}) async {
      await bloc.stream.firstWhere((s) => s is GoalsLoaded).timeout(timeout);
    }

    Goal makeGoal({int? id, String title = 'G', String? description}) => Goal(
          id: id,
          title: title,
          description: description ?? 'D',
          imagePath: 'img.png',
          createdTime: DateTime(2025, 1, 1),
        );

    setUp(() {
      repo = InMemoryGoalRepository();
      bloc = GoalBloc(
        repository: repo,
        disableBatching: true,
        batchUpdater: ImmediateUIBatchUpdater(),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('新增目标后，通过 Load/Refresh/Select 同步到 BLoC', () async {
      // 模拟 UI 直接写 DB
      final id = await repo.insertGoal(makeGoal(title: 'A'));
      final created = await repo.getGoal(id);
      expect(created, isNotNull);

      // 仅通过只读事件同步
      final states = <GoalState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadGoals());
      bloc.add(RefreshGoalTree());
      if (created != null) bloc.add(SelectGoal(created));

      await waitForLoaded();
      final s = bloc.state as GoalsLoaded;
      expect(s.goals.any((g) => g.title == 'A'), isTrue);
      expect(s.currentGoal?.title, 'A');
      await sub.cancel();
    });

    test('更新目标后，通过只读事件同步', () async {
      final id = await repo.insertGoal(makeGoal(title: 'A'));
      final g = (await repo.getGoal(id))!;
      await repo.updateGoal(g.copyWith(title: 'A2'));

      final sub = bloc.stream.listen((_){});
      bloc.add(const LoadGoals());
      bloc.add(RefreshGoalTree());
      bloc.add(SelectGoal((await repo.getGoal(id))!));
      await waitForLoaded();

      final s = bloc.state as GoalsLoaded;
      expect(s.goals.any((x) => x.title == 'A2'), isTrue);
      expect(s.currentGoal?.title, 'A2');
      await sub.cancel();
    });

    test('删除目标后，通过只读事件同步', () async {
      final id1 = await repo.insertGoal(makeGoal(title: 'A'));
      await repo.insertGoal(makeGoal(title: 'B'));
      expect((await repo.getGoals()).length, 2);

      final sub = bloc.stream.listen((_){});
      await repo.deleteGoal(id1);
      bloc.add(const LoadGoals());
      bloc.add(RefreshGoalTree());
      // 重新选择第一个
      final remain = (await repo.getGoals()).firstOrNull;
      if (remain != null) bloc.add(SelectGoal(remain));

      await waitForLoaded();
      final s = bloc.state as GoalsLoaded;
      expect(s.goals.length, 1);
      expect(s.goals.first.title, 'B');
      expect(s.currentGoal?.title, 'B');
      await sub.cancel();
    });

    test('视图切换与显示选项（BLoC 层）正常工作', () async {
      // 初始化一些数据
      await repo.insertGoal(makeGoal(title: 'A'));
      final sub = bloc.stream.listen((_){});
      bloc.add(const LoadGoals());
      await waitForLoaded();

      // 视图切换
      bloc.add(const ToggleViewMode(1));
      await waitForLoaded();

      // 显示选项
      bloc.add(const ToggleTitleDisplay(false));
      bloc.add(const ToggleDescriptionDisplay(false));
      await waitForLoaded();

      final s = bloc.state as GoalsLoaded;
      expect(s.viewMode, 1);
      expect(s.showTitle, isFalse);
      expect(s.showDescription, isFalse);
      await sub.cancel();
    });

    test('状态切换（完成/进行中/暂停）经只读同步后可见', () async {
      final id = await repo.insertGoal(makeGoal(title: 'A'));
      var g = (await repo.getGoal(id))!;
      // 模拟 UI 改状态
      g = g.copyWith(status: GoalStatus.completed);
      await repo.updateGoal(g);

      final sub = bloc.stream.listen((_){});
      bloc.add(const LoadGoals());
      bloc.add(RefreshGoalTree());
      bloc.add(SelectGoal(g));
      await waitForLoaded();

      final s = bloc.state as GoalsLoaded;
      expect(s.currentGoal?.status, GoalStatus.completed);
      await sub.cancel();
    });
  });
}

