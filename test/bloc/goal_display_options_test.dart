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
  group('GoalBloc display options behavior', () {
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

    test('toggle title/description/time/countdown flags', () async {
      bloc.add(const LoadGoals());
      await bloc.stream.firstWhere((s) => s is GoalsLoaded).timeout(const Duration(seconds: 2));
      final initial = bloc.state as GoalsLoaded;

      bloc.add(const ToggleTitleDisplay(false));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && !(s as GoalsLoaded).showTitle)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).showTitle, isFalse);

      bloc.add(const ToggleDescriptionDisplay(false));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && !(s as GoalsLoaded).showDescription)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).showDescription, isFalse);

      bloc.add(const ToggleTimeDisplay(false));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && !(s as GoalsLoaded).showTime)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).showTime, isFalse);

      bloc.add(const ToggleCountdownDisplay(true));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded && (s as GoalsLoaded).showCountdown)
          .timeout(const Duration(seconds: 2));
      expect((bloc.state as GoalsLoaded).showCountdown, isTrue);

      // restore
      bloc.add(const ToggleTitleDisplay(true));
      bloc.add(const ToggleDescriptionDisplay(true));
      bloc.add(const ToggleTimeDisplay(true));
      bloc.add(const ToggleCountdownDisplay(false));
      await bloc.stream.firstWhere((s) => s is GoalsLoaded &&
          (s as GoalsLoaded).showTitle && (s).showDescription && (s).showTime && !(s).showCountdown)
          .timeout(const Duration(seconds: 2));
      final restored = bloc.state as GoalsLoaded;
      expect(restored.showTitle, isTrue);
      expect(restored.showDescription, isTrue);
      expect(restored.showTime, isTrue);
      expect(restored.showCountdown, isFalse);

      // keep other flags intact
      expect(restored.viewMode, initial.viewMode);
    });
  });
}

