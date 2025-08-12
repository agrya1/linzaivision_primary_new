import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/goal/goal_event.dart';
import '../models/goal.dart';
import 'state_migration_manager.dart';

/// 状态变化类型
enum StateChangeType {
  blocStateChanged, // BLoC状态变化
  migrationCompleted, // 迁移完成
  migrationFailed, // 迁移失败
  operationCompleted, // 操作完成
  operationFailed, // 操作失败
}

/// 状态操作类型
enum StateOperationType {
  loadGoals, // 加载目标
  addGoal, // 添加目标
  updateGoal, // 更新目标
  deleteGoal, // 删除目标
  selectGoal, // 选择目标
}

/// 状态操作
class StateOperation {
  final String id;
  final StateOperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int priority;

  StateOperation({
    required this.id,
    required this.type,
    required this.data,
    this.priority = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'StateOperation(id: $id, type: $type, priority: $priority)';
  }
}

/// 状态依赖
class StateDependency {
  final String id;
  final String description;
  final int priority;
  final bool isRequired;
  final Future<void> Function() processor;

  StateDependency({
    required this.id,
    required this.description,
    required this.processor,
    this.priority = 0,
    this.isRequired = false,
  });

  @override
  String toString() {
    return 'StateDependency(id: $id, priority: $priority, required: $isRequired)';
  }
}

/// 状态变化监听器
typedef StateChangeListener = void Function(
    StateChangeType type, Map<String, dynamic> data);

/// 复杂状态管理场景适配器
///
/// 处理复杂的状态管理场景迁移，包括：
/// - 多状态同步
/// - 异步操作管理
/// - 状态依赖关系
/// - 错误恢复机制
class ComplexStateAdapter {
  final GoalBloc _goalBloc;
  final StateMigrationManager _migrationManager;

  // 状态管理
  bool _isInitialized = false;
  bool _isMigrationMode = false;

  // 状态缓存
  final Map<String, dynamic> _stateSnapshot = {};
  final List<StateOperation> _pendingOperations = [];

  // 监听器
  StreamSubscription<GoalState>? _blocSubscription;
  final List<StateChangeListener> _listeners = [];

  ComplexStateAdapter({
    required GoalBloc goalBloc,
    required StateMigrationManager migrationManager,
  })  : _goalBloc = goalBloc,
        _migrationManager = migrationManager;

  /// 初始化适配器
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print('【ComplexStateAdapter】初始化复杂状态适配器');
    }

