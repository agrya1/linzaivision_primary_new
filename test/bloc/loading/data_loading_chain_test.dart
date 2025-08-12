import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/bloc/loading/data_loading_chain.dart';
import 'package:linzaivision_primary/bloc/loading/loading_task.dart';
import 'package:linzaivision_primary/bloc/loading/loading_strategy_manager.dart';
import 'package:linzaivision_primary/bloc/loading/loading_performance_monitor.dart';

void main() {
  group('DataLoadingChain Tests', () {
    late DataLoadingChain loadingChain;

    setUp(() {
      loadingChain = DataLoadingChain();
    });

    tearDown(() {
      loadingChain.dispose();
    });

    test('应该能够注册和执行简单任务', () async {
      // 创建测试任务
      final task = LoadingTask<String>(
        id: 'test_task',
        name: '测试任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'test_result';
        },
      );

      // 注册任务
      loadingChain.registerTask(task);

      // 执行任务链
      final results = await loadingChain.executeChain();

      // 验证结果
      expect(results, containsPair('test_task', 'test_result'));
    });

    test('应该能够处理任务依赖关系', () async {
      // 创建有依赖关系的任务
      final task1 = LoadingTask<String>(
        id: 'task_1',
        name: '任务1',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'result_1';
        },
      );

      final task2 = LoadingTask<String>(
        id: 'task_2',
        name: '任务2',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 50));
          // 验证依赖任务的结果可用
          expect(context['dependency_task_1'], equals('result_1'));
          return 'result_2';
        },
        dependencies: ['task_1'],
      );

      // 注册任务
      loadingChain.registerTasks([task1, task2]);

      // 执行任务链
      final results = await loadingChain.executeChain();

      // 验证结果
      expect(results, containsPair('task_1', 'result_1'));
      expect(results, containsPair('task_2', 'result_2'));
    });

    test('应该能够并行执行独立任务', () async {
      final startTime = DateTime.now();

      // 创建两个独立的任务
      final task1 = LoadingTask<String>(
        id: 'parallel_1',
        name: '并行任务1',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'parallel_result_1';
        },
      );

      final task2 = LoadingTask<String>(
        id: 'parallel_2',
        name: '并行任务2',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'parallel_result_2';
        },
      );

      // 设置并行执行
      loadingChain.setMaxConcurrentTasks(2);
      loadingChain.registerTasks([task1, task2]);

      // 执行任务链
      final results = await loadingChain.executeChain();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // 验证结果
      expect(results, containsPair('parallel_1', 'parallel_result_1'));
      expect(results, containsPair('parallel_2', 'parallel_result_2'));

      // 验证并行执行（总时间应该小于串行执行时间）
      expect(duration.inMilliseconds, lessThan(350)); // 允许一些误差
    });

    test('应该能够处理任务失败和重试', () async {
      var attemptCount = 0;

      final task = LoadingTask<String>(
        id: 'retry_task',
        name: '重试任务',
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

      loadingChain.registerTask(task);

      final results = await loadingChain.executeChain();

      // 验证重试成功
      expect(results, containsPair('retry_task', 'success_after_retry'));
      expect(attemptCount, equals(3));
    });

    test('应该能够处理任务超时', () async {
      final task = LoadingTask<String>(
        id: 'timeout_task',
        name: '超时任务',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'should_not_complete';
        },
        timeout: const Duration(milliseconds: 100),
      );

      loadingChain.registerTask(task);

      // 执行应该处理超时
      final results = await loadingChain.executeChain();

      // 验证超时任务没有成功结果
      expect(
          results, isNot(containsPair('timeout_task', 'should_not_complete')));
    });

    test('应该能够生成执行统计信息', () async {
      final task1 = LoadingTask<String>(
        id: 'stats_task_1',
        name: '统计任务1',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'result_1';
        },
      );

      final task2 = LoadingTask<String>(
        id: 'stats_task_2',
        name: '统计任务2',
        executor: (context) async {
          throw Exception('模拟失败');
        },
        maxRetries: 1,
      );

      loadingChain.registerTasks([task1, task2]);

      await loadingChain.executeChain();

      final stats = loadingChain.getExecutionStats();

      // 验证统计信息
      expect(stats['totalTasks'], equals(2));
      expect(stats['completedTasks'], equals(1));
      expect(stats['failedTasks'], equals(1));
      expect(stats['successRate'], equals(0.5));
      expect(stats.containsKey('totalDuration'), isTrue);
      expect(stats.containsKey('averageDuration'), isTrue);
    });
  });

  group('LoadingStrategyManager Tests', () {
    late DataLoadingChain loadingChain;
    late LoadingStrategyManager strategyManager;

    setUp(() {
      loadingChain = DataLoadingChain();
      strategyManager = LoadingStrategyManager(loadingChain);
    });

    test('应该根据设备性能选择合适的策略', () {
      final tasks = [
        LoadingTask<String>(
          id: 'test_task',
          name: '测试任务',
          executor: (context) async => 'result',
        ),
      ];

      // 高端设备应该选择并行策略
      final highEndContext = LoadingContext(
        userId: 'user_1',
        deviceType: 'high_end',
        networkType: 'wifi',
        isFirstLaunch: false,
        performanceMetrics: {'deviceScore': 9, 'networkScore': 9},
      );

      final highEndStrategy =
          strategyManager.selectStrategy(tasks, highEndContext);
      expect(highEndStrategy, equals(LoadingStrategy.parallel));

      // 低端设备应该选择懒加载策略（因为没有依赖关系）
      final lowEndContext = LoadingContext(
        userId: 'user_1',
        deviceType: 'low_end',
        networkType: '3g',
        isFirstLaunch: false,
        performanceMetrics: {'deviceScore': 2, 'networkScore': 3},
      );

      final lowEndStrategy =
          strategyManager.selectStrategy(tasks, lowEndContext);
      expect(lowEndStrategy, equals(LoadingStrategy.lazy));
    });

    test('首次启动应该选择优先级策略', () {
      final tasks = [
        LoadingTask<String>(
          id: 'test_task',
          name: '测试任务',
          executor: (context) async => 'result',
        ),
      ];

      final firstLaunchContext = LoadingContext(
        userId: 'user_1',
        deviceType: 'mid_range',
        networkType: '4g',
        isFirstLaunch: true,
      );

      final strategy =
          strategyManager.selectStrategy(tasks, firstLaunchContext);
      expect(strategy, equals(LoadingStrategy.prioritized));
    });
  });

  group('LoadingPerformanceMonitor Tests', () {
    late LoadingPerformanceMonitor monitor;

    setUp(() {
      monitor = LoadingPerformanceMonitor();
    });

    tearDown(() {
      monitor.dispose();
    });

    test('应该能够记录和监控任务性能', () {
      // 开始监控任务
      monitor.startTaskMonitoring('test_task');

      // 模拟任务执行
      Future.delayed(const Duration(milliseconds: 100), () {
        monitor.endTaskMonitoring('test_task', success: true);
      });

      // 记录性能指标
      monitor.recordMetric(
        taskId: 'test_task',
        metric: PerformanceMetric.memoryUsage,
        value: 50.0,
      );

      // 获取任务统计
      final stats = monitor.getTaskStats('test_task');

      expect(stats['taskId'], equals('test_task'));
      expect(stats['executionCount'], equals(1));
      expect(stats['errorCount'], equals(0));
    });

    test('应该能够记录缓存命中率', () {
      // 记录缓存命中和未命中
      monitor.recordCacheHit('cache_task', true);
      monitor.recordCacheHit('cache_task', false);
      monitor.recordCacheHit('cache_task', true);

      final stats = monitor.getTaskStats('cache_task');

      expect(stats['cacheHitRate'], closeTo(66.67, 0.01)); // 2/3 * 100 ≈ 66.67
    });

    test('应该能够生成性能建议', () {
      // 模拟任务执行以产生错误率统计
      monitor.startTaskMonitoring('error_task');
      monitor.endTaskMonitoring('error_task', success: false); // 失败
      monitor.startTaskMonitoring('error_task');
      monitor.endTaskMonitoring('error_task', success: false); // 失败
      monitor.startTaskMonitoring('error_task');
      monitor.endTaskMonitoring('error_task', success: true); // 成功

      final recommendations = monitor.getPerformanceRecommendations();

      expect(recommendations, isNotEmpty);
      expect(recommendations.any((r) => r.contains('错误率')), isTrue);
    });
  });
}
