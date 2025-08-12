import 'package:flutter/foundation.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/app/app_state.dart';
import '../models/goal.dart';
import '../repositories/repository_provider.dart';

/// 验证问题类型
enum ValidationIssueType {
  dataInconsistency, // 数据不一致
  stateInconsistency, // 状态不一致
  configurationError, // 配置错误
  dependencyError, // 依赖错误
  serviceError, // 服务错误
  runtimeError, // 运行时错误
  performanceWarning, // 性能警告
  validationError, // 验证错误
}

/// 验证问题严重程度
enum ValidationSeverity {
  low, // 低 - 信息提示
  medium, // 中 - 警告
  high, // 高 - 错误
  critical, // 严重 - 致命错误
}

/// 验证类型
enum ValidationType {
  goalStateConsistency, // 目标状态一致性
  appStateHealth, // 应用状态健康性
  repositoryHealth, // Repository健康性
  performanceMetrics, // 性能指标
}

/// 验证问题
class ValidationIssue {
  final ValidationIssueType type;
  final ValidationSeverity severity;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  ValidationIssue({
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

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'severity': severity.name,
      'message': message,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final DateTime timestamp;
  final ValidationType validationType;

  ValidationResult({
    required this.isValid,
    required this.issues,
    required this.timestamp,
    required this.validationType,
  });

  /// 获取指定严重程度的问题
  List<ValidationIssue> getIssuesBySeverity(ValidationSeverity severity) {
    return issues.where((issue) => issue.severity == severity).toList();
  }

  /// 获取严重程度不低于指定级别的问题
  List<ValidationIssue> getIssuesAtLeastSeverity(
      ValidationSeverity minSeverity) {
    return issues
        .where((issue) => issue.severity.index >= minSeverity.index)
        .toList();
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'validationType': validationType.name,
      'summary': {
        'totalIssues': issues.length,
        'criticalIssues':
            getIssuesBySeverity(ValidationSeverity.critical).length,
        'highIssues': getIssuesBySeverity(ValidationSeverity.high).length,
        'mediumIssues': getIssuesBySeverity(ValidationSeverity.medium).length,
        'lowIssues': getIssuesBySeverity(ValidationSeverity.low).length,
      },
    };
  }

  @override
  String toString() {
    final summary = toJson()['summary'] as Map<String, dynamic>;
    return '${validationType.name}: ${isValid ? "VALID" : "INVALID"} '
        '(${summary['totalIssues']} issues: '
        '${summary['criticalIssues']} critical, '
        '${summary['highIssues']} high, '
        '${summary['mediumIssues']} medium, '
        '${summary['lowIssues']} low)';
  }
}

/// 验证总结
class ValidationSummary {
  final List<ValidationResult> results;
  final DateTime timestamp;
  final bool overallValid;

  ValidationSummary({
    required this.results,
    required this.timestamp,
    required this.overallValid,
  });

  /// 获取所有问题
  List<ValidationIssue> get allIssues {
    return results.expand((result) => result.issues).toList();
  }

  /// 获取指定严重程度的问题
  List<ValidationIssue> getIssuesBySeverity(ValidationSeverity severity) {
    return allIssues.where((issue) => issue.severity == severity).toList();
  }

  /// 获取验证统计信息
  Map<String, int> get statistics {
    final allIssues = this.allIssues;
    return {
      'totalValidations': results.length,
      'validValidations': results.where((r) => r.isValid).length,
      'totalIssues': allIssues.length,
      'criticalIssues': getIssuesBySeverity(ValidationSeverity.critical).length,
      'highIssues': getIssuesBySeverity(ValidationSeverity.high).length,
      'mediumIssues': getIssuesBySeverity(ValidationSeverity.medium).length,
      'lowIssues': getIssuesBySeverity(ValidationSeverity.low).length,
    };
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((result) => result.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'overallValid': overallValid,
      'statistics': statistics,
    };
  }

