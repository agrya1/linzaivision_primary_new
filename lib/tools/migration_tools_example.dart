import 'package:flutter/foundation.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/app/app_state.dart';
import '../models/goal.dart';
import 'migration_validator.dart';
import 'automated_test_framework.dart';

/// 状态迁移工具使用示例
///
/// 展示如何在实际迁移过程中使用验证工具和测试框架
class MigrationToolsExample {
  /// 示例1: 验证BLoC状态与传统状态的一致性
  static Future<void> exampleStateConsistencyValidation() async {
    if (kDebugMode) {
      print('=== 状态一致性验证示例 ===');
    }

    // 模拟传统状态管理的数据
    final traditionalGoals = [
      Goal(
        title: '学习Flutter',
        description: '掌握Flutter开发技能',
        imagePath: 'flutter.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 7)),
        targetDate: DateTime.now().add(const Duration(days: 30)),
      ),
      Goal(
        title: '完成项目',
        description: '完成当前开发项目',
        imagePath: 'project.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 3)),
        targetDate: DateTime.now().add(const Duration(days: 15)),
      ),
    ];

    final traditionalCurrentGoal = traditionalGoals.first;

    // 模拟BLoC状态
    final blocState = GoalsLoaded(
      goals: traditionalGoals,
      allGoals: traditionalGoals,
      currentGoal: traditionalCurrentGoal,
    );

    // 运行验证
    final validationResult =
        await MigrationValidator.validateGoalStateConsistency(
      blocState: blocState,
      traditionalGoals: traditionalGoals,
      traditionalCurrentGoal: traditionalCurrentGoal,
    );

    if (kDebugMode) {
      print('验证结果: ${validationResult.isValid ? "通过" : "失败"}');
      print('问题数量: ${validationResult.issues.length}');
      for (final issue in validationResult.issues) {
        print('- $issue');
      }
    }
  }

