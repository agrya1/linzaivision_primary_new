/// 事务处理效果验证器
///
/// 测试复杂操作的正确性、性能和数据一致性，验证事务处理机制
library;

import 'dart:async';
import 'transaction_manager.dart';
import 'chain_operation_processor.dart';
import 'cross_component_sync.dart';
import 'rollback_manager.dart';
import 'batch_processor.dart';
import 'loading_optimizer.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart';

/// 验证测试类型
enum ValidationTestType {
  transactionIntegrity, // 事务完整性测试
  chainOperationTest, // 连锁操作测试
  rollbackTest, // 回滚机制测试
  syncPerformanceTest, // 同步性能测试
  batchProcessingTest, // 批量处理测试
  loadingOptimizationTest, // 加载优化测试
  stressTest, // 压力测试
  concurrencyTest, // 并发测试
}

/// 验证结果
class ValidationResult {
  final ValidationTestType testType;
  final bool passed;
  final Duration executionTime;
  final Map<String, dynamic> metrics;
  final List<String> errors;
  final List<String> warnings;
  final String? details;

  const ValidationResult({
    required this.testType,
    required this.passed,
    required this.executionTime,
    required this.metrics,
    required this.errors,
    required this.warnings,
    this.details,
  });

  factory ValidationResult.success(
    ValidationTestType testType,
    Duration executionTime,
    Map<String, dynamic> metrics,
  ) {
    return ValidationResult(
      testType: testType,
      passed: true,
      executionTime: executionTime,
      metrics: metrics,
      errors: [],
      warnings: [],
    );
  }

