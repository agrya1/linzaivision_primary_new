import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/goal/goal_event.dart';
import '../models/goal.dart';

/// 迁移问题类型
enum MigrationIssueType {
  dataValidation, // 数据验证
  dataConsistency, // 数据一致性
  dataMigration, // 数据迁移
  blocState, // BLoC状态
  syncValidation, // 同步验证
  validationError, // 验证错误
  migrationError, // 迁移错误
}

/// 迁移问题严重程度
enum MigrationIssueSeverity {
  low, // 低
  medium, // 中
  high, // 高
  critical, // 严重
}

/// 迁移问题
class MigrationIssue {
  final MigrationIssueType type;
  final MigrationIssueSeverity severity;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  MigrationIssue({
    required this.type,
    required this.severity,
    required this.message,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return '${severity.name.toUpperCase()}: ${type.name} - $message';
  }
}

/// 迁移结果
class MigrationResult {
  final bool success;
  final Duration duration;
  final List<MigrationIssue> issues;
  final String message;
  final DateTime timestamp;

  MigrationResult({
    required this.success,
    required this.duration,
    required this.issues,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 获取指定严重程度的问题
  List<MigrationIssue> getIssuesBySeverity(MigrationIssueSeverity severity) {
    return issues.where((issue) => issue.severity == severity).toList();
  }

  @override
  String toString() {
    return 'MigrationResult: ${success ? "SUCCESS" : "FAILED"} '
        '(${duration.inMilliseconds}ms, ${issues.length} issues)';
  }
}

/// 预迁移验证结果
class PreMigrationValidation {
  final bool canProceed;
  final List<MigrationIssue> issues;

  PreMigrationValidation({
    required this.canProceed,
    required this.issues,
  });
}

/// 数据迁移结果
class DataMigrationResult {
  final bool success;
  final List<MigrationIssue> issues;

  DataMigrationResult({
    required this.success,
    required this.issues,
  });
}

/// 同步验证结果
class SyncValidationResult {
  final bool isValid;
  final List<MigrationIssue> issues;

  SyncValidationResult({
    required this.isValid,
    required this.issues,
  });
}

/// 状态迁移管理器
///
/// 负责管理从传统状态管理到BLoC模式的复杂迁移场景
class StateMigrationManager {
  final GoalBloc _goalBloc;

  // 迁移状态跟踪
  bool _isMigrationActive = false;
  bool _isValidationEnabled = true;

  // 状态同步缓存
  final Map<String, dynamic> _stateCache = {};
  DateTime _lastSyncTime = DateTime.now();

  StateMigrationManager({
    required GoalBloc goalBloc,
  }) : _goalBloc = goalBloc;

  /// 开始状态迁移
  Future<MigrationResult> startMigration({
    required List<Goal> traditionalGoals,
    required Goal? traditionalCurrentGoal,
    Map<String, dynamic>? additionalState,
  }) async {
    if (kDebugMode) {
      print('【StateMigrationManager】开始状态迁移');
    }

    _isMigrationActive = true;
    final migrationStartTime = DateTime.now();
    final issues = <MigrationIssue>[];

    try {
      // 1. 预迁移验证
      if (_isValidationEnabled) {
        final preValidation = await _performPreMigrationValidation(
          traditionalGoals,
          traditionalCurrentGoal,
        );
        issues.addAll(preValidation.issues);

        if (!preValidation.canProceed) {
          return MigrationResult(
            success: false,
            duration: DateTime.now().difference(migrationStartTime),
            issues: issues,
            message: '预迁移验证失败，无法继续迁移',
          );
        }
      }

      // 2. 状态数据迁移
      final dataResult = await _migrateStateData(
        traditionalGoals,
        traditionalCurrentGoal,
        additionalState,
      );
      issues.addAll(dataResult.issues);

      if (!dataResult.success) {
        return MigrationResult(
          success: false,
          duration: DateTime.now().difference(migrationStartTime),
          issues: issues,
          message: '状态数据迁移失败',
        );
      }

      // 3. 状态同步验证
      if (_isValidationEnabled) {
        final syncValidation = await _validateStateSynchronization(
          traditionalGoals,
          traditionalCurrentGoal,
        );
        issues.addAll(syncValidation.issues);
      }

      // 4. 后迁移清理
      await _performPostMigrationCleanup();

      final migrationDuration = DateTime.now().difference(migrationStartTime);

      if (kDebugMode) {
        print(
            '【StateMigrationManager】状态迁移完成，耗时: ${migrationDuration.inMilliseconds}ms');
      }

      return MigrationResult(
        success: true,
        duration: migrationDuration,
        issues: issues,
        message: '状态迁移成功完成',
      );
    } catch (e) {
      if (kDebugMode) {
        print('【StateMigrationManager】状态迁移失败: $e');
      }

      issues.add(MigrationIssue(
        type: MigrationIssueType.migrationError,
        severity: MigrationIssueSeverity.critical,
        message: '状态迁移过程中发生异常: $e',
        details: {'error': e.toString()},
      ));

      return MigrationResult(
        success: false,
        duration: DateTime.now().difference(migrationStartTime),
        issues: issues,
        message: '状态迁移异常终止',
      );
    } finally {
      _isMigrationActive = false;
    }
  }

  /// 执行预迁移验证
  Future<PreMigrationValidation> _performPreMigrationValidation(
    List<Goal> traditionalGoals,
    Goal? traditionalCurrentGoal,
  ) async {
    final issues = <MigrationIssue>[];

    try {
      // 验证传统状态数据完整性
      if (traditionalGoals.isEmpty) {
        issues.add(MigrationIssue(
          type: MigrationIssueType.dataValidation,
          severity: MigrationIssueSeverity.medium,
          message: '传统状态中没有目标数据',
          details: {},
        ));
      }

      // 验证当前目标的有效性
      if (traditionalCurrentGoal != null) {
        final currentGoalExists = traditionalGoals.any(
          (goal) => goal.id == traditionalCurrentGoal.id,
        );

        if (!currentGoalExists) {
          issues.add(MigrationIssue(
            type: MigrationIssueType.dataConsistency,
            severity: MigrationIssueSeverity.high,
            message: '当前目标不存在于目标列表中',
            details: {
              'currentGoalId': traditionalCurrentGoal.id,
              'availableGoalIds': traditionalGoals.map((g) => g.id).toList(),
            },
          ));
        }
      }

      // 验证BLoC状态
      final blocState = _goalBloc.state;
      if (blocState is GoalError) {
        issues.add(MigrationIssue(
          type: MigrationIssueType.blocState,
          severity: MigrationIssueSeverity.high,
          message: 'BLoC处于错误状态，无法进行迁移',
          details: {'blocError': blocState.message},
        ));
      }

      // 判断是否可以继续迁移
      final criticalIssues = issues
          .where(
            (issue) => issue.severity == MigrationIssueSeverity.critical,
          )
          .toList();

      return PreMigrationValidation(
        canProceed: criticalIssues.isEmpty,
        issues: issues,
      );
    } catch (e) {
      issues.add(MigrationIssue(
        type: MigrationIssueType.validationError,
        severity: MigrationIssueSeverity.critical,
        message: '预迁移验证过程中发生异常: $e',
        details: {'error': e.toString()},
      ));

      return PreMigrationValidation(
        canProceed: false,
        issues: issues,
      );
    }
  }

  /// 迁移状态数据
  Future<DataMigrationResult> _migrateStateData(
    List<Goal> traditionalGoals,
    Goal? traditionalCurrentGoal,
    Map<String, dynamic>? additionalState,
  ) async {
    final issues = <MigrationIssue>[];

    try {
      if (kDebugMode) {
        print('【StateMigrationManager】开始迁移状态数据');
      }

      // 缓存传统状态
      _stateCache['traditionalGoals'] = traditionalGoals;
      _stateCache['traditionalCurrentGoal'] = traditionalCurrentGoal;
      _stateCache['additionalState'] = additionalState;
      _stateCache['migrationTimestamp'] = DateTime.now();

      // 触发BLoC加载事件
      _goalBloc.add(const LoadGoals());

      // 等待BLoC状态更新
      await _waitForBlocStateUpdate();

      // 如果有当前目标，选择它
      if (traditionalCurrentGoal != null) {
        _goalBloc.add(SelectGoal(traditionalCurrentGoal));
        await _waitForBlocStateUpdate();
      }

      if (kDebugMode) {
        print('【StateMigrationManager】状态数据迁移完成');
      }

      return DataMigrationResult(
        success: true,
        issues: issues,
      );
    } catch (e) {
      issues.add(MigrationIssue(
        type: MigrationIssueType.dataMigration,
        severity: MigrationIssueSeverity.critical,
        message: '状态数据迁移失败: $e',
        details: {'error': e.toString()},
      ));

      return DataMigrationResult(
        success: false,
        issues: issues,
      );
    }
  }

  /// 等待BLoC状态更新
  Future<void> _waitForBlocStateUpdate() async {
    final completer = Completer<void>();
    late StreamSubscription subscription;

    subscription = _goalBloc.stream.listen((state) {
      if (state is GoalsLoaded || state is GoalError) {
        if (!completer.isCompleted) {
          completer.complete();
          subscription.cancel();
        }
      }
    });

    // 添加超时保护
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete();
      }
    });

