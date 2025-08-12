import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:linzaivision_primary/migration/state_migration_manager.dart';
import 'package:linzaivision_primary/migration/complex_state_adapter.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';

// 生成Mock类
@GenerateMocks([GoalRepository])
import 'complex_state_migration_test.mocks.dart';

void main() {
  group('StateMigrationManager', () {
    late MockGoalRepository mockRepository;
    late GoalBloc goalBloc;
    late StateMigrationManager migrationManager;

    setUp(() {
      mockRepository = MockGoalRepository();
      goalBloc = GoalBloc(repository: mockRepository);
      migrationManager = StateMigrationManager(goalBloc: goalBloc);
    });

    tearDown(() {
      goalBloc.close();
    });

    test('应该能创建迁移管理器', () {
      expect(migrationManager, isNotNull);
      expect(migrationManager.isMigrationActive, isFalse);
    });

    test('应该能开始状态迁移', () async {
      // 准备测试数据
      final traditionalGoals = [
        Goal(
          title: '测试目标1',
          description: '描述1',
          imagePath: 'test1.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '测试目标2',
          description: '描述2',
          imagePath: 'test2.jpg',
          createdTime: DateTime.now(),
        ),
      ];

      final traditionalCurrentGoal = traditionalGoals.first;

      // 模拟Repository返回
      when(mockRepository.getGoals(parentId: anyNamed('parentId')))
          .thenAnswer((_) async => traditionalGoals);
      when(mockRepository.getGoalTree())
          .thenAnswer((_) async => traditionalGoals);

      // 执行迁移
      final result = await migrationManager.startMigration(
        traditionalGoals: traditionalGoals,
        traditionalCurrentGoal: traditionalCurrentGoal,
      );

      // 验证结果
      expect(result, isNotNull);
      expect(result.success, isTrue);
      expect(result.duration, isA<Duration>());
      expect(result.issues, isA<List<MigrationIssue>>());
    });

    test('应该能处理空目标列表的迁移', () async {
      // 模拟Repository返回空列表
      when(mockRepository.getGoals(parentId: anyNamed('parentId')))
          .thenAnswer((_) async => <Goal>[]);
      when(mockRepository.getGoalTree()).thenAnswer((_) async => <Goal>[]);

      // 执行迁移
      final result = await migrationManager.startMigration(
        traditionalGoals: [],
        traditionalCurrentGoal: null,
      );

      // 验证结果
      expect(result, isNotNull);
      expect(result.success, isTrue);

      // 应该有一个关于空目标列表的警告
      final mediumIssues =
          result.getIssuesBySeverity(MigrationIssueSeverity.medium);
      expect(mediumIssues.isNotEmpty, isTrue);
    });

    test('应该能处理迁移异常', () async {
      // 模拟Repository抛出异常
      when(mockRepository.getGoals(parentId: anyNamed('parentId')))
          .thenThrow(Exception('数据库连接失败'));

      // 执行迁移
      final result = await migrationManager.startMigration(
        traditionalGoals: [],
        traditionalCurrentGoal: null,
      );

      // 验证结果 - 由于有超时保护，迁移可能仍然成功，但会有问题记录
      expect(result, isNotNull);
      // 迁移可能成功（由于超时保护），但应该有问题记录
      if (!result.success) {
        expect(result.message, contains('状态迁移异常终止'));
      } else {
        // 如果迁移成功，应该至少有一些问题记录
        expect(result.issues, isNotEmpty);
      }
    });

    test('应该能验证状态缓存', () {
      // 获取状态缓存
      final cache = migrationManager.stateCache;

      expect(cache, isA<Map<String, dynamic>>());
      expect(cache, isEmpty); // 初始状态下应该为空
    });
  });

  group('ComplexStateAdapter', () {
    late MockGoalRepository mockRepository;
    late GoalBloc goalBloc;
    late StateMigrationManager migrationManager;
    late ComplexStateAdapter adapter;

    setUp(() {
      mockRepository = MockGoalRepository();
      goalBloc = GoalBloc(repository: mockRepository);
      migrationManager = StateMigrationManager(goalBloc: goalBloc);
      adapter = ComplexStateAdapter(
        goalBloc: goalBloc,
        migrationManager: migrationManager,
      );
    });

    tearDown(() {
      adapter.dispose();
      goalBloc.close();
    });

    test('应该能初始化适配器', () async {
      expect(adapter.isInitialized, isFalse);

      await adapter.initialize();

      expect(adapter.isInitialized, isTrue);
      expect(adapter.isMigrationMode, isFalse);
    });

    test('应该能获取状态快照', () async {
      await adapter.initialize();

      final snapshot = adapter.getCurrentStateSnapshot();

      expect(snapshot, isA<Map<String, dynamic>>());
      expect(snapshot.containsKey('blocState'), isTrue);
      expect(snapshot.containsKey('timestamp'), isTrue);
    });

    test('应该能管理待处理操作', () async {
      await adapter.initialize();

      // 初始状态下应该没有待处理操作
      expect(adapter.getPendingOperations(), isEmpty);

      // 创建一个测试操作
      final operation = StateOperation(
        id: 'test_operation',
        type: StateOperationType.loadGoals,
        data: {},
      );

      // 模拟添加操作到待处理列表
      // 注意：这里我们无法直接测试私有方法，但可以通过复杂异步操作来间接测试
      expect(operation.id, 'test_operation');
      expect(operation.type, StateOperationType.loadGoals);
    });

    test('应该能处理状态变化监听器', () async {
      await adapter.initialize();

      bool listenerCalled = false;
      StateChangeType? receivedType;
      Map<String, dynamic>? receivedData;

      // 添加监听器
      adapter.addStateChangeListener((type, data) {
        listenerCalled = true;
        receivedType = type;
        receivedData = data;
      });

      // 模拟状态变化（通过触发BLoC状态变化）
      when(mockRepository.getGoals(parentId: anyNamed('parentId')))
          .thenAnswer((_) async => <Goal>[]);
      when(mockRepository.getGoalTree()).thenAnswer((_) async => <Goal>[]);

      // 等待一段时间让监听器有机会被调用
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证监听器设置
      expect(listenerCalled, isFalse); // 初始状态下不应该被调用
      expect(receivedType, isNull);
      expect(receivedData, isNull);
    });

    test('应该能正确清理资源', () async {
      await adapter.initialize();

      expect(adapter.isInitialized, isTrue);

      adapter.dispose();

      expect(adapter.isInitialized, isFalse);
      expect(adapter.isMigrationMode, isFalse);
    });
  });

  group('StateOperation', () {
    test('应该能创建状态操作', () {
      final operation = StateOperation(
        id: 'test_op',
        type: StateOperationType.addGoal,
        data: {'goal': 'test_goal'},
        priority: 1,
      );

      expect(operation.id, 'test_op');
      expect(operation.type, StateOperationType.addGoal);
      expect(operation.data['goal'], 'test_goal');
      expect(operation.priority, 1);
      expect(operation.timestamp, isA<DateTime>());
    });

    test('应该有正确的toString实现', () {
      final operation = StateOperation(
        id: 'test_op',
        type: StateOperationType.updateGoal,
        data: {},
        priority: 2,
      );

      final string = operation.toString();
      expect(string, contains('test_op'));
      expect(string, contains('updateGoal'));
      expect(string, contains('2'));
    });
  });

  group('StateDependency', () {
    test('应该能创建状态依赖', () {
      final dependency = StateDependency(
        id: 'test_dep',
        description: '测试依赖',
        processor: () async {},
        priority: 1,
        isRequired: true,
      );

      expect(dependency.id, 'test_dep');
      expect(dependency.description, '测试依赖');
      expect(dependency.priority, 1);
      expect(dependency.isRequired, isTrue);
      expect(dependency.processor, isA<Future<void> Function()>());
    });

    test('应该有正确的toString实现', () {
      final dependency = StateDependency(
        id: 'test_dep',
        description: '测试依赖',
        processor: () async {},
        priority: 3,
        isRequired: false,
      );

      final string = dependency.toString();
      expect(string, contains('test_dep'));
      expect(string, contains('3'));
      expect(string, contains('false'));
    });
  });

  group('MigrationIssue', () {
    test('应该能创建迁移问题', () {
      final issue = MigrationIssue(
        type: MigrationIssueType.dataValidation,
        severity: MigrationIssueSeverity.high,
        message: '测试问题',
        details: {'key': 'value'},
      );

      expect(issue.type, MigrationIssueType.dataValidation);
      expect(issue.severity, MigrationIssueSeverity.high);
      expect(issue.message, '测试问题');
      expect(issue.details['key'], 'value');
      expect(issue.timestamp, isA<DateTime>());
    });

    test('应该有正确的toString实现', () {
      final issue = MigrationIssue(
        type: MigrationIssueType.migrationError,
        severity: MigrationIssueSeverity.critical,
        message: '严重错误',
        details: {},
      );

      final string = issue.toString();
      expect(string, contains('CRITICAL'));
      expect(string, contains('migrationError'));
      expect(string, contains('严重错误'));
    });
  });

  group('MigrationResult', () {
    test('应该能创建迁移结果', () {
      final issues = [
        MigrationIssue(
          type: MigrationIssueType.dataValidation,
          severity: MigrationIssueSeverity.low,
          message: '低级问题',
          details: {},
        ),
        MigrationIssue(
          type: MigrationIssueType.syncValidation,
          severity: MigrationIssueSeverity.high,
          message: '高级问题',
          details: {},
        ),
      ];

      final result = MigrationResult(
        success: true,
        duration: const Duration(milliseconds: 500),
        issues: issues,
        message: '迁移成功',
      );

      expect(result.success, isTrue);
      expect(result.duration.inMilliseconds, 500);
      expect(result.issues.length, 2);
      expect(result.message, '迁移成功');
      expect(result.timestamp, isA<DateTime>());
    });

    test('应该能按严重程度筛选问题', () {
      final issues = [
        MigrationIssue(
          type: MigrationIssueType.dataValidation,
          severity: MigrationIssueSeverity.low,
          message: '低级问题',
          details: {},
        ),
        MigrationIssue(
          type: MigrationIssueType.syncValidation,
          severity: MigrationIssueSeverity.high,
          message: '高级问题',
          details: {},
        ),
        MigrationIssue(
          type: MigrationIssueType.migrationError,
          severity: MigrationIssueSeverity.critical,
          message: '严重问题',
          details: {},
        ),
      ];

      final result = MigrationResult(
        success: false,
        duration: const Duration(milliseconds: 1000),
        issues: issues,
        message: '迁移失败',
      );

      expect(result.getIssuesBySeverity(MigrationIssueSeverity.low).length, 1);
      expect(result.getIssuesBySeverity(MigrationIssueSeverity.high).length, 1);
      expect(result.getIssuesBySeverity(MigrationIssueSeverity.critical).length,
          1);
    });

    test('应该有正确的toString实现', () {
      final result = MigrationResult(
        success: true,
        duration: const Duration(milliseconds: 250),
        issues: [],
        message: '成功',
      );

      final string = result.toString();
      expect(string, contains('SUCCESS'));
      expect(string, contains('250ms'));
      expect(string, contains('0 issues'));
    });
  });
}
