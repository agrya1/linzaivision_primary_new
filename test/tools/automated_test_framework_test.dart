import 'package:flutter_test/flutter_test.dart';
import 'package:linzaivision_primary/tools/automated_test_framework.dart';

void main() {
  group('AutomatedTestFramework', () {
    test('TestCase应该正确创建', () {
      final testCase = TestCase(
        name: '测试用例',
        description: '测试描述',
        result: TestCaseResult.passed,
        duration: const Duration(milliseconds: 100),
      );

      expect(testCase.name, '测试用例');
      expect(testCase.description, '测试描述');
      expect(testCase.result, TestCaseResult.passed);
      expect(testCase.duration.inMilliseconds, 100);
      expect(testCase.timestamp, isA<DateTime>());
    });

    test('TestCase应该正确转换为JSON', () {
      final testCase = TestCase(
        name: '测试用例',
        description: '测试描述',
        result: TestCaseResult.failed,
        duration: const Duration(milliseconds: 200),
        error: '测试错误',
        details: {'key': 'value'},
      );

      final json = testCase.toJson();

      expect(json['name'], '测试用例');
      expect(json['description'], '测试描述');
      expect(json['result'], 'failed');
      expect(json['duration'], 200);
      expect(json['error'], '测试错误');
      expect(json['details']['key'], 'value');
      expect(json['timestamp'], isA<String>());
    });

    test('TestCase toString应该显示正确的状态图标', () {
      final passedCase = TestCase(
        name: '通过测试',
        description: '描述',
        result: TestCaseResult.passed,
        duration: const Duration(milliseconds: 100),
      );

      final failedCase = TestCase(
        name: '失败测试',
        description: '描述',
        result: TestCaseResult.failed,
        duration: const Duration(milliseconds: 100),
      );

      final skippedCase = TestCase(
        name: '跳过测试',
        description: '描述',
        result: TestCaseResult.skipped,
        duration: const Duration(milliseconds: 100),
      );

      final errorCase = TestCase(
        name: '错误测试',
        description: '描述',
        result: TestCaseResult.error,
        duration: const Duration(milliseconds: 100),
      );

      expect(passedCase.toString(), contains('✅'));
      expect(failedCase.toString(), contains('❌'));
      expect(skippedCase.toString(), contains('⏭️'));
      expect(errorCase.toString(), contains('⚠️'));
    });

    test('TestResult应该正确计算成功率', () {
      final testCases = [
        TestCase(
          name: '测试1',
          description: '描述',
          result: TestCaseResult.passed,
          duration: const Duration(milliseconds: 100),
        ),
        TestCase(
          name: '测试2',
          description: '描述',
          result: TestCaseResult.passed,
          duration: const Duration(milliseconds: 100),
        ),
        TestCase(
          name: '测试3',
          description: '描述',
          result: TestCaseResult.failed,
          duration: const Duration(milliseconds: 100),
        ),
      ];

      final result = TestResult(
        testType: TestType.blocFunctionality,
        testCases: testCases,
        totalDuration: const Duration(milliseconds: 300),
        passedCount: 2,
        failedCount: 1,
      );

      expect(result.successRate, closeTo(0.667, 0.001));
      expect(result.testCases.length, 3);
      expect(result.passedCount, 2);
      expect(result.failedCount, 1);
    });

    test('TestResult应该正确转换为JSON', () {
      final testCases = [
        TestCase(
          name: '测试1',
          description: '描述',
          result: TestCaseResult.passed,
          duration: const Duration(milliseconds: 100),
        ),
      ];

      final result = TestResult(
        testType: TestType.performanceBenchmark,
        testCases: testCases,
        totalDuration: const Duration(milliseconds: 100),
        passedCount: 1,
        failedCount: 0,
      );

      final json = result.toJson();

      expect(json['testType'], 'performanceBenchmark');
      expect(json['testCases'], isA<List>());
      expect(json['totalDuration'], 100);
      expect(json['passedCount'], 1);
      expect(json['failedCount'], 0);
      expect(json['successRate'], 1.0);
      expect(json['timestamp'], isA<String>());
    });

    test('TestSuite应该正确统计所有结果', () {
      final results = [
        TestResult(
          testType: TestType.blocFunctionality,
          testCases: [
            TestCase(
              name: '测试1',
              description: '描述',
              result: TestCaseResult.passed,
              duration: const Duration(milliseconds: 100),
            ),
            TestCase(
              name: '测试2',
              description: '描述',
              result: TestCaseResult.failed,
              duration: const Duration(milliseconds: 100),
            ),
          ],
          totalDuration: const Duration(milliseconds: 200),
          passedCount: 1,
          failedCount: 1,
        ),
        TestResult(
          testType: TestType.stateConsistency,
          testCases: [
            TestCase(
              name: '测试3',
              description: '描述',
              result: TestCaseResult.passed,
              duration: const Duration(milliseconds: 100),
            ),
          ],
          totalDuration: const Duration(milliseconds: 100),
          passedCount: 1,
          failedCount: 0,
        ),
      ];

      final suite = TestSuite(
        results: results,
        totalDuration: const Duration(milliseconds: 300),
        totalPassed: 2,
        totalFailed: 1,
      );

      expect(suite.totalTests, 3);
      expect(suite.overallSuccessRate, closeTo(0.667, 0.001));
      expect(suite.allTestCases.length, 3);

      // 验证结果数量
      expect(suite.results.length, 2);
      expect(suite.totalPassed, 2);
      expect(suite.totalFailed, 1);
    });

    test('TestSuite应该正确转换为JSON', () {
      final results = [
        TestResult(
          testType: TestType.integrationTest,
          testCases: [],
          totalDuration: const Duration(milliseconds: 100),
          passedCount: 0,
          failedCount: 0,
        ),
      ];

      final suite = TestSuite(
        results: results,
        totalDuration: const Duration(milliseconds: 100),
        totalPassed: 0,
        totalFailed: 0,
      );

      final json = suite.toJson();

      expect(json['results'], isA<List>());
      expect(json['totalDuration'], 100);
      expect(json['totalPassed'], 0);
      expect(json['totalFailed'], 0);
      expect(json['totalTests'], 0);
      expect(json['overallSuccessRate'], 0.0);
      expect(json['timestamp'], isA<String>());
    });

    test('TestSuite toString应该显示正确的摘要', () {
      final suite = TestSuite(
        results: [],
        totalDuration: const Duration(milliseconds: 500),
        totalPassed: 8,
        totalFailed: 2,
      );

      final summary = suite.toString();

      expect(summary, contains('TestSuite'));
      expect(summary, contains('8/10 passed'));
      expect(summary, contains('80.0%'));
      expect(summary, contains('500ms'));
    });
  });
}