  @override
  String toString() {
    final stats = statistics;
    return 'ValidationSummary: ${overallValid ? "VALID" : "INVALID"} '
        '(${stats['validValidations']}/${stats['totalValidations']} validations passed, '
        '${stats['totalIssues']} total issues)';
  }
}

/// 状态迁移验证工具
///
/// 用于验证BLoC状态与传统状态管理的一致性
/// 确保迁移过程中功能的正确性和数据的完整性
class MigrationValidator {
  /// 验证目标状态一致性
  ///
  /// 比较BLoC状态与传统状态管理中的目标数据
  static Future<ValidationResult> validateGoalStateConsistency({
    required GoalState blocState,
    required List<Goal> traditionalGoals,
    required Goal? traditionalCurrentGoal,
  }) async {
    final issues = <ValidationIssue>[];

    try {
      // 只有在GoalsLoaded状态下才进行验证
      if (blocState is! GoalsLoaded) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.stateInconsistency,
          severity: ValidationSeverity.medium,
          message: 'BLoC状态不是GoalsLoaded类型: ${blocState.runtimeType}',
          details: {'blocStateType': blocState.runtimeType.toString()},
        ));

        return ValidationResult(
          isValid: false,
          issues: issues,
          timestamp: DateTime.now(),
          validationType: ValidationType.goalStateConsistency,
        );
      }

      final goalsLoadedState = blocState;

