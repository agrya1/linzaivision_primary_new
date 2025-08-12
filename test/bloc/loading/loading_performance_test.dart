import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:linzaivision_primary/bloc/loading/loading_bloc.dart';
import 'package:linzaivision_primary/bloc/loading/loading_state.dart';
import 'package:linzaivision_primary/bloc/loading/loading_event.dart';
import 'package:linzaivision_primary/bloc/loading/loading_task.dart';
import 'package:linzaivision_primary/bloc/loading/data_loading_chain.dart';
import 'package:linzaivision_primary/bloc/loading/loading_strategy_manager.dart';
import 'package:linzaivision_primary/bloc/loading/loading_performance_monitor.dart';

/// 加载性能测试
/// 验证加载性能优化的效果和正确性
void main() {
  group('加载性能优化验证', () {
    late LoadingBloc loadingBloc;
    late DataLoadingChain dataLoadingChain;
    late LoadingStrategyManager strategyManager;
    late LoadingPerformanceMonitor performanceMonitor;

    setUp(() {
      dataLoadingChain = DataLoadingChain();
      strategyManager = LoadingStrategyManager(dataLoadingChain);
      performanceMonitor = LoadingPerformanceMonitor();
      loadingBloc = LoadingBloc();
    });

    tearDown(() {
      loadingBloc.close();
    });

    group('基础性能测试', () {
      test('应该能够快速注册大量任务', () async {
        final stopwatch = Stopwatch()..start();

        // 创建100个任务
        final tasks = List.generate(
            100,
            (index) => LoadingTask<String>(
                  id: 'task_$index',
                  name: '任务 $index',
                  executor: (context) async {
                    await Future.delayed(const Duration(milliseconds: 10));
                    return 'result_$index';
                  },
                ));

        loadingBloc.add(RegisterLoadingTasks(tasks));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.taskStates.length == 100),
          ]),
        );

        stopwatch.stop();

        // 注册100个任务应该在100ms内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('应该能够高效处理并行任务', () async {
        final stopwatch = Stopwatch()..start();

        // 创建10个可以并行执行的任务
        final tasks = List.generate(
            10,
            (index) => LoadingTask<String>(
                  id: 'parallel_task_$index',
                  name: '并行任务 $index',
                  executor: (context) async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    return 'parallel_result_$index';
                  },
                  priority: LoadingPriority.high,
                ));

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.taskStates.length == 10),
            predicate<LoadingBlocState>(
                (state) => state.activeTasks.length == 10),
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == 10),
          ]),
        );

        stopwatch.stop();

        // 并行执行10个100ms的任务应该在200ms内完成（考虑并行度）
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('应该能够优化依赖任务的执行顺序', () async {
        final executionOrder = <String>[];

        final tasks = [
          LoadingTask<String>(
            id: 'task_a',
            name: '任务A',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 50));
              executionOrder.add('A');
              return 'A';
            },
            priority: LoadingPriority.high,
          ),
          LoadingTask<String>(
            id: 'task_b',
            name: '任务B',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 30));
              executionOrder.add('B');
              return 'B';
            },
            dependencies: ['task_a'],
          ),
          LoadingTask<String>(
            id: 'task_c',
            name: '任务C',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 20));
              executionOrder.add('C');
              return 'C';
            },
            dependencies: ['task_a'],
          ),
        ];

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(['task_a', 'task_b', 'task_c']));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.taskStates.length == 3),
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == 3),
          ]),
        );

        // 验证执行顺序：A必须先执行，B和C可以并行
        expect(executionOrder.first, equals('A'));
        expect(executionOrder.contains('B'), isTrue);
        expect(executionOrder.contains('C'), isTrue);
      });
    });

    group('策略优化测试', () {
      test('应该根据设备性能选择合适的策略', () {
        // 高性能设备
        final highEndContext = LoadingContext(
          userId: 'user_1',
          deviceType: 'high_end',
          networkType: 'wifi',
          isFirstLaunch: false,
          performanceMetrics: {'deviceScore': 9, 'networkScore': 8},
        );

        final highEndStrategy =
            strategyManager.selectStrategy([], highEndContext);
        expect(highEndStrategy, equals(LoadingStrategy.parallel));

        // 低性能设备
        final lowEndContext = LoadingContext(
          userId: 'user_1',
          deviceType: 'low_end',
          networkType: '3g',
          isFirstLaunch: false,
          performanceMetrics: {'deviceScore': 3, 'networkScore': 2},
        );

        final lowEndStrategy =
            strategyManager.selectStrategy([], lowEndContext);
        expect(lowEndStrategy, equals(LoadingStrategy.lazy));
      });

      test('应该能够动态调整策略', () async {
        // 模拟网络状况变化
        final context1 = LoadingContext(
          userId: 'user_1',
          deviceType: 'medium',
          networkType: 'wifi',
          isFirstLaunch: false,
          performanceMetrics: {'deviceScore': 6, 'networkScore': 8},
        );

        final context2 = LoadingContext(
          userId: 'user_1',
          deviceType: 'medium',
          networkType: '3g',
          isFirstLaunch: false,
          performanceMetrics: {'deviceScore': 6, 'networkScore': 3},
        );

        final strategy1 = strategyManager.selectStrategy([], context1);
        final strategy2 = strategyManager.selectStrategy([], context2);

        // WiFi环境下应该使用更激进的策略
        expect(strategy1, isNot(equals(strategy2)));
      });
    });

    group('性能监控测试', () {
      test('应该能够准确监控任务执行性能', () async {
        performanceMonitor.startTaskMonitoring('test_task');

        await Future.delayed(const Duration(milliseconds: 100));

        performanceMonitor.endTaskMonitoring('test_task', success: true);

        final stats = performanceMonitor.getTaskStats('test_task');
        expect(stats['executionCount'], equals(1));
        expect(stats['averageExecutionTime'], greaterThan(90));
        expect(stats['averageExecutionTime'], lessThan(150));
        expect(stats['successRate'], equals(100.0));
      });

      test('应该能够检测性能问题并提供建议', () async {
        // 模拟慢任务
        for (int i = 0; i < 5; i++) {
          performanceMonitor.startTaskMonitoring('slow_task');
          await Future.delayed(const Duration(milliseconds: 200));
          performanceMonitor.endTaskMonitoring('slow_task', success: true);
        }

        final recommendations =
            performanceMonitor.getPerformanceRecommendations();
        expect(recommendations, isNotEmpty);
        expect(
          recommendations.any((r) => r.contains('执行时间') || r.contains('性能')),
          isTrue,
        );
      });

      test('应该能够监控缓存命中率', () {
        // 模拟缓存操作
        performanceMonitor.recordCacheHit('test_cache', true);
        performanceMonitor.recordCacheHit('test_cache', true);
        performanceMonitor.recordCacheHit('test_cache', false);

        final stats = performanceMonitor.getTaskStats('test_cache');
        expect(stats['cacheHitRate'], closeTo(66.67, 0.01)); // 2/3 * 100
      });
    });

    group('内存和资源管理测试', () {
      test('应该能够正确清理已完成的任务', () async {
        final tasks = List.generate(
            10,
            (index) => LoadingTask<String>(
                  id: 'cleanup_task_$index',
                  name: '清理测试任务 $index',
                  executor: (context) async {
                    await Future.delayed(const Duration(milliseconds: 10));
                    return 'result_$index';
                  },
                ));

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == 10),
          ]),
        );

        // 清理已完成的任务
        loadingBloc.add(const ResetLoadingState());

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>((state) => state.taskStates.isEmpty),
          ]),
        );
      });

      test('应该能够处理任务取消而不泄漏资源', () async {
        final task = LoadingTask<String>(
          id: 'cancel_task',
          name: '取消测试任务',
          executor: (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'should_not_complete';
          },
        );

        loadingBloc.add(RegisterLoadingTasks([task]));
        loadingBloc.add(StartLoadingTasks(['cancel_task']));

        // 等待任务开始
        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.activeTasks.contains('cancel_task')),
          ]),
        );

        // 取消任务
        loadingBloc.add(CancelLoadingTask('cancel_task'));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => !state.activeTasks.contains('cancel_task')),
          ]),
        );
      });
    });

    group('错误处理和恢复测试', () {
      test('应该能够高效处理任务失败和重试', () async {
        int attemptCount = 0;

        final task = LoadingTask<String>(
          id: 'retry_task',
          name: '重试测试任务',
          executor: (context) async {
            attemptCount++;
            if (attemptCount < 3) {
              throw Exception('模拟失败');
            }
            return 'success_after_retry';
          },
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 10),
        );

        loadingBloc.add(RegisterLoadingTasks([task]));
        loadingBloc.add(StartLoadingTasks(['retry_task']));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.contains('retry_task')),
          ]),
        );

        expect(attemptCount, equals(3));
      });

      test('应该能够处理级联失败', () async {
        final tasks = [
          LoadingTask<String>(
            id: 'fail_task',
            name: '失败任务',
            executor: (context) async {
              throw Exception('任务失败');
            },
            maxRetries: 1,
          ),
          LoadingTask<String>(
            id: 'dependent_task',
            name: '依赖任务',
            executor: (context) async {
              return 'should_not_execute';
            },
            dependencies: ['fail_task'],
          ),
        ];

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(['fail_task', 'dependent_task']));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.failedTasks.contains('fail_task')),
            predicate<LoadingBlocState>((state) =>
                !state.activeTasks.contains('dependent_task') &&
                !state.completedTasks.contains('dependent_task')),
          ]),
        );
      });
    });

    group('实际场景性能测试', () {
      test('应该能够高效处理应用启动场景', () async {
        final stopwatch = Stopwatch()..start();

        // 模拟应用启动任务
        final startupTasks = [
          LoadingTask<String>(
            id: 'init_database',
            name: '初始化数据库',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 50));
              return 'database_ready';
            },
            priority: LoadingPriority.critical,
          ),
          LoadingTask<String>(
            id: 'load_user_settings',
            name: '加载用户设置',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 30));
              return 'settings_loaded';
            },
            dependencies: ['init_database'],
            priority: LoadingPriority.high,
          ),
          LoadingTask<String>(
            id: 'load_goals',
            name: '加载目标数据',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 40));
              return 'goals_loaded';
            },
            dependencies: ['init_database'],
            priority: LoadingPriority.normal,
          ),
          LoadingTask<String>(
            id: 'preload_cache',
            name: '预加载缓存',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 20));
              return 'cache_preloaded';
            },
            dependencies: ['load_user_settings', 'load_goals'],
            priority: LoadingPriority.low,
          ),
        ];

        loadingBloc.add(RegisterLoadingTasks(startupTasks));
        loadingBloc
            .add(StartLoadingTasks(startupTasks.map((t) => t.id).toList()));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == 4),
          ]),
        );

        stopwatch.stop();

        // 应用启动应该在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('应该能够处理大数据量加载', () async {
        final stopwatch = Stopwatch()..start();

        // 模拟加载大量数据
        final dataLoadingTasks = List.generate(
            50,
            (index) => LoadingTask<String>(
                  id: 'data_task_$index',
                  name: '数据任务 $index',
                  executor: (context) async {
                    // 模拟数据处理
                    await Future.delayed(const Duration(milliseconds: 5));
                    return 'data_$index';
                  },
                  priority: index < 10
                      ? LoadingPriority.high
                      : LoadingPriority.normal,
                ));

        loadingBloc.add(RegisterLoadingTasks(dataLoadingTasks));
        loadingBloc
            .add(StartLoadingTasks(dataLoadingTasks.map((t) => t.id).toList()));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == 50),
          ]),
        );

        stopwatch.stop();

        // 50个任务应该能够高效完成
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });
  });
}
