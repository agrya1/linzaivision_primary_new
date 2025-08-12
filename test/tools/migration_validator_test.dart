import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/tools/migration_validator.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/bloc/app/app_state.dart';
import 'package:linzaivision_primary/models/goal.dart';

void main() {
  group('MigrationValidator', () {
    test('ValidationIssue应该正确创建', () {
      final issue = ValidationIssue(
        type: ValidationIssueType.dataInconsistency,
        severity: ValidationSeverity.high,
        message: '测试问题',
        details: {'test': 'value'},
      );

      expect(issue.type, ValidationIssueType.dataInconsistency);
      expect(issue.severity, ValidationSeverity.high);
      expect(issue.message, '测试问题');
      expect(issue.details['test'], 'value');
      expect(issue.timestamp, isA<DateTime>());
    });

    test('ValidationResult应该正确分类问题', () {
      final issues = [
        ValidationIssue(
          type: ValidationIssueType.dataInconsistency,
          severity: ValidationSeverity.critical,
          message: '严重问题',
          details: {},
        ),
        ValidationIssue(
          type: ValidationIssueType.stateInconsistency,
          severity: ValidationSeverity.high,
          message: '高级问题',
          details: {},
        ),
        ValidationIssue(
          type: ValidationIssueType.performanceWarning,
          severity: ValidationSeverity.low,
          message: '低级问题',
          details: {},
        ),
      ];

      final result = ValidationResult(
        isValid: false,
        issues: issues,
        timestamp: DateTime.now(),
        validationType: ValidationType.goalStateConsistency,
      );

      expect(result.getIssuesBySeverity(ValidationSeverity.critical).length, 1);
      expect(result.getIssuesBySeverity(ValidationSeverity.high).length, 1);
      expect(result.getIssuesBySeverity(ValidationSeverity.low).length, 1);
      expect(
          result.getIssuesAtLeastSeverity(ValidationSeverity.high).length, 2);
    });

    test('ValidationSummary应该正确统计结果', () {
      final results = [
        ValidationResult(
          isValid: true,
          issues: [],
          timestamp: DateTime.now(),
          validationType: ValidationType.goalStateConsistency,
        ),
        ValidationResult(
          isValid: false,
          issues: [
            ValidationIssue(
              type: ValidationIssueType.dataInconsistency,
              severity: ValidationSeverity.high,
              message: '测试问题',
              details: {},
            ),
          ],
          timestamp: DateTime.now(),
          validationType: ValidationType.appStateHealth,
        ),
      ];

      final summary = ValidationSummary(
        results: results,
        timestamp: DateTime.now(),
        overallValid: false,
      );

      final stats = summary.statistics;
      expect(stats['totalValidations'], 2);
      expect(stats['validValidations'], 1);
      expect(stats['totalIssues'], 1);
      expect(stats['highIssues'], 1);
    });

    test('validateAppStateHealth应该正确验证AppReady状态', () async {
      final appState = AppReady(
        version: '1.0.0',
        buildNumber: '1',
        lastSyncTime: DateTime.now(),
        globalError: '测试错误',
        globalErrorCode: 'TEST_ERROR',
      );

      final result = await MigrationValidator.validateAppStateHealth(
        appState: appState,
      );

      expect(result.validationType, ValidationType.appStateHealth);
      expect(result.isValid, false); // 因为有全局错误
      expect(result.issues.isNotEmpty, true);

      // 检查是否检测到全局错误
      final errorIssues = result.issues
          .where((issue) => issue.type == ValidationIssueType.runtimeError)
          .toList();
      expect(errorIssues.isNotEmpty, true);
    });

    test('validateAppStateHealth应该正确验证AppError状态', () async {
      const appState = AppError('应用错误', code: 'APP_ERROR');

      final result = await MigrationValidator.validateAppStateHealth(
        appState: appState,
      );

      expect(result.validationType, ValidationType.appStateHealth);
      expect(result.isValid, false);
      expect(result.issues.isNotEmpty, true);

      // 检查是否检测到应用错误状态
      final errorIssues = result.issues
          .where((issue) => issue.severity == ValidationSeverity.critical)
          .toList();
      expect(errorIssues.isNotEmpty, true);
    });

    test('validatePerformanceMetrics应该正确验证性能指标', () async {
      final result = await MigrationValidator.validatePerformanceMetrics(
        stateUpdateDuration: const Duration(milliseconds: 600), // 超过高阈值
        memoryUsageMB: 600, // 超过高阈值
        uiResponseTime: const Duration(milliseconds: 300), // 超过高阈值
      );

      expect(result.validationType, ValidationType.performanceMetrics);
      expect(result.isValid, false); // 因为所有指标都超过阈值且达到高严重程度
      expect(result.issues.length, 3); // 应该有3个性能问题

      // 检查性能警告
      final performanceIssues = result.issues
          .where(
              (issue) => issue.type == ValidationIssueType.performanceWarning)
          .toList();
      expect(performanceIssues.length, 3);

      // 检查严重程度
      final highSeverityIssues = result.issues
          .where((issue) => issue.severity == ValidationSeverity.high)
          .toList();
      expect(highSeverityIssues.length, 3); // 所有问题都应该是高严重程度
    });

    test('validatePerformanceMetrics应该通过良好的性能指标', () async {
      final result = await MigrationValidator.validatePerformanceMetrics(
        stateUpdateDuration: const Duration(milliseconds: 50), // 在阈值内
        memoryUsageMB: 100, // 在阈值内
        uiResponseTime: const Duration(milliseconds: 30), // 在阈值内
      );

      expect(result.validationType, ValidationType.performanceMetrics);
      expect(result.isValid, true); // 所有指标都在阈值内
      expect(result.issues.isEmpty, true); // 应该没有问题
    });

    test('runComprehensiveValidation应该运行多个验证', () async {
      final appState = AppReady(
        version: '1.0.0',
        buildNumber: '1',
        lastSyncTime: DateTime.now(),
      );

      final summary = await MigrationValidator.runComprehensiveValidation(
        appState: appState,
        stateUpdateDuration: const Duration(milliseconds: 50),
        memoryUsageMB: 100,
        uiResponseTime: const Duration(milliseconds: 30),
      );

      expect(summary.results.isNotEmpty, true);
      expect(summary.results.length, greaterThanOrEqualTo(2)); // 至少应用状态和性能验证

      // 检查是否包含不同类型的验证
      final validationTypes =
          summary.results.map((r) => r.validationType).toSet();
      expect(validationTypes.contains(ValidationType.appStateHealth), true);
      expect(validationTypes.contains(ValidationType.repositoryHealth), true);
      expect(validationTypes.contains(ValidationType.performanceMetrics), true);
    });
  });
}