  /// 示例2: 应用状态健康检查
  static Future<void> exampleAppStateHealthCheck() async {
    if (kDebugMode) {
      print('\n=== 应用状态健康检查示例 ===');
    }

    // 模拟健康的应用状态
    final healthyState = AppReady(
      version: '1.0.0',
      buildNumber: '1',
      lastSyncTime: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    // 模拟有问题的应用状态
    final problematicState = AppReady(
      version: '', // 版本信息为空
      buildNumber: '1',
      lastSyncTime: DateTime.now().subtract(const Duration(hours: 2)),
      globalError: '网络连接失败',
      globalErrorCode: 'NETWORK_ERROR',
    );

    // 检查健康状态
    final healthyResult = await MigrationValidator.validateAppStateHealth(
      appState: healthyState,
    );

    final problematicResult = await MigrationValidator.validateAppStateHealth(
      appState: problematicState,
    );

    if (kDebugMode) {
      print('健康状态验证: ${healthyResult.isValid ? "通过" : "失败"}');
      print('问题状态验证: ${problematicResult.isValid ? "通过" : "失败"}');
      print('问题状态的问题数量: ${problematicResult.issues.length}');
    }
  }

  /// 示例3: 性能指标验证
  static Future<void> examplePerformanceValidation() async {
    if (kDebugMode) {
      print('\n=== 性能指标验证示例 ===');
    }

    // 模拟良好的性能指标
    final goodPerformanceResult =
        await MigrationValidator.validatePerformanceMetrics(
      stateUpdateDuration: const Duration(milliseconds: 50),
      memoryUsageMB: 150,
      uiResponseTime: const Duration(milliseconds: 30),
    );

    // 模拟较差的性能指标
    final poorPerformanceResult =
        await MigrationValidator.validatePerformanceMetrics(
      stateUpdateDuration: const Duration(milliseconds: 800),
      memoryUsageMB: 600,
      uiResponseTime: const Duration(milliseconds: 300),
    );

    if (kDebugMode) {
      print('良好性能验证: ${goodPerformanceResult.isValid ? "通过" : "失败"}');
      print('较差性能验证: ${poorPerformanceResult.isValid ? "通过" : "失败"}');
      print('性能问题数量: ${poorPerformanceResult.issues.length}');

      for (final issue in poorPerformanceResult.issues) {
        print('- ${issue.message}');
      }
    }
  }

  /// 示例4: 综合验证
  static Future<void> exampleComprehensiveValidation() async {
    if (kDebugMode) {
      print('\n=== 综合验证示例 ===');
    }

    // 准备测试数据
    final appState = AppReady(
      version: '1.0.0',
      buildNumber: '1',
      lastSyncTime: DateTime.now(),
    );

    final goals = [
      Goal(
        title: '测试目标',
        description: '用于验证的测试目标',
        imagePath: 'test.jpg',
        createdTime: DateTime.now(),
      ),
    ];

    final blocState = GoalsLoaded(
      goals: goals,
      allGoals: goals,
    );

    // 运行综合验证
    final summary = await MigrationValidator.runComprehensiveValidation(
      blocGoalState: blocState,
      traditionalGoals: goals,
      appState: appState,
      stateUpdateDuration: const Duration(milliseconds: 80),
      memoryUsageMB: 180,
      uiResponseTime: const Duration(milliseconds: 40),
    );

    if (kDebugMode) {
      print('综合验证结果: ${summary.overallValid ? "通过" : "失败"}');
      print('验证项目数量: ${summary.results.length}');
      print('总问题数量: ${summary.allIssues.length}');

      for (final result in summary.results) {
        print(
            '- ${result.validationType.name}: ${result.isValid ? "通过" : "失败"} (${result.issues.length}个问题)');
      }
    }
  }

  /// 示例5: 自动化测试框架使用
  static Future<void> exampleAutomatedTesting() async {
    if (kDebugMode) {
      print('\n=== 自动化测试框架示例 ===');
    }

    // 创建测试用例
    final testCases = [
      TestCase(
        name: '目标加载测试',
        description: '验证目标能够正确加载',
        result: TestCaseResult.passed,
        duration: const Duration(milliseconds: 150),
      ),
      TestCase(
        name: '目标添加测试',
        description: '验证目标能够正确添加',
        result: TestCaseResult.passed,
        duration: const Duration(milliseconds: 200),
      ),
      TestCase(
        name: '目标删除测试',
        description: '验证目标能够正确删除',
        result: TestCaseResult.failed,
        duration: const Duration(milliseconds: 100),
        error: '删除操作失败',
      ),
    ];

    // 创建测试结果
    final testResult = TestResult(
      testType: TestType.blocFunctionality,
      testCases: testCases,
      totalDuration: const Duration(milliseconds: 450),
      passedCount: 2,
      failedCount: 1,
    );

    // 创建测试套件
    final testSuite = TestSuite(
      results: [testResult],
      totalDuration: const Duration(milliseconds: 450),
      totalPassed: 2,
      totalFailed: 1,
    );

    if (kDebugMode) {
      print('测试结果摘要:');
      print('- 成功率: ${(testResult.successRate * 100).toStringAsFixed(1)}%');
      print('- 总耗时: ${testResult.totalDuration.inMilliseconds}ms');
      print('- 测试用例:');

      for (final testCase in testCases) {
        print('  $testCase');
      }

      print('\n测试套件摘要:');
      print('- $testSuite');
    }
  }

  /// 运行所有示例
  static Future<void> runAllExamples() async {
    if (kDebugMode) {
      print('🚀 开始运行状态迁移工具示例\n');
    }

    try {
      await exampleStateConsistencyValidation();
      await exampleAppStateHealthCheck();
      await examplePerformanceValidation();
      await exampleComprehensiveValidation();
      await exampleAutomatedTesting();

      if (kDebugMode) {
        print('\n✅ 所有示例运行完成！');
      }
    } catch (e) {
      if (kDebugMode) {
        print('\n❌ 示例运行失败: $e');
      }
    }
  }
}
