import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../bloc/goal/goal_bloc.dart';
import '../models/goal.dart';
import 'state_migration_manager.dart';
import 'complex_state_adapter.dart';

/// 复杂状态迁移使用示例
///
/// 展示如何在实际应用中使用复杂状态管理场景迁移
class ComplexMigrationExample {
  /// 示例1: 基本状态迁移
  static Future<void> exampleBasicStateMigration({
    required GoalBloc goalBloc,
    required List<Goal> traditionalGoals,
    required Goal? traditionalCurrentGoal,
  }) async {
    if (kDebugMode) {
      print('=== 基本状态迁移示例 ===');
    }

    // 创建迁移管理器
    final migrationManager = StateMigrationManager(goalBloc: goalBloc);

    try {
      // 执行状态迁移
      final result = await migrationManager.startMigration(
        traditionalGoals: traditionalGoals,
        traditionalCurrentGoal: traditionalCurrentGoal,
        additionalState: {
          'migrationReason': '从传统状态管理迁移到BLoC',
          'timestamp': DateTime.now(),
        },
      );

      if (kDebugMode) {
        print('迁移结果: ${result.success ? "成功" : "失败"}');
        print('耗时: ${result.duration.inMilliseconds}ms');
        print('问题数量: ${result.issues.length}');

        for (final issue in result.issues) {
          print('- $issue');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('迁移失败: $e');
      }
    }
  }

  /// 示例2: 复杂状态适配器使用
  static Future<void> exampleComplexStateAdapter({
    required GoalBloc goalBloc,
    required Map<String, dynamic> traditionalState,
  }) async {
    if (kDebugMode) {
      print('\n=== 复杂状态适配器示例 ===');
    }

    // 创建迁移管理器和复杂状态适配器
    final migrationManager = StateMigrationManager(goalBloc: goalBloc);
    final adapter = ComplexStateAdapter(
      goalBloc: goalBloc,
      migrationManager: migrationManager,
    );

    try {
      // 初始化适配器
      await adapter.initialize();

      // 添加状态变化监听器
      adapter.addStateChangeListener((type, data) {
        if (kDebugMode) {
          print('状态变化: $type');
          print('数据: $data');
        }
      });

      // 开始迁移模式
      final migrationResult = await adapter.startMigrationMode(
        traditionalState: traditionalState,
        enableValidation: true,
      );

      if (kDebugMode) {
        print('迁移模式结果: ${migrationResult.success ? "成功" : "失败"}');
        print('适配器状态: 迁移模式=${adapter.isMigrationMode}');
      }

      // 获取状态快照
      final snapshot = adapter.getCurrentStateSnapshot();
      if (kDebugMode) {
        print('状态快照: ${snapshot.keys.join(", ")}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('复杂状态适配器使用失败: $e');
      }
    } finally {
      // 清理资源
      adapter.dispose();
    }
  }

  /// 示例3: 异步操作管理
  static Future<void> exampleAsyncOperationManagement({
    required GoalBloc goalBloc,
  }) async {
    if (kDebugMode) {
      print('\n=== 异步操作管理示例 ===');
    }

    final migrationManager = StateMigrationManager(goalBloc: goalBloc);
    final adapter = ComplexStateAdapter(
      goalBloc: goalBloc,
      migrationManager: migrationManager,
    );

    try {
      await adapter.initialize();

      // 创建复杂异步操作
      final operation = StateOperation(
        id: 'complex_goal_operation',
        type: StateOperationType.addGoal,
        data: {
          'goal': Goal(
            title: '复杂异步操作测试',
            description: '测试复杂异步操作管理',
            imagePath: 'async_test.jpg',
            createdTime: DateTime.now(),
          ),
        },
        priority: 1,
      );

      // 处理复杂异步操作
      final result = await adapter.handleComplexAsyncOperation<String>(
        operationId: 'complex_goal_operation',
        operation: () async {
          // 模拟复杂的异步操作
          await Future.delayed(const Duration(milliseconds: 500));
          return '异步操作完成';
        },
        stateOperation: operation,
        timeout: const Duration(seconds: 10),
      );

      if (kDebugMode) {
        print('异步操作结果: $result');
        print('待处理操作数量: ${adapter.getPendingOperations().length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('异步操作管理失败: $e');
      }
    } finally {
      adapter.dispose();
    }
  }

  /// 示例4: 状态依赖关系处理
  static Future<void> exampleStateDependencyHandling({
    required GoalBloc goalBloc,
  }) async {
    if (kDebugMode) {
      print('\n=== 状态依赖关系处理示例 ===');
    }

    final migrationManager = StateMigrationManager(goalBloc: goalBloc);
    final adapter = ComplexStateAdapter(
      goalBloc: goalBloc,
      migrationManager: migrationManager,
    );

    try {
      await adapter.initialize();

      // 创建状态依赖
      final dependencies = [
        StateDependency(
          id: 'database_connection',
          description: '数据库连接依赖',
          priority: 1,
          isRequired: true,
          processor: () async {
            if (kDebugMode) {
              print('处理数据库连接依赖');
            }
            await Future.delayed(const Duration(milliseconds: 100));
          },
        ),
        StateDependency(
          id: 'cache_initialization',
          description: '缓存初始化依赖',
          priority: 2,
          isRequired: false,
          processor: () async {
            if (kDebugMode) {
              print('处理缓存初始化依赖');
            }
            await Future.delayed(const Duration(milliseconds: 50));
          },
        ),
        StateDependency(
          id: 'user_preferences',
          description: '用户偏好设置依赖',
          priority: 3,
          isRequired: false,
          processor: () async {
            if (kDebugMode) {
              print('处理用户偏好设置依赖');
            }
            await Future.delayed(const Duration(milliseconds: 30));
          },
        ),
      ];

      // 处理状态依赖关系
      await adapter.handleStateDependencies(dependencies: dependencies);

      if (kDebugMode) {
        print('所有状态依赖处理完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('状态依赖关系处理失败: $e');
      }
    } finally {
      adapter.dispose();
    }
  }

  /// 示例5: 完整的迁移流程
  static Future<void> exampleCompleteeMigrationFlow({
    required GoalBloc goalBloc,
    required BuildContext context,
  }) async {
    if (kDebugMode) {
      print('\n=== 完整迁移流程示例 ===');
    }

    // 模拟传统状态数据
    final traditionalGoals = [
      Goal(
        title: '学习Flutter BLoC',
        description: '掌握BLoC状态管理模式',
        imagePath: 'bloc_learning.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 5)),
        targetDate: DateTime.now().add(const Duration(days: 30)),
      ),
      Goal(
        title: '完成状态迁移',
        description: '将应用从传统状态管理迁移到BLoC',
        imagePath: 'migration.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 2)),
        targetDate: DateTime.now().add(const Duration(days: 15)),
      ),
    ];

    final traditionalCurrentGoal = traditionalGoals.first;

    final traditionalState = {
      'goals': traditionalGoals,
      'currentGoal': traditionalCurrentGoal,
      'isLoading': false,
      'error': null,
      'lastUpdateTime': DateTime.now(),
    };

    // 创建迁移组件
    final migrationManager = StateMigrationManager(goalBloc: goalBloc);
    final adapter = ComplexStateAdapter(
      goalBloc: goalBloc,
      migrationManager: migrationManager,
    );

    try {
      if (kDebugMode) {
        print('步骤1: 初始化复杂状态适配器');
      }
      await adapter.initialize();

      if (kDebugMode) {
        print('步骤2: 设置状态变化监听器');
      }
      adapter.addStateChangeListener((type, data) {
        if (kDebugMode) {
          print('监听到状态变化: $type');
        }
      });

      if (kDebugMode) {
        print('步骤3: 开始迁移模式');
      }
      final migrationResult = await adapter.startMigrationMode(
        traditionalState: traditionalState,
        enableValidation: true,
      );

      if (migrationResult.success) {
        if (kDebugMode) {
          print('步骤4: 迁移成功，处理后续操作');
        }

        // 创建一个复杂的后续操作
        final postMigrationOperation = StateOperation(
          id: 'post_migration_sync',
          type: StateOperationType.loadGoals,
          data: {'reason': 'post_migration_refresh'},
        );

        await adapter.handleComplexAsyncOperation<void>(
          operationId: 'post_migration_sync',
          operation: () async {
            if (kDebugMode) {
              print('执行迁移后同步操作');
            }
            await Future.delayed(const Duration(milliseconds: 200));
          },
          stateOperation: postMigrationOperation,
        );

        if (kDebugMode) {
          print('完整迁移流程成功完成！');
          print('最终状态快照: ${adapter.getCurrentStateSnapshot().keys.join(", ")}');
        }
      } else {
        if (kDebugMode) {
          print('迁移失败: ${migrationResult.message}');
          print('问题详情:');
          for (final issue in migrationResult.issues) {
            print('- $issue');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('完整迁移流程失败: $e');
      }
    } finally {
      if (kDebugMode) {
        print('步骤5: 清理资源');
      }
      adapter.dispose();
    }
  }

  /// 运行所有示例
  static Future<void> runAllExamples({
    required GoalBloc goalBloc,
    required BuildContext context,
  }) async {
    if (kDebugMode) {
      print('🚀 开始运行复杂状态迁移示例\n');
    }

    try {
      // 准备测试数据
      final testGoals = [
        Goal(
          title: '示例目标1',
          description: '用于测试的示例目标',
          imagePath: 'example1.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '示例目标2',
          description: '另一个测试目标',
          imagePath: 'example2.jpg',
          createdTime: DateTime.now(),
        ),
      ];

      final testState = {
        'goals': testGoals,
        'currentGoal': testGoals.first,
        'metadata': {'version': '1.0', 'source': 'example'},
      };

      // 运行所有示例
      await exampleBasicStateMigration(
        goalBloc: goalBloc,
        traditionalGoals: testGoals,
        traditionalCurrentGoal: testGoals.first,
      );

      await exampleComplexStateAdapter(
        goalBloc: goalBloc,
        traditionalState: testState,
      );

      await exampleAsyncOperationManagement(goalBloc: goalBloc);

      await exampleStateDependencyHandling(goalBloc: goalBloc);

      await exampleCompleteeMigrationFlow(
        goalBloc: goalBloc,
        context: context,
      );

      if (kDebugMode) {
        print('\n✅ 所有复杂状态迁移示例运行完成！');
      }
    } catch (e) {
      if (kDebugMode) {
        print('\n❌ 示例运行失败: $e');
      }
    }
  }
}
