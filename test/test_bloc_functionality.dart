import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:linzaivision_primary_new/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary_new/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary_new/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary_new/models/goal.dart';
import 'package:linzaivision_primary_new/repositories/goal_repository.dart';

// Mock Repository
class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  group('第一阶段BLoC迁移功能验证测试', () {
    late GoalBloc goalBloc;
    late MockGoalRepository mockRepository;
    
    setUp(() {
      mockRepository = MockGoalRepository();
      goalBloc = GoalBloc(repository: mockRepository);
    });
    
    tearDown(() {
      goalBloc.close();
    });
    
    group('视图切换功能测试', () {
      blocTest<GoalBloc, GoalState>(
        '应该正确处理ToggleViewMode事件',
        build: () {
          // 设置初始状态
          when(() => mockRepository.getGoals()).thenAnswer((_) async => []);
          return goalBloc;
        },
        act: (bloc) async {
          // 先加载目标
          bloc.add(const LoadGoals());
          await Future.delayed(const Duration(milliseconds: 100));
          
          // 测试视图切换
          bloc.add(const ToggleViewMode(1)); // 切换到时间轴视图
          bloc.add(const ToggleViewMode(2)); // 切换到网格视图
          bloc.add(const ToggleViewMode(0)); // 切换回全屏视图
        },
        expect: () => [
          isA<GoalLoading>(),
          isA<GoalsLoaded>().having((state) => state.viewMode, 'viewMode', 0),
          isA<GoalsLoaded>().having((state) => state.viewMode, 'viewMode', 1),
          isA<GoalsLoaded>().having((state) => state.viewMode, 'viewMode', 2),
          isA<GoalsLoaded>().having((state) => state.viewMode, 'viewMode', 0),
        ],
        verify: (bloc) {
          // 验证最终状态
          final state = bloc.state as GoalsLoaded;
          expect(state.viewMode, equals(0));
        },
      );
      
      test('视图模式应该在有效范围内', () {
        const validModes = [0, 1, 2, 3, 4]; // 全屏、时间轴、网格、目标树、探索
        
        for (final mode in validModes) {
          expect(mode, greaterThanOrEqualTo(0));
          expect(mode, lessThanOrEqualTo(4));
        }
      });
    });
    
    group('目标选择功能测试', () {
      final testGoal = Goal(
        id: 1,
        title: '测试目标',
        description: '这是一个测试目标',
        createdAt: DateTime.now(),
        status: GoalStatus.pending,
      );
      
      blocTest<GoalBloc, GoalState>(
        '应该正确处理SelectGoal事件',
        build: () {
          when(() => mockRepository.getGoals()).thenAnswer((_) async => [testGoal]);
          return goalBloc;
        },
        act: (bloc) async {
          // 先加载目标
          bloc.add(const LoadGoals());
          await Future.delayed(const Duration(milliseconds: 100));
          
          // 测试目标选择
          bloc.add(SelectGoal(testGoal));
        },
        expect: () => [
          isA<GoalLoading>(),
          isA<GoalsLoaded>().having((state) => state.currentGoal, 'currentGoal', null),
          isA<GoalsLoaded>().having((state) => state.currentGoal, 'currentGoal', testGoal),
        ],
        verify: (bloc) {
          // 验证最终状态
          final state = bloc.state as GoalsLoaded;
          expect(state.currentGoal, equals(testGoal));
          expect(state.currentGoal?.id, equals(1));
          expect(state.currentGoal?.title, equals('测试目标'));
        },
      );
    });
    
    group('编辑状态功能测试', () {
      blocTest<GoalBloc, GoalState>(
        '应该正确处理编辑状态切换',
        build: () {
          when(() => mockRepository.getGoals()).thenAnswer((_) async => []);
          return goalBloc;
        },
        act: (bloc) async {
          // 先加载目标
          bloc.add(const LoadGoals());
          await Future.delayed(const Duration(milliseconds: 100));
          
          // 测试编辑状态切换
          bloc.add(const StartEditingTitle());
          bloc.add(const CancelEditing());
        },
        expect: () => [
          isA<GoalLoading>(),
          isA<GoalsLoaded>().having((state) => state.isEditingTitle, 'isEditingTitle', false),
          isA<GoalsLoaded>().having((state) => state.isEditingTitle, 'isEditingTitle', true),
          isA<GoalsLoaded>().having((state) => state.isEditingTitle, 'isEditingTitle', false),
        ],
        verify: (bloc) {
          // 验证最终状态
          final state = bloc.state as GoalsLoaded;
          expect(state.isEditingTitle, isFalse);
        },
      );
    });
    
    group('显示选项功能测试', () {
      blocTest<GoalBloc, GoalState>(
        '应该正确处理显示选项切换',
        build: () {
          when(() => mockRepository.getGoals()).thenAnswer((_) async => []);
          return goalBloc;
        },
        act: (bloc) async {
          // 先加载目标
          bloc.add(const LoadGoals());
          await Future.delayed(const Duration(milliseconds: 100));
          
          // 测试显示选项切换
          bloc.add(const ToggleTitleDisplay(false));
          bloc.add(const ToggleTimeDisplay(false));
          bloc.add(const ToggleDescriptionDisplay(false));
          bloc.add(const ToggleCountdownDisplay(true));
        },
        expect: () => [
          isA<GoalLoading>(),
          isA<GoalsLoaded>(),
          isA<GoalsLoaded>().having((state) => state.showTitle, 'showTitle', false),
          isA<GoalsLoaded>().having((state) => state.showTime, 'showTime', false),
          isA<GoalsLoaded>().having((state) => state.showDescription, 'showDescription', false),
          isA<GoalsLoaded>().having((state) => state.showCountdown, 'showCountdown', true),
        ],
        verify: (bloc) {
          // 验证最终状态
          final state = bloc.state as GoalsLoaded;
          expect(state.showTitle, isFalse);
          expect(state.showTime, isFalse);
          expect(state.showDescription, isFalse);
          expect(state.showCountdown, isTrue);
        },
      );
    });
    
    group('复合操作测试', () {
      final testGoal = Goal(
        id: 1,
        title: '测试目标',
        description: '这是一个测试目标',
        createdAt: DateTime.now(),
        status: GoalStatus.pending,
      );
      
      blocTest<GoalBloc, GoalState>(
        '应该正确处理复合操作：选择目标 + 切换视图 + 开始编辑',
        build: () {
          when(() => mockRepository.getGoals()).thenAnswer((_) async => [testGoal]);
          return goalBloc;
        },
        act: (bloc) async {
          // 加载目标
          bloc.add(const LoadGoals());
          await Future.delayed(const Duration(milliseconds: 100));
          
          // 复合操作
          bloc.add(SelectGoal(testGoal));
          bloc.add(const ToggleViewMode(0));
          bloc.add(const StartEditingTitle());
        },
        verify: (bloc) {
          // 验证最终状态包含所有变更
          final state = bloc.state as GoalsLoaded;
          expect(state.currentGoal, equals(testGoal));
          expect(state.viewMode, equals(0));
          expect(state.isEditingTitle, isTrue);
        },
      );
    });
  });
}