    await completer.future;
  }

  /// 验证状态同步
  Future<SyncValidationResult> _validateStateSynchronization(
    List<Goal> traditionalGoals,
    Goal? traditionalCurrentGoal,
  ) async {
    final issues = <MigrationIssue>[];

    try {
      final blocState = _goalBloc.state;

      if (blocState is GoalsLoaded) {
        // 验证目标数量一致性
        if (blocState.goals.length != traditionalGoals.length) {
          issues.add(MigrationIssue(
            type: MigrationIssueType.syncValidation,
            severity: MigrationIssueSeverity.medium,
            message: '目标数量不一致',
            details: {
              'traditionalCount': traditionalGoals.length,
              'blocCount': blocState.goals.length,
            },
          ));
        }

        // 验证当前目标一致性
        if (traditionalCurrentGoal?.id != blocState.currentGoal?.id) {
          issues.add(MigrationIssue(
            type: MigrationIssueType.syncValidation,
            severity: MigrationIssueSeverity.medium,
            message: '当前目标不一致',
            details: {
              'traditionalCurrentGoalId': traditionalCurrentGoal?.id,
              'blocCurrentGoalId': blocState.currentGoal?.id,
            },
          ));
        }
      } else {
        issues.add(MigrationIssue(
          type: MigrationIssueType.syncValidation,
          severity: MigrationIssueSeverity.high,
          message: 'BLoC状态不是GoalsLoaded类型',
          details: {'blocStateType': blocState.runtimeType.toString()},
        ));
      }

      return SyncValidationResult(
        isValid: issues
            .where((i) => i.severity == MigrationIssueSeverity.critical)
            .isEmpty,
        issues: issues,
      );
    } catch (e) {
      issues.add(MigrationIssue(
        type: MigrationIssueType.validationError,
        severity: MigrationIssueSeverity.critical,
        message: '状态同步验证失败: $e',
        details: {'error': e.toString()},
      ));

      return SyncValidationResult(
        isValid: false,
        issues: issues,
      );
    }
  }

  /// 执行后迁移清理
  Future<void> _performPostMigrationCleanup() async {
    try {
      if (kDebugMode) {
        print('【StateMigrationManager】执行后迁移清理');
      }

      // 清理过期的状态缓存
      final now = DateTime.now();
      _stateCache.removeWhere((key, value) {
        if (key == 'migrationTimestamp' && value is DateTime) {
          return now.difference(value).inMinutes > 5; // 5分钟后清理
        }
        return false;
      });

      // 更新最后同步时间
      _lastSyncTime = now;

      if (kDebugMode) {
        print('【StateMigrationManager】最后同步时间更新: $_lastSyncTime');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【StateMigrationManager】后迁移清理失败: $e');
      }
    }
  }

  /// 获取迁移状态
  bool get isMigrationActive => _isMigrationActive;

  /// 获取状态缓存
  Map<String, dynamic> get stateCache => Map.unmodifiable(_stateCache);

  /// 启用/禁用验证
  void setValidationEnabled(bool enabled) {
    _isValidationEnabled = enabled;
  }
}
