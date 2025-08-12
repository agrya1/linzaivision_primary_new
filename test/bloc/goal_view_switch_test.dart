import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/bloc/transaction/immediate_ui_batch_updater.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/models/goal.dart';

class _Repo implements GoalRepository {
  @override
  Future<List<Goal>> getGoals({int? parentId}) async => [];
  @override
  Future<List<Goal>> getGoalTree() async => [];
  @override
  Future<Goal?> getGoal(int id) async => null;
  @override
  Future<int> insertGoal(Goal goal) async => 1;
  @override
  Future<int> updateGoal(Goal goal) async => 1;
  @override
  Future<int> deleteGoal(int id) async => 1;
  @override
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {}
  @override
  Future<List<int>> batchInsertGoals(List<Goal> goals) async => [];
  @override
  Future<List<int>> batchUpdateGoals(List<Goal> goals) async => [];
  @override
  Future<List<int>> batchDeleteGoals(List<int> goalIds) async => [];
  @override
  Future<T> executeInTransaction<T>(Future<T> Function() operation) async => operation();
  @override
  Map<String, dynamic> getBatchOperationStats() => const {};
}

void main() {
  group('GoalBloc view switching behavior', () {
    late GoalBloc bloc;

    setUp(() {
      bloc = GoalBloc(
        repository: _Repo(),
        disableBatching: true,
        batchUpdater: ImmediateUIBatchUpdater(),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('cycle viewMode 0 -> 1 -> 2 -> 0', () async {
      // Load to reach GoalsLoaded
      bloc.add(const LoadGoals());
      await bloc.stream.firstWhere((s) => s is GoalsLoaded).timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).viewMode, 0);

      // 0 -> 1
      bloc.add(const ToggleViewMode(1));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && (s as GoalsLoaded).viewMode == 1)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).viewMode, 1);

      // 1 -> 2
      bloc.add(const ToggleViewMode(2));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && (s as GoalsLoaded).viewMode == 2)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).viewMode, 2);

      // 2 -> 0
      bloc.add(const ToggleViewMode(0));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && (s as GoalsLoaded).viewMode == 0)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).viewMode, 0);
    });
  });
}

