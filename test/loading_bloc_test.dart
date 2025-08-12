import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/loading/loading_bloc.dart';
import 'package:linzaivision_primary/bloc/loading/loading_event.dart';
import 'package:linzaivision_primary/bloc/loading/loading_state.dart';
import 'package:linzaivision_primary/bloc/loading/loading_task.dart';

/// 统一加载状态管理机制测试
void main() {
  group('LoadingBloc 统一加载状态管理测试', () {
    late LoadingBloc loadingBloc;
    
    setUp(() {
      loadingBloc = LoadingBloc();
    });
    
    tearDown(() {
      loadingBloc.close();
    });
    
    test('初始状态应该正确', () {
      expect(loadingBloc.state.isLoading, isFalse);
      expect(loadingBloc.state.overallProgress, equals(0.0));
      expect(loadingBloc.state.taskStates, isEmpty);
      expect(loadingBloc.state.activeTasks, isEmpty);
      expect(loadingBloc.state.failedTasks, isEmpty);
      expect(loadingBloc.state.completedTasks, isEmpty);
    });
    
    test('注册任务应该更新状态', () async {
      final tasks = [
        LoadingTask<String>(
          id: 'test_task_1',
          name: '测试任务1',
          executor: (context) async => 'result1',
          priority: LoadingPriority.high,
        ),
        LoadingTask<String>(
          id: 'test_task_2',
          name: '测试任务2',
          executor: (context) async => 'result2',
          priority: LoadingPriority.normal,
          dependencies: ['test_task_1'],
        ),
      ];
      
      loadingBloc.add(RegisterLoadingTasks(tasks));
      
      await expectLater(
        loadingBloc.stream,
        emits(predicate<LoadingBlocState>((state) {
          return state.taskStates.length == 2 &&
                 state.taskStates.containsKey('test_task_1') &&
                 state.taskStates.containsKey('test_task_2') &&
                 state.taskStates['test_task_1'] is LoadingIdle &&
                 state.taskStates['test_task_2'] is LoadingIdle;
        })),
      );
    });
    
    test('执行简单任务应该成功', () async {
      final task = LoadingTask<String>(
        id: 'simple_task',
        name: '简单任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success';
        },
        priority: LoadingPriority.normal,
      );
      
      loadingBloc.add(RegisterLoadingTasks([task]));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      loadingBloc.add(const StartLoadingTask('simple_task'));
      
      // 验证加载中状态
      await expectLater(
        loadingBloc.stream,
        emits(predicate<LoadingBlocState>((state) {
          return state.isLoading &&
                 state.activeTasks.contains('simple_task') &&
                 state.taskStates['simple_task'] is LoadingInProgress;
        })),
      );
      
      // 等待任务完成
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 验证完成状态
      await expectLater(
        loadingBloc.stream,
        emits(predicate<LoadingBlocState>((state) {
          return !state.isLoading &&
                 !state.activeTasks.contains('simple_task') &&
                 state.completedTasks.contains('simple_task') &&
                 state.taskStates['simple_task'] is LoadingSuccess;
        })),
      );
    });
    
    test('任务失败应该正确处理', () async {
      final task = LoadingTask<String>(
        id: 'failing_task',
        name: '失败任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('任务执行失败');
        },
        priority: LoadingPriority.normal,
        maxRetries: 1,
      );
      
      loadingBloc.add(RegisterLoadingTasks([task]));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      loadingBloc.add(const StartLoadingTask('failing_task'));
      
      // 等待任务失败
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 验证失败状态
      await expectLater(
        loadingBloc.stream,
        emits(predicate<LoadingBlocState>((state) {
          return !state.isLoading &&
                 !state.activeTasks.contains('failing_task') &&
                 state.failedTasks.contains('failing_task') &&
                 state.taskStates['failing_task'] is LoadingError;
        })),
      );
    });
    
    test('依赖任务应该按顺序执行', () async {
      final tasks = [
        LoadingTask<String>(
          id: 'dependency_task',
          name: '依赖任务',
          executor: (context) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'dependency_result';
          },
          priority: LoadingPriority.high,
        ),
        LoadingTask<String>(
          id: 'dependent_task',
          name: '依赖者任务',
          executor: (context) async {
            await Future.delayed(const Duration(milliseconds: 50));
            return 'dependent_result';
          },
          priority: LoadingPriority.normal,
          dependencies: ['dependency_task'],
        ),
      ];
      
      loadingBloc.add(RegisterLoadingTasks(tasks));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 尝试执行依赖者任务（应该不会执行，因为依赖未满足）
      loadingBloc.add(const StartLoadingTask('dependent_task'));
      
      // 等待一段时间，确认依赖者任务没有开始
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(loadingBloc.state.activeTasks.contains('dependent_task'), isFalse);
      
      // 执行依赖任务
      loadingBloc.add(const StartLoadingTask('dependency_task'));
      
      // 等待依赖任务完成
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 验证依赖任务完成
      expect(loadingBloc.state.taskStates['dependency_task'] is LoadingSuccess, isTrue);
      
      // 现在执行依赖者任务应该成功
      loadingBloc.add(const StartLoadingTask('dependent_task'));
      
      // 等待依赖者任务完成
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 验证依赖者任务也完成
      expect(loadingBloc.state.taskStates['dependent_task'] is LoadingSuccess, isTrue);
    });
    
    test('任务优先级应该正确排序', () async {
      final tasks = [
        LoadingTask<String>(
          id: 'low_priority',
          name: '低优先级任务',
          executor: (context) async => 'low',
          priority: LoadingPriority.low,
        ),
        LoadingTask<String>(
          id: 'high_priority',
          name: '高优先级任务',
          executor: (context) async => 'high',
          priority: LoadingPriority.high,
        ),
        LoadingTask<String>(
          id: 'critical_priority',
          name: '关键优先级任务',
          executor: (context) async => 'critical',
          priority: LoadingPriority.critical,
        ),
      ];
      
      loadingBloc.add(RegisterLoadingTasks(tasks));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 批量执行任务
      loadingBloc.add(const StartLoadingTasks(['low_priority', 'high_priority', 'critical_priority']));
      
      // 等待任务开始执行
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证关键优先级任务首先执行
      expect(loadingBloc.state.currentPriority, equals(LoadingPriority.critical));
    });
    
    test('任务取消应该正确处理', () async {
      final task = LoadingTask<String>(
        id: 'cancellable_task',
        name: '可取消任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 500)); // 长时间任务
          return 'completed';
        },
        priority: LoadingPriority.normal,
        canBeCancelled: true,
      );
      
      loadingBloc.add(RegisterLoadingTasks([task]));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      loadingBloc.add(const StartLoadingTask('cancellable_task'));
      
      // 等待任务开始
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证任务正在执行
      expect(loadingBloc.state.activeTasks.contains('cancellable_task'), isTrue);
      
      // 取消任务
      loadingBloc.add(const CancelLoadingTask('cancellable_task'));
      
      // 等待取消处理
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证任务已取消
      expect(loadingBloc.state.activeTasks.contains('cancellable_task'), isFalse);
      expect(loadingBloc.state.taskStates['cancellable_task'] is LoadingCancelled, isTrue);
    });
    
    test('重试失败任务应该正确工作', () async {
      int attemptCount = 0;
      
      final task = LoadingTask<String>(
        id: 'retry_task',
        name: '重试任务',
        executor: (context) async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('任务失败，尝试次数: $attemptCount');
          }
          return 'success_after_retry';
        },
        priority: LoadingPriority.normal,
        maxRetries: 3,
      );
      
      loadingBloc.add(RegisterLoadingTasks([task]));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      loadingBloc.add(const StartLoadingTask('retry_task'));
      
      // 等待第一次失败
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 验证任务失败
      expect(loadingBloc.state.taskStates['retry_task'] is LoadingError, isTrue);
      expect(loadingBloc.state.failedTasks.contains('retry_task'), isTrue);
      
      // 重试任务
      loadingBloc.add(const RetryFailedTask('retry_task'));
      
      // 等待第二次失败
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 再次重试
      loadingBloc.add(const RetryFailedTask('retry_task'));
      
      // 等待第三次尝试成功
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 验证任务最终成功
      expect(loadingBloc.state.taskStates['retry_task'] is LoadingSuccess, isTrue);
      expect(attemptCount, equals(3));
    });
    
    test('整体进度计算应该正确', () async {
      final tasks = [
        LoadingTask<String>(
          id: 'task1',
          name: '任务1',
          executor: (context) async => 'result1',
        ),
        LoadingTask<String>(
          id: 'task2',
          name: '任务2',
          executor: (context) async => 'result2',
        ),
        LoadingTask<String>(
          id: 'task3',
          name: '任务3',
          executor: (context) async => 'result3',
        ),
      ];
      
      loadingBloc.add(RegisterLoadingTasks(tasks));
      
      // 等待注册完成
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 初始进度应该是0
      expect(loadingBloc.state.overallProgress, equals(0.0));
      
      // 完成第一个任务
      loadingBloc.add(const CompleteTask(
        taskId: 'task1',
        data: 'result1',
        duration: Duration(milliseconds: 100),
      ));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 进度应该是1/3
      expect(loadingBloc.state.overallProgress, closeTo(0.33, 0.01));
      
      // 完成第二个任务
      loadingBloc.add(const CompleteTask(
        taskId: 'task2',
        data: 'result2',
        duration: Duration(milliseconds: 100),
      ));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 进度应该是2/3
      expect(loadingBloc.state.overallProgress, closeTo(0.67, 0.01));
      
      // 完成第三个任务
      loadingBloc.add(const CompleteTask(
        taskId: 'task3',
        data: 'result3',
        duration: Duration(milliseconds: 100),
      ));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 进度应该是100%
      expect(loadingBloc.state.overallProgress, equals(1.0));
    });
  });
}