      // 验证目标列表数量
      if (goalsLoadedState.goals.length != traditionalGoals.length) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.dataInconsistency,
          severity: ValidationSeverity.high,
          message:
              '目标数量不一致: BLoC=${goalsLoadedState.goals.length}, 传统=${traditionalGoals.length}',
          details: {
            'blocGoals': goalsLoadedState.goals.length,
            'traditionalGoals': traditionalGoals.length,
          },
        ));
      }

      // 验证目标内容一致性
      for (int i = 0;
          i < goalsLoadedState.goals.length && i < traditionalGoals.length;
          i++) {
        final blocGoal = goalsLoadedState.goals[i];
        final traditionalGoal = traditionalGoals[i];

        if (blocGoal.id != traditionalGoal.id) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.dataInconsistency,
            severity: ValidationSeverity.high,
            message:
                '目标ID不匹配: 位置$i, BLoC=${blocGoal.id}, 传统=${traditionalGoal.id}',
            details: {
              'position': i,
              'blocGoalId': blocGoal.id,
              'traditionalGoalId': traditionalGoal.id,
            },
          ));
        }

        if (blocGoal.title != traditionalGoal.title) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.dataInconsistency,
            severity: ValidationSeverity.medium,
            message: '目标标题不匹配: ID=${blocGoal.id}',
            details: {
              'goalId': blocGoal.id,
              'blocTitle': blocGoal.title,
              'traditionalTitle': traditionalGoal.title,
            },
          ));
        }
      }

      // 验证当前目标一致性
      if (goalsLoadedState.currentGoal?.id != traditionalCurrentGoal?.id) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.stateInconsistency,
          severity: ValidationSeverity.high,
          message:
              '当前目标不一致: BLoC=${goalsLoadedState.currentGoal?.id}, 传统=${traditionalCurrentGoal?.id}',
          details: {
            'blocCurrentGoalId': goalsLoadedState.currentGoal?.id,
            'traditionalCurrentGoalId': traditionalCurrentGoal?.id,
          },
        ));
      }

      if (kDebugMode) {
        print('【MigrationValidator】目标状态验证完成: ${issues.length}个问题');
      }
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.validationError,
        severity: ValidationSeverity.critical,
        message: '验证过程中发生错误: $e',
        details: {'error': e.toString()},
      ));
    }

    return ValidationResult(
      isValid: issues
          .where((i) => i.severity.index >= ValidationSeverity.high.index)
          .isEmpty,
      issues: issues,
      timestamp: DateTime.now(),
      validationType: ValidationType.goalStateConsistency,
    );
  }

  /// 验证应用状态健康性
  ///
  /// 检查AppBloc状态的健康性和完整性
  static Future<ValidationResult> validateAppStateHealth({
    required AppState appState,
  }) async {
    final issues = <ValidationIssue>[];

    try {
      if (appState is AppReady) {
        // 验证版本信息
        if (appState.version.isEmpty) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.configurationError,
            severity: ValidationSeverity.medium,
            message: '应用版本信息为空',
            details: {},
          ));
        }

        // 验证网络状态
        if (appState.networkState == NetworkState.unknown) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.stateInconsistency,
            severity: ValidationSeverity.low,
            message: '网络状态未知',
            details: {'networkState': appState.networkState.toString()},
          ));
        }

        // 验证全局错误状态
        if (appState.hasGlobalError) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.runtimeError,
            severity: ValidationSeverity.high,
            message: '存在全局错误: ${appState.globalError}',
            details: {
              'globalError': appState.globalError,
              'globalErrorCode': appState.globalErrorCode,
            },
          ));
        }

        // 验证同步时间
        if (appState.needsDataSync) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.performanceWarning,
            severity: ValidationSeverity.low,
            message: '数据需要同步',
            details: {
              'lastSyncTime': appState.lastSyncTime.toIso8601String(),
              'needsSync': appState.needsDataSync,
            },
          ));
        }
      } else if (appState is AppError) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.runtimeError,
          severity: ValidationSeverity.critical,
          message: '应用处于错误状态: ${appState.message}',
          details: {
            'errorMessage': appState.message,
            'errorCode': appState.code,
          },
        ));
      }

      if (kDebugMode) {
        print('【MigrationValidator】应用状态健康检查完成: ${issues.length}个问题');
      }
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.validationError,
        severity: ValidationSeverity.critical,
        message: '健康检查过程中发生错误: $e',
        details: {'error': e.toString()},
      ));
    }

    return ValidationResult(
      isValid: issues
          .where((i) => i.severity.index >= ValidationSeverity.high.index)
          .isEmpty,
      issues: issues,
      timestamp: DateTime.now(),
      validationType: ValidationType.appStateHealth,
    );
  }

  /// 验证Repository健康性
  ///
  /// 检查Repository提供者的健康状态
  static Future<ValidationResult> validateRepositoryHealth() async {
    final issues = <ValidationIssue>[];

    try {
      final repositoryProvider = AppRepositoryProvider.instance;

      // 检查初始化状态
      if (!repositoryProvider.isInitialized) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.configurationError,
          severity: ValidationSeverity.critical,
          message: 'Repository提供者未初始化',
          details: {},
        ));

        return ValidationResult(
          isValid: false,
          issues: issues,
          timestamp: DateTime.now(),
          validationType: ValidationType.repositoryHealth,
        );
      }

      // 检查依赖状态
      final dependencyStatus = repositoryProvider.getDependencyStatus();
      dependencyStatus.forEach((dependency, isHealthy) {
        if (!isHealthy) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.dependencyError,
            severity: ValidationSeverity.high,
            message: '依赖服务不健康: $dependency',
            details: {'dependency': dependency, 'isHealthy': isHealthy},
          ));
        }
      });

      // 检查Repository健康状态
      final healthStatus = repositoryProvider.getHealthStatus();
      final unhealthyRepositories = healthStatus.entries
          .where((entry) => entry.key.contains('Repository') && !entry.value)
          .map((entry) => entry.key)
          .toList();

      if (unhealthyRepositories.isNotEmpty) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.serviceError,
          severity: ValidationSeverity.medium,
          message: '部分Repository未创建: ${unhealthyRepositories.join(", ")}',
          details: {'unhealthyRepositories': unhealthyRepositories},
        ));
      }

      if (kDebugMode) {
        print('【MigrationValidator】Repository健康检查完成: ${issues.length}个问题');
      }
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.validationError,
        severity: ValidationSeverity.critical,
        message: 'Repository健康检查过程中发生错误: $e',
        details: {'error': e.toString()},
      ));
    }

    return ValidationResult(
      isValid: issues
          .where((i) => i.severity.index >= ValidationSeverity.high.index)
          .isEmpty,
      issues: issues,
      timestamp: DateTime.now(),
      validationType: ValidationType.repositoryHealth,
    );
  }

  /// 验证性能指标
  ///
  /// 检查应用的性能指标是否在可接受范围内
  static Future<ValidationResult> validatePerformanceMetrics({
    required Duration stateUpdateDuration,
    required int memoryUsageMB,
    required Duration uiResponseTime,
  }) async {
    final issues = <ValidationIssue>[];

    try {
      // 验证状态更新时间
      if (stateUpdateDuration.inMilliseconds > 100) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.performanceWarning,
          severity: stateUpdateDuration.inMilliseconds > 500
              ? ValidationSeverity.high
              : ValidationSeverity.medium,
          message: '状态更新时间过长: ${stateUpdateDuration.inMilliseconds}ms',
          details: {
            'stateUpdateDuration': stateUpdateDuration.inMilliseconds,
            'threshold': 100,
          },
        ));
      }

      // 验证内存使用
      if (memoryUsageMB > 200) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.performanceWarning,
          severity: memoryUsageMB > 500
              ? ValidationSeverity.high
              : ValidationSeverity.medium,
          message: '内存使用过高: ${memoryUsageMB}MB',
          details: {
            'memoryUsageMB': memoryUsageMB,
            'threshold': 200,
          },
        ));
      }

      // 验证UI响应时间
      if (uiResponseTime.inMilliseconds > 50) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.performanceWarning,
          severity: uiResponseTime.inMilliseconds > 200
              ? ValidationSeverity.high
              : ValidationSeverity.medium,
          message: 'UI响应时间过长: ${uiResponseTime.inMilliseconds}ms',
          details: {
            'uiResponseTime': uiResponseTime.inMilliseconds,
            'threshold': 50,
          },
        ));
      }

      if (kDebugMode) {
        print('【MigrationValidator】性能指标验证完成: ${issues.length}个问题');
      }
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.validationError,
        severity: ValidationSeverity.critical,
        message: '性能验证过程中发生错误: $e',
        details: {'error': e.toString()},
      ));
    }

    return ValidationResult(
      isValid: issues
          .where((i) => i.severity.index >= ValidationSeverity.high.index)
          .isEmpty,
      issues: issues,
      timestamp: DateTime.now(),
      validationType: ValidationType.performanceMetrics,
    );
  }

  /// 运行综合验证
  ///
  /// 执行所有验证检查并返回综合结果
  static Future<ValidationSummary> runComprehensiveValidation({
    GoalState? blocGoalState,
    List<Goal>? traditionalGoals,
    Goal? traditionalCurrentGoal,
    AppState? appState,
    Duration? stateUpdateDuration,
    int? memoryUsageMB,
    Duration? uiResponseTime,
  }) async {
    final results = <ValidationResult>[];

    try {
      // 目标状态一致性验证
      if (blocGoalState != null && traditionalGoals != null) {
        final goalResult = await validateGoalStateConsistency(
          blocState: blocGoalState,
          traditionalGoals: traditionalGoals,
          traditionalCurrentGoal: traditionalCurrentGoal,
        );
        results.add(goalResult);
      }

      // 应用状态健康性验证
      if (appState != null) {
        final appResult = await validateAppStateHealth(appState: appState);
        results.add(appResult);
      }

      // Repository健康性验证
      final repoResult = await validateRepositoryHealth();
      results.add(repoResult);

      // 性能指标验证
      if (stateUpdateDuration != null &&
          memoryUsageMB != null &&
          uiResponseTime != null) {
        final perfResult = await validatePerformanceMetrics(
          stateUpdateDuration: stateUpdateDuration,
          memoryUsageMB: memoryUsageMB,
          uiResponseTime: uiResponseTime,
        );
        results.add(perfResult);
      }

      if (kDebugMode) {
        print('【MigrationValidator】综合验证完成: ${results.length}个验证项');
      }
    } catch (e) {
      if (kDebugMode) {
        print('【MigrationValidator】综合验证失败: $e');
      }
    }

    return ValidationSummary(
      results: results,
      timestamp: DateTime.now(),
      overallValid: results.every((r) => r.isValid),
    );
  }
}