    try {
      // 设置BLoC状态监听
      _blocSubscription = _goalBloc.stream.listen(_handleBlocStateChange);

      // 创建初始状态快照
      await _createStateSnapshot();

      _isInitialized = true;

      if (kDebugMode) {
        print('【ComplexStateAdapter】复杂状态适配器初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【ComplexStateAdapter】初始化失败: $e');
      }
      rethrow;
    }
  }

  /// 开始迁移模式
  Future<MigrationResult> startMigrationMode({
    required Map<String, dynamic> traditionalState,
    bool enableValidation = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('适配器未初始化');
    }

    if (kDebugMode) {
      print('【ComplexStateAdapter】开始迁移模式');
    }

    _isMigrationMode = true;

    try {
      // 创建迁移前状态快照
      await _createStateSnapshot();

      // 提取传统状态数据
      final traditionalGoals = traditionalState['goals'] as List<Goal>? ?? [];
      final traditionalCurrentGoal = traditionalState['currentGoal'] as Goal?;

      // 执行状态迁移
      final migrationResult = await _migrationManager.startMigration(
        traditionalGoals: traditionalGoals,
        traditionalCurrentGoal: traditionalCurrentGoal,
        additionalState: traditionalState,
      );

      if (migrationResult.success) {
        // 迁移成功，处理待处理的操作
        await _processPendingOperations();

        // 通知监听器
        _notifyListeners(StateChangeType.migrationCompleted, {
          'migrationResult': migrationResult,
          'traditionalState': traditionalState,
        });
      } else {
        // 迁移失败，恢复状态
        await _restoreStateFromSnapshot();

        _notifyListeners(StateChangeType.migrationFailed, {
          'migrationResult': migrationResult,
          'error': migrationResult.message,
        });
      }

      return migrationResult;
    } catch (e) {
      if (kDebugMode) {
        print('【ComplexStateAdapter】迁移模式启动失败: $e');
      }

      // 恢复状态
      await _restoreStateFromSnapshot();

      return MigrationResult(
        success: false,
        duration: Duration.zero,
        issues: [
          MigrationIssue(
            type: MigrationIssueType.migrationError,
            severity: MigrationIssueSeverity.critical,
            message: '迁移模式启动失败: $e',
            details: {'error': e.toString()},
          ),
        ],
        message: '迁移模式启动异常',
      );
    }
  }

  /// 处理复杂的异步操作
  Future<T> handleComplexAsyncOperation<T>({
    required String operationId,
    required Future<T> Function() operation,
    required StateOperation stateOperation,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (kDebugMode) {
      print('【ComplexStateAdapter】处理复杂异步操作: $operationId');
    }

    // 添加到待处理操作列表
    _pendingOperations.add(stateOperation);

    try {
      // 执行操作
      final result = await operation().timeout(timeout);

      // 操作成功，移除待处理操作
      _pendingOperations.removeWhere((op) => op.id == operationId);

      // 通知监听器
      _notifyListeners(StateChangeType.operationCompleted, {
        'operationId': operationId,
        'result': result,
        'stateOperation': stateOperation,
      });

      if (kDebugMode) {
        print('【ComplexStateAdapter】异步操作完成: $operationId');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('【ComplexStateAdapter】异步操作失败: $operationId, 错误: $e');
      }

      // 操作失败，移除待处理操作
      _pendingOperations.removeWhere((op) => op.id == operationId);

      // 通知监听器
      _notifyListeners(StateChangeType.operationFailed, {
        'operationId': operationId,
        'error': e.toString(),
        'stateOperation': stateOperation,
      });

      rethrow;
    }
  }

  /// 处理状态依赖关系
  Future<void> handleStateDependencies({
    required List<StateDependency> dependencies,
  }) async {
    if (kDebugMode) {
      print('【ComplexStateAdapter】处理状态依赖关系: ${dependencies.length}个依赖');
    }

    // 按优先级排序依赖
    dependencies.sort((a, b) => a.priority.compareTo(b.priority));

    for (final dependency in dependencies) {
      try {
        await _processDependency(dependency);
      } catch (e) {
        if (kDebugMode) {
          print('【ComplexStateAdapter】处理依赖失败: ${dependency.id}, 错误: $e');
        }

        if (dependency.isRequired) {
          // 必需依赖失败，抛出异常
          throw StateError('必需依赖处理失败: ${dependency.id}');
        }
      }
    }
  }

  /// 添加状态变化监听器
  void addStateChangeListener(StateChangeListener listener) {
    _listeners.add(listener);
  }

  /// 移除状态变化监听器
  void removeStateChangeListener(StateChangeListener listener) {
    _listeners.remove(listener);
  }

  /// 获取当前状态快照
  Map<String, dynamic> getCurrentStateSnapshot() {
    return Map<String, dynamic>.from(_stateSnapshot);
  }

  /// 获取待处理操作
  List<StateOperation> getPendingOperations() {
    return List<StateOperation>.from(_pendingOperations);
  }

  /// 是否处于迁移模式
  bool get isMigrationMode => _isMigrationMode;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 处理BLoC状态变化
  void _handleBlocStateChange(GoalState state) {
    if (kDebugMode) {
      print('【ComplexStateAdapter】BLoC状态变化: ${state.runtimeType}');
    }

    // 更新状态快照
    _updateStateSnapshot(state);

    // 通知监听器
    _notifyListeners(StateChangeType.blocStateChanged, {
      'newState': state,
      'timestamp': DateTime.now(),
    });
  }

  /// 创建状态快照
  Future<void> _createStateSnapshot() async {
    final currentState = _goalBloc.state;

    _stateSnapshot.clear();
    _stateSnapshot['blocState'] = currentState;
    _stateSnapshot['timestamp'] = DateTime.now();
    _stateSnapshot['isMigrationMode'] = _isMigrationMode;

    if (currentState is GoalsLoaded) {
      _stateSnapshot['goals'] = currentState.goals;
      _stateSnapshot['allGoals'] = currentState.allGoals;
      _stateSnapshot['currentGoal'] = currentState.currentGoal;
    }

    if (kDebugMode) {
      print('【ComplexStateAdapter】状态快照已创建');
    }
  }

  /// 更新状态快照
  void _updateStateSnapshot(GoalState state) {
    _stateSnapshot['blocState'] = state;
    _stateSnapshot['timestamp'] = DateTime.now();

    if (state is GoalsLoaded) {
      _stateSnapshot['goals'] = state.goals;
      _stateSnapshot['allGoals'] = state.allGoals;
      _stateSnapshot['currentGoal'] = state.currentGoal;
    }
  }

  /// 从快照恢复状态
  Future<void> _restoreStateFromSnapshot() async {
    if (kDebugMode) {
      print('【ComplexStateAdapter】从快照恢复状态');
    }

    // 这里可以实现状态恢复逻辑
    // 由于BLoC的单向数据流特性，通常通过重新加载数据来恢复状态
    _goalBloc.add(const LoadGoals());
  }

  /// 处理待处理操作
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    if (kDebugMode) {
      print('【ComplexStateAdapter】处理${_pendingOperations.length}个待处理操作');
    }

    final operations = List<StateOperation>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        await _executeStateOperation(operation);
      } catch (e) {
        if (kDebugMode) {
          print('【ComplexStateAdapter】执行操作失败: ${operation.id}, 错误: $e');
        }
      }
    }
  }

  /// 执行状态操作
  Future<void> _executeStateOperation(StateOperation operation) async {
    switch (operation.type) {
      case StateOperationType.loadGoals:
        _goalBloc.add(const LoadGoals());
        break;
      case StateOperationType.addGoal:
        if (operation.data['goal'] is Goal) {
          _goalBloc.add(AddGoal(operation.data['goal'] as Goal));
        }
        break;
      case StateOperationType.updateGoal:
        if (operation.data['goal'] is Goal) {
          _goalBloc.add(UpdateGoal(operation.data['goal'] as Goal));
        }
        break;
      case StateOperationType.deleteGoal:
        if (operation.data['goalId'] is int) {
          _goalBloc.add(DeleteGoal(operation.data['goalId'] as int));
        } else if (operation.data['goalId'] is String) {
          final goalId = int.tryParse(operation.data['goalId'] as String);
          if (goalId != null) {
            _goalBloc.add(DeleteGoal(goalId));
          }
        }
        break;
      case StateOperationType.selectGoal:
        if (operation.data['goal'] is Goal) {
          _goalBloc.add(SelectGoal(operation.data['goal'] as Goal));
        }
        break;
    }
  }

  /// 处理依赖
  Future<void> _processDependency(StateDependency dependency) async {
    if (kDebugMode) {
      print('【ComplexStateAdapter】处理依赖: ${dependency.id}');
    }

    // 这里可以实现具体的依赖处理逻辑
    await dependency.processor();
  }

  /// 通知监听器
  void _notifyListeners(StateChangeType type, Map<String, dynamic> data) {
    for (final listener in _listeners) {
      try {
        listener(type, data);
      } catch (e) {
        if (kDebugMode) {
          print('【ComplexStateAdapter】监听器通知失败: $e');
        }
      }
    }
  }

  /// 清理资源
  void dispose() {
    if (kDebugMode) {
      print('【ComplexStateAdapter】清理资源');
    }

    _blocSubscription?.cancel();
    _listeners.clear();
    _pendingOperations.clear();
    _stateSnapshot.clear();
    _isInitialized = false;
    _isMigrationMode = false;
  }
}
