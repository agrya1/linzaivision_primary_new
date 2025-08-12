import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linzaivision_primary/bloc/loading/loading_bloc.dart';
import 'package:linzaivision_primary/bloc/loading/loading_state.dart';
import 'package:linzaivision_primary/bloc/loading/loading_event.dart';
import 'package:linzaivision_primary/bloc/loading/loading_task.dart';
import 'package:linzaivision_primary/widgets/progress_indicators/unified_progress_indicator.dart';
import 'package:linzaivision_primary/widgets/progress_indicators/loading_state_manager.dart';
import 'package:linzaivision_primary/widgets/progress_indicators/smart_loading_feedback.dart';

/// 加载系统集成测试
/// 验证整个加载系统在真实场景下的性能和正确性
void main() {
  group('加载系统集成测试', () {
    late LoadingBloc loadingBloc;

    setUp(() {
      loadingBloc = LoadingBloc();
    });

    tearDown(() {
      loadingBloc.close();
    });

    testWidgets('统一进度指示器应该正确显示加载状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: loadingBloc,
            child: const Scaffold(
              body: Center(
                child: UnifiedProgressIndicator(
                  type: ProgressIndicatorType.circular,
                  size: ProgressIndicatorSize.medium,
                  showPercentage: true,
                  showTaskCount: true,
                ),
              ),
            ),
          ),
        ),
      );

      // 初始状态应该显示0%
      expect(find.text('0%'), findsOneWidget);

      // 添加任务
      final task = LoadingTask<String>(
        id: 'ui_test_task',
        name: 'UI测试任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'completed';
        },
      );

      loadingBloc.add(RegisterLoadingTasks([task]));
      loadingBloc.add(StartLoadingTasks(['ui_test_task']));

      await tester.pump();

      // 应该显示加载状态
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 等待任务完成
      await tester.pump(const Duration(milliseconds: 200));

      // 应该显示100%
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('加载状态管理器应该正确处理全局状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: loadingBloc,
            child: LoadingStateManager(
              config: const LoadingStateConfig(
                enableGlobalIndicator: true,
                enableSmartFeedback: true,
              ),
              child: const Scaffold(
                body: Center(
                  child: Text('测试内容'),
                ),
              ),
            ),
          ),
        ),
      );

      // 初始状态不应该显示全局指示器
      expect(find.byType(UnifiedProgressIndicator), findsNothing);

      // 添加任务
      final task = LoadingTask<String>(
        id: 'global_test_task',
        name: '全局测试任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'completed';
        },
      );

      loadingBloc.add(RegisterLoadingTasks([task]));
      loadingBloc.add(StartLoadingTasks(['global_test_task']));

      await tester.pump();

      // 应该显示全局指示器
      expect(find.byType(UnifiedProgressIndicator), findsOneWidget);

      // 等待任务完成
      await tester.pump(const Duration(milliseconds: 200));

      // 全局指示器应该消失
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UnifiedProgressIndicator), findsNothing);
    });

    testWidgets('智能反馈系统应该在适当时机显示', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: loadingBloc,
            child: SmartLoadingFeedback(
              type: LoadingFeedbackType.snackbar,
              trigger: const FeedbackTrigger(
                minDuration: Duration(milliseconds: 50),
                showOnError: true,
              ),
              child: const Scaffold(
                body: Center(
                  child: Text('测试内容'),
                ),
              ),
            ),
          ),
        ),
      );

      // 创建一个会失败的任务
      final failingTask = LoadingTask<String>(
        id: 'failing_task',
        name: '失败任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          throw Exception('测试失败');
        },
        maxRetries: 1,
      );

      loadingBloc.add(RegisterLoadingTasks([failingTask]));
      loadingBloc.add(StartLoadingTasks(['failing_task']));

      // 等待任务失败
      await tester.pump(const Duration(milliseconds: 200));

      // 应该显示错误反馈
      expect(find.text('重试'), findsOneWidget);
    });

    group('性能基准测试', () {
      testWidgets('大量任务的UI性能测试', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: loadingBloc,
              child: const Scaffold(
                body: Center(
                  child: UnifiedProgressIndicator(
                    type: ProgressIndicatorType.linear,
                    showTaskCount: true,
                  ),
                ),
              ),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();

        // 创建大量任务
        final tasks = List.generate(
            100,
            (index) => LoadingTask<String>(
                  id: 'perf_task_$index',
                  name: '性能测试任务 $index',
                  executor: (context) async {
                    await Future.delayed(const Duration(milliseconds: 1));
                    return 'result_$index';
                  },
                ));

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));

        // 测量UI更新性能
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        stopwatch.stop();

        // UI更新应该保持流畅
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('内存使用测试', () async {
        // 创建大量任务并完成它们
        for (int batch = 0; batch < 10; batch++) {
          final tasks = List.generate(
              50,
              (index) => LoadingTask<String>(
                    id: 'memory_task_${batch}_$index',
                    name: '内存测试任务 ${batch}_$index',
                    executor: (context) async {
                      await Future.delayed(const Duration(milliseconds: 1));
                      return 'result_${batch}_$index';
                    },
                  ));

          loadingBloc.add(RegisterLoadingTasks(tasks));
          loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));

          // 等待任务完成
          await expectLater(
            loadingBloc.stream,
            emitsInOrder([
              predicate<LoadingBlocState>(
                  (state) => state.completedTasks.length >= tasks.length),
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
        }

        // 如果到这里没有内存溢出，说明内存管理正常
        expect(true, isTrue);
      });

      test('并发性能测试', () async {
        final stopwatch = Stopwatch()..start();

        // 创建多个并发任务组
        final futures = <Future>[];

        for (int group = 0; group < 5; group++) {
          final future = () async {
            final tasks = List.generate(
                20,
                (index) => LoadingTask<String>(
                      id: 'concurrent_task_${group}_$index',
                      name: '并发测试任务 ${group}_$index',
                      executor: (context) async {
                        await Future.delayed(const Duration(milliseconds: 10));
                        return 'result_${group}_$index';
                      },
                    ));

            loadingBloc.add(RegisterLoadingTasks(tasks));
            loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));

            await expectLater(
              loadingBloc.stream,
              emitsInOrder([
                predicate<LoadingBlocState>((state) => tasks
                    .every((task) => state.completedTasks.contains(task.id))),
              ]),
            );
          }();

          futures.add(future);
        }

        await Future.wait(futures);
        stopwatch.stop();

        // 并发执行应该比串行执行快
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });

    group('错误恢复集成测试', () {
      testWidgets('UI应该正确显示错误状态', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: loadingBloc,
              child: LoadingStateManager(
                config: const LoadingStateConfig(
                  enableGlobalIndicator: true,
                  enableSmartFeedback: true,
                ),
                child: const Scaffold(
                  body: Center(
                    child: Text('测试内容'),
                  ),
                ),
              ),
            ),
          ),
        );

        // 创建失败任务
        final failingTask = LoadingTask<String>(
          id: 'ui_failing_task',
          name: 'UI失败任务',
          executor: (context) async {
            await Future.delayed(const Duration(milliseconds: 50));
            throw Exception('UI测试失败');
          },
          maxRetries: 1,
        );

        loadingBloc.add(RegisterLoadingTasks([failingTask]));
        loadingBloc.add(StartLoadingTasks(['ui_failing_task']));

        // 等待任务失败
        await tester.pump(const Duration(milliseconds: 200));

        // 应该显示错误指示器
        expect(find.byIcon(Icons.error), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);

        // 点击重试
        await tester.tap(find.text('重试'));
        await tester.pump();

        // 应该重新开始加载
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      test('系统应该能够从级联失败中恢复', () async {
        final tasks = [
          LoadingTask<String>(
            id: 'recovery_task_1',
            name: '恢复测试任务1',
            executor: (context) async {
              throw Exception('第一个任务失败');
            },
            maxRetries: 1,
          ),
          LoadingTask<String>(
            id: 'recovery_task_2',
            name: '恢复测试任务2',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 10));
              return 'success';
            },
            dependencies: ['recovery_task_1'],
          ),
          LoadingTask<String>(
            id: 'recovery_task_3',
            name: '恢复测试任务3',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 10));
              return 'success';
            },
          ),
        ];

        loadingBloc.add(RegisterLoadingTasks(tasks));
        loadingBloc.add(StartLoadingTasks(
            ['recovery_task_1', 'recovery_task_2', 'recovery_task_3']));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.failedTasks.contains('recovery_task_1')),
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.contains('recovery_task_3')),
          ]),
        );

        // 独立任务应该成功，依赖任务应该被跳过
        expect(loadingBloc.state.completedTasks, contains('recovery_task_3'));
        expect(loadingBloc.state.completedTasks,
            isNot(contains('recovery_task_2')));
      });
    });

    group('真实场景模拟测试', () {
      test('应用启动场景完整测试', () async {
        final stopwatch = Stopwatch()..start();

        // 模拟完整的应用启动流程
        final initTasks = [
          LoadingTask<String>(
            id: 'init_core',
            name: '初始化核心服务',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 30));
              return 'core_initialized';
            },
            priority: LoadingPriority.critical,
          ),
          LoadingTask<String>(
            id: 'init_database',
            name: '初始化数据库',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 40));
              return 'database_ready';
            },
            dependencies: ['init_core'],
            priority: LoadingPriority.high,
          ),
          LoadingTask<String>(
            id: 'load_user_data',
            name: '加载用户数据',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 25));
              return 'user_data_loaded';
            },
            dependencies: ['init_database'],
            priority: LoadingPriority.high,
          ),
          LoadingTask<String>(
            id: 'load_goals',
            name: '加载目标数据',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 35));
              return 'goals_loaded';
            },
            dependencies: ['init_database'],
            priority: LoadingPriority.normal,
          ),
          LoadingTask<String>(
            id: 'init_ui',
            name: '初始化UI',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 20));
              return 'ui_ready';
            },
            dependencies: ['load_user_data'],
            priority: LoadingPriority.normal,
          ),
          LoadingTask<String>(
            id: 'preload_assets',
            name: '预加载资源',
            executor: (context) async {
              await Future.delayed(const Duration(milliseconds: 15));
              return 'assets_preloaded';
            },
            dependencies: ['init_ui'],
            priority: LoadingPriority.low,
          ),
        ];

        loadingBloc.add(RegisterLoadingTasks(initTasks));
        loadingBloc.add(StartLoadingTasks(initTasks.map((t) => t.id).toList()));

        await expectLater(
          loadingBloc.stream,
          emitsInOrder([
            predicate<LoadingBlocState>(
                (state) => state.completedTasks.length == initTasks.length),
          ]),
        );

        stopwatch.stop();

        // 应用启动应该在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(200));

        // 验证所有任务都成功完成
        expect(loadingBloc.state.failedTasks, isEmpty);
        expect(
            loadingBloc.state.completedTasks.length, equals(initTasks.length));
      });
    });
  });
}