  factory ValidationResult.failure(
    ValidationTestType testType,
    Duration executionTime,
    List<String> errors, {
    List<String> warnings = const [],
    Map<String, dynamic> metrics = const {},
  }) {
    return ValidationResult(
      testType: testType,
      passed: false,
      executionTime: executionTime,
      metrics: metrics,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// 验证报告
class ValidationReport {
  final DateTime timestamp;
  final List<ValidationResult> results;
  final Duration totalExecutionTime;
  final int passedTests;
  final int failedTests;
  final double successRate;
  final Map<String, dynamic> overallMetrics;

  ValidationReport({
    required this.results,
    required this.totalExecutionTime,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        passedTests = results.where((r) => r.passed).length,
        failedTests = results.where((r) => !r.passed).length,
        successRate = results.isEmpty
            ? 0.0
            : results.where((r) => r.passed).length / results.length,
        overallMetrics = _calculateOverallMetrics(results);

  static Map<String, dynamic> _calculateOverallMetrics(
      List<ValidationResult> results) {
    if (results.isEmpty) return {};

    final totalErrors = results.fold(0, (sum, r) => sum + r.errors.length);
    final totalWarnings = results.fold(0, (sum, r) => sum + r.warnings.length);
    final avgExecutionTime = Duration(
        milliseconds:
            (results.fold(0, (sum, r) => sum + r.executionTime.inMilliseconds) /
                    results.length)
                .round());

    return {
      'totalErrors': totalErrors,
      'totalWarnings': totalWarnings,
      'averageExecutionTime': avgExecutionTime.inMilliseconds,
      'testTypes': results.map((r) => r.testType.toString()).toSet().toList(),
    };
  }
}

/// 事务处理验证器
class TransactionValidator {
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  final TransactionManager transactionManager;
  final ChainOperationProcessor chainProcessor;
  final CrossComponentSyncManager syncManager;
  final RollbackManager rollbackManager;

  TransactionValidator({
    required this.databaseHelper,
    required this.goalBloc,
    required this.transactionManager,
    required this.chainProcessor,
    required this.syncManager,
    required this.rollbackManager,
  });

  /// 运行所有验证测试
  Future<ValidationReport> runAllValidationTests() async {
    final stopwatch = Stopwatch()..start();
    final results = <ValidationResult>[];

    // 运行各种验证测试
    results.add(await validateTransactionIntegrity());
    results.add(await validateChainOperations());
    results.add(await validateRollbackMechanism());
    results.add(await validateSyncPerformance());
    results.add(await validateBatchProcessing());
    results.add(await validateLoadingOptimization());
    results.add(await runStressTest());
    results.add(await runConcurrencyTest());

    stopwatch.stop();

    return ValidationReport(
      results: results,
      totalExecutionTime: stopwatch.elapsed,
    );
  }

  /// 验证事务完整性
  Future<ValidationResult> validateTransactionIntegrity() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建测试目标
      final testGoal = Goal(
        title: 'Transaction Test Goal',
        description: 'Test goal for transaction integrity',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      // 测试事务创建
      final createTransaction = transactionManager.createTransaction(
        description: 'Test goal creation',
        operations: [
          _CreateTestGoalOperation(testGoal, databaseHelper, goalBloc)
        ],
      );

      final createResult =
          await transactionManager.commitTransaction(createTransaction.id);

      if (!createResult.success) {
        errors.add('Transaction creation failed: ${createResult.error}');
      }

      // 验证数据一致性
      final createdGoal = await databaseHelper.getGoal(testGoal.id!);
      if (createdGoal == null) {
        errors.add('Goal not found after transaction commit');
      }

      // 测试事务回滚
      final updateTransaction = transactionManager.createTransaction(
        description: 'Test goal update with rollback',
        operations: [_FailingTestOperation()],
      );

      final updateResult =
          await transactionManager.commitTransaction(updateTransaction.id);

      if (updateResult.success) {
        warnings.add('Expected transaction to fail for rollback test');
      }

      // 验证回滚后数据一致性
      final goalAfterRollback = await databaseHelper.getGoal(testGoal.id!);
      if (goalAfterRollback?.title != testGoal.title) {
        errors.add('Data inconsistency after rollback');
      }

      // 清理测试数据
      await databaseHelper.deleteGoal(testGoal.id!);

      metrics['transactionsCreated'] = 2;
      metrics['dataConsistencyChecks'] = 2;
    } catch (e) {
      errors.add('Transaction integrity test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.transactionIntegrity, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.transactionIntegrity, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 验证连锁操作
  Future<ValidationResult> validateChainOperations() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建测试目标层级
      final parentGoal = Goal(
        title: 'Parent Goal',
        description: 'Parent goal for chain test',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      final childGoal = Goal(
        title: 'Child Goal',
        description: 'Child goal for chain test',
        imagePath: '',
        status: GoalStatus.pending,
        parentId: parentGoal.id,
        createdTime: DateTime.now(),
      );

      // 插入测试数据
      await databaseHelper.insertGoal(parentGoal);
      await databaseHelper.insertGoal(childGoal);

      // 测试删除连锁操作
      final chainResult =
          await chainProcessor.processGoalDeletionChain(parentGoal);

      if (!chainResult.success) {
        errors.add('Chain operation failed: ${chainResult.error}');
      }

      // 验证连锁效果
      final deletedParent = await databaseHelper.getGoal(parentGoal.id!);
      final deletedChild = await databaseHelper.getGoal(childGoal.id!);

      if (deletedParent != null) {
        errors.add('Parent goal not deleted in chain operation');
      }

      if (deletedChild != null) {
        errors.add('Child goal not deleted in chain operation');
      }

      metrics['chainSteps'] = chainResult.executedSteps.length;
      metrics['chainSuccessRate'] = chainResult.successRate;
    } catch (e) {
      errors.add('Chain operation test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.chainOperationTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.chainOperationTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 验证回滚机制
  Future<ValidationResult> validateRollbackMechanism() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建测试目标
      final testGoal = Goal(
        title: 'Rollback Test Goal',
        description: 'Test goal for rollback',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      await databaseHelper.insertGoal(testGoal);

      // 创建回滚点
      final rollbackPoint = RollbackPoint.goalUpdate(
        testGoal,
        testGoal.copyWith(title: 'Updated Title'),
      );

      final rollbackPointId =
          rollbackManager.createRollbackPoint(rollbackPoint);

      // 执行更新操作
      final updatedGoal = testGoal.copyWith(title: 'Updated Title');
      await databaseHelper.updateGoal(updatedGoal);

      // 执行回滚
      final rollbackResult =
          await rollbackManager.executeRollback(rollbackPointId);

      if (!rollbackResult.success) {
        errors.add('Rollback failed: ${rollbackResult.error}');
      }

      // 验证回滚效果
      final restoredGoal = await databaseHelper.getGoal(testGoal.id!);
      if (restoredGoal?.title != testGoal.title) {
        errors.add('Goal not properly restored after rollback');
      }

      // 清理测试数据
      await databaseHelper.deleteGoal(testGoal.id!);

      metrics['rollbackPointsCreated'] = 1;
      metrics['rollbacksExecuted'] = 1;
      metrics['rollbackSuccessRate'] = rollbackResult.success ? 1.0 : 0.0;
    } catch (e) {
      errors.add('Rollback mechanism test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.rollbackTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.rollbackTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 验证同步性能
  Future<ValidationResult> validateSyncPerformance() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 注册测试组件
      final config = ComponentSyncConfig(
        componentId: 'test_component',
        subscribedEvents: {SyncEventType.goalAdded, SyncEventType.goalUpdated},
        enableBatching: true,
        batchWindow: const Duration(milliseconds: 100),
      );

      syncManager.registerComponent(config);

      // 发布测试事件
      final testGoal = Goal(
        title: 'Sync Test Goal',
        description: 'Test goal for sync',
        imagePath: '',
        status: GoalStatus.pending,
        createdTime: DateTime.now(),
      );

      final eventCount = 100;
      final eventStopwatch = Stopwatch()..start();

      for (int i = 0; i < eventCount; i++) {
        final event = SyncEvent.goalAdded(testGoal, source: 'test_source');
        syncManager.publishEvent(event);
      }

      // 等待事件处理
      await Future.delayed(const Duration(milliseconds: 200));

      eventStopwatch.stop();

      final stats = syncManager.getStats();

      if (stats.totalEvents < eventCount) {
        warnings.add(
            'Not all events were processed: ${stats.totalEvents}/$eventCount');
      }

      if (stats.processingRate < 0.9) {
        warnings.add('Low processing rate: ${stats.processingRate}');
      }

      metrics['eventsPublished'] = eventCount;
      metrics['eventsProcessed'] = stats.processedEvents;
      metrics['processingRate'] = stats.processingRate;
      metrics['averageProcessingTime'] =
          stats.averageProcessingTime.inMilliseconds;

      // 清理
      syncManager.unregisterComponent('test_component');
    } catch (e) {
      errors.add('Sync performance test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.syncPerformanceTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.syncPerformanceTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 验证批量处理
  Future<ValidationResult> validateBatchProcessing() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建批量处理器
      final processor = BatchProcessor<Goal>(
        processor: (item) async {
          // 模拟处理
          await Future.delayed(const Duration(milliseconds: 10));
          return item.data;
        },
      );

      // 创建测试数据
      final testItems = List.generate(
          50,
          (i) => BatchOperationItem<Goal>(
                id: 'test_$i',
                data: Goal(
                  title: 'Test Goal $i',
                  description: 'Test description $i',
                  imagePath: '',
                  status: GoalStatus.pending,
                  createdTime: DateTime.now(),
                ),
                type: BatchOperationType.create,
              ));

      // 执行批量处理
      final batchResult = await processor.processBatch(testItems);

      if (batchResult.successCount != testItems.length) {
        errors.add(
            'Batch processing failed: ${batchResult.failureCount} failures');
      }

      if (batchResult.successRate < 1.0) {
        warnings
            .add('Batch success rate below 100%: ${batchResult.successRate}');
      }

      metrics['itemsProcessed'] = testItems.length;
      metrics['successCount'] = batchResult.successCount;
      metrics['failureCount'] = batchResult.failureCount;
      metrics['successRate'] = batchResult.successRate;
      metrics['totalDuration'] = batchResult.totalDuration.inMilliseconds;
    } catch (e) {
      errors.add('Batch processing test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.batchProcessingTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.batchProcessingTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 验证加载优化
  Future<ValidationResult> validateLoadingOptimization() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建加载优化器
      final optimizer = LoadingOptimizer(
        databaseHelper: databaseHelper,
        config: const LoadingOptimizationConfig(
          strategy: LoadingStrategy.cached,
          cacheStrategy: CacheStrategy.memory,
        ),
      );

      // 测试加载性能
      final loadCount = 20;
      final loadTimes = <Duration>[];

      for (int i = 0; i < loadCount; i++) {
        final loadStopwatch = Stopwatch()..start();
        await optimizer.loadGoals(offset: 0, limit: 10);
        loadStopwatch.stop();
        loadTimes.add(loadStopwatch.elapsed);
      }

      final stats = optimizer.getPerformanceStats();

      if (stats.cacheHitRate < 0.5) {
        warnings.add('Low cache hit rate: ${stats.cacheHitRate}');
      }

      if (stats.averageLoadTime.inMilliseconds > 100) {
        warnings.add(
            'High average load time: ${stats.averageLoadTime.inMilliseconds}ms');
      }

      metrics['loadOperations'] = loadCount;
      metrics['cacheHitRate'] = stats.cacheHitRate;
      metrics['averageLoadTime'] = stats.averageLoadTime.inMilliseconds;
      metrics['maxLoadTime'] = stats.maxLoadTime.inMilliseconds;

      optimizer.dispose();
    } catch (e) {
      errors.add('Loading optimization test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(ValidationTestType.loadingOptimizationTest,
            stopwatch.elapsed, metrics)
        : ValidationResult.failure(ValidationTestType.loadingOptimizationTest,
            stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 运行压力测试
  Future<ValidationResult> runStressTest() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 创建大量测试数据
      final testGoals = List.generate(
          1000,
          (i) => Goal(
                title: 'Stress Test Goal $i',
                description: 'Stress test description $i',
                imagePath: '',
                status: GoalStatus.pending,
                createdTime: DateTime.now(),
              ));

      // 批量插入
      final insertStopwatch = Stopwatch()..start();
      for (final goal in testGoals) {
        await databaseHelper.insertGoal(goal);
      }
      insertStopwatch.stop();

      // 批量查询
      final queryStopwatch = Stopwatch()..start();
      final loadedGoals = await databaseHelper.getGoals();
      queryStopwatch.stop();

      // 批量删除
      final deleteStopwatch = Stopwatch()..start();
      for (final goal in testGoals) {
        await databaseHelper.deleteGoal(goal.id!);
      }
      deleteStopwatch.stop();

      if (loadedGoals.length < testGoals.length) {
        errors.add(
            'Not all goals were loaded: ${loadedGoals.length}/${testGoals.length}');
      }

      metrics['testDataSize'] = testGoals.length;
      metrics['insertTime'] = insertStopwatch.elapsed.inMilliseconds;
      metrics['queryTime'] = queryStopwatch.elapsed.inMilliseconds;
      metrics['deleteTime'] = deleteStopwatch.elapsed.inMilliseconds;
      metrics['throughput'] = testGoals.length / stopwatch.elapsed.inSeconds;
    } catch (e) {
      errors.add('Stress test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.stressTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.stressTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }

  /// 运行并发测试
  Future<ValidationResult> runConcurrencyTest() async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    final warnings = <String>[];
    final metrics = <String, dynamic>{};

    try {
      // 并发创建事务
      final concurrentTransactions = <Future<TransactionResult>>[];

      for (int i = 0; i < 10; i++) {
        final testGoal = Goal(
          title: 'Concurrent Test Goal $i',
          description: 'Concurrent test description $i',
          imagePath: '',
          status: GoalStatus.pending,
          createdTime: DateTime.now(),
        );

        final transaction = transactionManager.createTransaction(
          description: 'Concurrent test transaction $i',
          operations: [
            _CreateTestGoalOperation(testGoal, databaseHelper, goalBloc)
          ],
        );

        concurrentTransactions
            .add(transactionManager.commitTransaction(transaction.id));
      }

      // 等待所有事务完成
      final results = await Future.wait(concurrentTransactions);

      final successCount = results.where((r) => r.success).length;
      final failureCount = results.length - successCount;

      if (failureCount > 0) {
        warnings.add('Some concurrent transactions failed: $failureCount');
      }

      metrics['concurrentTransactions'] = results.length;
      metrics['successfulTransactions'] = successCount;
      metrics['failedTransactions'] = failureCount;
      metrics['concurrencySuccessRate'] = successCount / results.length;
    } catch (e) {
      errors.add('Concurrency test failed: $e');
    }

    stopwatch.stop();

    return errors.isEmpty
        ? ValidationResult.success(
            ValidationTestType.concurrencyTest, stopwatch.elapsed, metrics)
        : ValidationResult.failure(
            ValidationTestType.concurrencyTest, stopwatch.elapsed, errors,
            warnings: warnings, metrics: metrics);
  }
}

/// 测试用的创建目标操作
class _CreateTestGoalOperation extends TransactionOperation {
  final Goal goal;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;

  _CreateTestGoalOperation(this.goal, this.databaseHelper, this.goalBloc)
      : super(
          id: 'create_test_goal_${goal.title}',
          description: 'Create test goal: ${goal.title}',
        );

  @override
  Future<TransactionOperationResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      await databaseHelper.insertGoal(goal);
      goalBloc.add(AddGoal(goal));

      stopwatch.stop();
      return TransactionOperationResult.success(
        data: {'goalId': goal.id},
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TransactionOperationResult.failure(
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (goal.id != null) {
      await databaseHelper.deleteGoal(goal.id!);
      goalBloc.add(DeleteGoal(goal.id!));
    }
  }

  @override
  Future<bool> validate() async {
    return goal.title.isNotEmpty;
  }

  @override
  Set<String> getAffectedResources() {
    return {'goal_create'};
  }
}

/// 测试用的失败操作
class _FailingTestOperation extends TransactionOperation {
  _FailingTestOperation()
      : super(
          id: 'failing_test_operation',
          description: 'Failing test operation',
        );

  @override
  Future<TransactionOperationResult> execute() async {
    throw Exception('Intentional test failure');
  }

  @override
  Future<void> rollback() async {
    // No rollback needed for test
  }

  @override
  Future<bool> validate() async {
    return true;
  }

  @override
  Set<String> getAffectedResources() {
    return {'test_resource'};
  }
}
