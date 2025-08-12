import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 性能指标类型
enum PerformanceMetric {
  executionTime, // 执行时间
  memoryUsage, // 内存使用
  cpuUsage, // CPU使用
  networkLatency, // 网络延迟
  cacheHitRate, // 缓存命中率
  errorRate, // 错误率
  throughput, // 吞吐量
}

/// 性能数据点
class PerformanceDataPoint {
  final DateTime timestamp;
  final String taskId;
  final PerformanceMetric metric;
  final double value;
  final Map<String, dynamic> metadata;

  const PerformanceDataPoint({
    required this.timestamp,
    required this.taskId,
    required this.metric,
    required this.value,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'taskId': taskId,
      'metric': metric.toString(),
      'value': value,
      'metadata': metadata,
    };
  }
}

/// 性能阈值配置
class PerformanceThresholds {
  final Duration maxExecutionTime;
  final double maxMemoryUsage; // MB
  final double maxCpuUsage; // 百分比
  final Duration maxNetworkLatency;
  final double minCacheHitRate; // 百分比
  final double maxErrorRate; // 百分比

  const PerformanceThresholds({
    this.maxExecutionTime = const Duration(seconds: 30),
    this.maxMemoryUsage = 100.0,
    this.maxCpuUsage = 80.0,
    this.maxNetworkLatency = const Duration(seconds: 5),
    this.minCacheHitRate = 70.0,
    this.maxErrorRate = 5.0,
  });
}

/// 性能警告
class PerformanceWarning {
  final DateTime timestamp;
  final String taskId;
  final PerformanceMetric metric;
  final double actualValue;
  final double thresholdValue;
  final String message;
  final String severity; // low, medium, high, critical

  const PerformanceWarning({
    required this.timestamp,
    required this.taskId,
    required this.metric,
    required this.actualValue,
    required this.thresholdValue,
    required this.message,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'taskId': taskId,
      'metric': metric.toString(),
      'actualValue': actualValue,
      'thresholdValue': thresholdValue,
      'message': message,
      'severity': severity,
    };
  }
}

/// 加载性能监控器
/// 监控数据加载的性能指标，提供优化建议
class LoadingPerformanceMonitor {
  final PerformanceThresholds _thresholds;
  final Queue<PerformanceDataPoint> _dataPoints = Queue<PerformanceDataPoint>();
  final List<PerformanceWarning> _warnings = [];
  final Map<String, DateTime> _taskStartTimes = {};
  final Map<String, List<double>> _metricHistory = {};

  // 统计数据
  final Map<String, int> _taskExecutionCounts = {};
  final Map<String, Duration> _totalExecutionTimes = {};
  final Map<String, int> _taskErrorCounts = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheRequests = {};

  // 配置参数
  static const int _maxDataPoints = 1000;
  static const int _maxWarnings = 100;
  static const Duration _dataRetentionPeriod = Duration(hours: 24);

  Timer? _cleanupTimer;

  LoadingPerformanceMonitor({
    PerformanceThresholds? thresholds,
  }) : _thresholds = thresholds ?? const PerformanceThresholds() {
    _startCleanupTimer();
  }

  /// 开始监控任务
  void startTaskMonitoring(String taskId) {
    _taskStartTimes[taskId] = DateTime.now();
    _taskExecutionCounts[taskId] = (_taskExecutionCounts[taskId] ?? 0) + 1;

    if (kDebugMode) {
      print('【LoadingPerformanceMonitor】开始监控任务: $taskId');
    }
  }

  /// 结束任务监控
  void endTaskMonitoring(String taskId, {bool success = true}) {
    final startTime = _taskStartTimes.remove(taskId);
    if (startTime == null) return;

    final executionTime = DateTime.now().difference(startTime);

    // 记录执行时间
    recordMetric(
      taskId: taskId,
      metric: PerformanceMetric.executionTime,
      value: executionTime.inMilliseconds.toDouble(),
    );

    // 更新统计数据
    _totalExecutionTimes[taskId] =
        (_totalExecutionTimes[taskId] ?? Duration.zero) + executionTime;

    if (!success) {
      _taskErrorCounts[taskId] = (_taskErrorCounts[taskId] ?? 0) + 1;
    }

    // 检查性能阈值
    _checkExecutionTimeThreshold(taskId, executionTime);

    if (kDebugMode) {
      print(
          '【LoadingPerformanceMonitor】任务完成: $taskId, 耗时: ${executionTime.inMilliseconds}ms');
    }
  }

  /// 记录性能指标
  void recordMetric({
    required String taskId,
    required PerformanceMetric metric,
    required double value,
    Map<String, dynamic> metadata = const {},
  }) {
    final dataPoint = PerformanceDataPoint(
      timestamp: DateTime.now(),
      taskId: taskId,
      metric: metric,
      value: value,
      metadata: metadata,
    );

    _dataPoints.add(dataPoint);

    // 维护数据点数量限制
    while (_dataPoints.length > _maxDataPoints) {
      _dataPoints.removeFirst();
    }

    // 更新指标历史
    final historyKey = '${taskId}_${metric.toString()}';
    _metricHistory.putIfAbsent(historyKey, () => []).add(value);

    // 限制历史数据长度
    final history = _metricHistory[historyKey]!;
    if (history.length > 100) {
      history.removeAt(0);
    }

    // 检查阈值
    _checkMetricThreshold(taskId, metric, value);
  }

  /// 记录缓存命中
  void recordCacheHit(String taskId, bool hit) {
    _cacheRequests[taskId] = (_cacheRequests[taskId] ?? 0) + 1;
    if (hit) {
      _cacheHits[taskId] = (_cacheHits[taskId] ?? 0) + 1;
    }

    // 计算缓存命中率
    final hitRate =
        (_cacheHits[taskId] ?? 0) / (_cacheRequests[taskId] ?? 1) * 100;

    recordMetric(
      taskId: taskId,
      metric: PerformanceMetric.cacheHitRate,
      value: hitRate,
    );
  }

  /// 检查执行时间阈值
  void _checkExecutionTimeThreshold(String taskId, Duration executionTime) {
    if (executionTime > _thresholds.maxExecutionTime) {
      final warning = PerformanceWarning(
        timestamp: DateTime.now(),
        taskId: taskId,
        metric: PerformanceMetric.executionTime,
        actualValue: executionTime.inMilliseconds.toDouble(),
        thresholdValue: _thresholds.maxExecutionTime.inMilliseconds.toDouble(),
        message:
            '任务执行时间超过阈值: ${executionTime.inSeconds}s > ${_thresholds.maxExecutionTime.inSeconds}s',
        severity: executionTime > _thresholds.maxExecutionTime * 2
            ? 'critical'
            : 'high',
      );

      _addWarning(warning);
    }
  }

  /// 检查指标阈值
  void _checkMetricThreshold(
      String taskId, PerformanceMetric metric, double value) {
    String? message;
    String severity = 'medium';
    double? thresholdValue;

    switch (metric) {
      case PerformanceMetric.memoryUsage:
        if (value > _thresholds.maxMemoryUsage) {
          thresholdValue = _thresholds.maxMemoryUsage;
          message =
              '内存使用超过阈值: ${value.toStringAsFixed(1)}MB > ${_thresholds.maxMemoryUsage}MB';
          severity =
              value > _thresholds.maxMemoryUsage * 1.5 ? 'critical' : 'high';
        }
        break;

      case PerformanceMetric.cpuUsage:
        if (value > _thresholds.maxCpuUsage) {
          thresholdValue = _thresholds.maxCpuUsage;
          message =
              'CPU使用率超过阈值: ${value.toStringAsFixed(1)}% > ${_thresholds.maxCpuUsage}%';
          severity =
              value > _thresholds.maxCpuUsage * 1.2 ? 'critical' : 'high';
        }
        break;

      case PerformanceMetric.cacheHitRate:
        if (value < _thresholds.minCacheHitRate) {
          thresholdValue = _thresholds.minCacheHitRate;
          message =
              '缓存命中率低于阈值: ${value.toStringAsFixed(1)}% < ${_thresholds.minCacheHitRate}%';
          severity =
              value < _thresholds.minCacheHitRate * 0.5 ? 'high' : 'medium';
        }
        break;

      case PerformanceMetric.errorRate:
        if (value > _thresholds.maxErrorRate) {
          thresholdValue = _thresholds.maxErrorRate;
          message =
              '错误率超过阈值: ${value.toStringAsFixed(1)}% > ${_thresholds.maxErrorRate}%';
          severity = value > _thresholds.maxErrorRate * 2 ? 'critical' : 'high';
        }
        break;

      default:
        return;
    }

    if (message != null && thresholdValue != null) {
      final warning = PerformanceWarning(
        timestamp: DateTime.now(),
        taskId: taskId,
        metric: metric,
        actualValue: value,
        thresholdValue: thresholdValue,
        message: message,
        severity: severity,
      );

      _addWarning(warning);
    }
  }

  /// 添加警告
  void _addWarning(PerformanceWarning warning) {
    _warnings.add(warning);

    // 维护警告数量限制
    while (_warnings.length > _maxWarnings) {
      _warnings.removeAt(0);
    }

    if (kDebugMode) {
      print(
          '【LoadingPerformanceMonitor】性能警告 [${warning.severity}]: ${warning.message}');
    }
  }

  /// 获取任务性能统计
  Map<String, dynamic> getTaskStats(String taskId) {
    final executionCount = _taskExecutionCounts[taskId] ?? 0;
    final totalTime = _totalExecutionTimes[taskId] ?? Duration.zero;
    final errorCount = _taskErrorCounts[taskId] ?? 0;
    final cacheHits = _cacheHits[taskId] ?? 0;
    final cacheRequests = _cacheRequests[taskId] ?? 0;

    return {
      'taskId': taskId,
      'executionCount': executionCount,
      'totalExecutionTime': totalTime.inMilliseconds,
      'averageExecutionTime':
          executionCount > 0 ? totalTime.inMilliseconds / executionCount : 0,
      'errorCount': errorCount,
      'errorRate': executionCount > 0 ? (errorCount / executionCount * 100) : 0,
      'cacheHitRate': cacheRequests > 0 ? (cacheHits / cacheRequests * 100) : 0,
      'successRate': executionCount > 0
          ? ((executionCount - errorCount) / executionCount * 100)
          : 0,
    };
  }

  /// 获取整体性能统计
  Map<String, dynamic> getOverallStats() {
    final totalTasks = _taskExecutionCounts.length;
    final totalExecutions =
        _taskExecutionCounts.values.fold(0, (sum, count) => sum + count);
    final totalErrors =
        _taskErrorCounts.values.fold(0, (sum, count) => sum + count);
    final totalCacheHits =
        _cacheHits.values.fold(0, (sum, count) => sum + count);
    final totalCacheRequests =
        _cacheRequests.values.fold(0, (sum, count) => sum + count);

    final totalExecutionTime = _totalExecutionTimes.values.fold(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    return {
      'totalTasks': totalTasks,
      'totalExecutions': totalExecutions,
      'totalExecutionTime': totalExecutionTime.inMilliseconds,
      'averageExecutionTime': totalExecutions > 0
          ? totalExecutionTime.inMilliseconds / totalExecutions
          : 0.0,
      'overallErrorRate':
          totalExecutions > 0 ? (totalErrors / totalExecutions * 100) : 0.0,
      'overallCacheHitRate': totalCacheRequests > 0
          ? (totalCacheHits / totalCacheRequests * 100)
          : 0.0,
      'overallSuccessRate': totalExecutions > 0
          ? ((totalExecutions - totalErrors) / totalExecutions * 100)
          : 0.0,
      'activeWarnings': _warnings.length,
      'criticalWarnings':
          _warnings.where((w) => w.severity == 'critical').length,
    };
  }

  /// 获取性能趋势
  Map<String, List<double>> getPerformanceTrends(String taskId) {
    final trends = <String, List<double>>{};

    for (final metric in PerformanceMetric.values) {
      final historyKey = '${taskId}_${metric.toString()}';
      final history = _metricHistory[historyKey];
      if (history != null && history.isNotEmpty) {
        trends[metric.toString()] = List.from(history);
      }
    }

    return trends;
  }

  /// 获取性能建议
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];
    final stats = getOverallStats();

    // 错误率建议
    final errorRate = stats['overallErrorRate'] as double;
    if (errorRate > 10) {
      recommendations
          .add('错误率过高(${errorRate.toStringAsFixed(1)}%)，建议检查任务实现和网络连接');
    }

    // 缓存命中率建议
    final cacheHitRate = stats['overallCacheHitRate'] as double;
    if (cacheHitRate < 50) {
      recommendations
          .add('缓存命中率较低(${cacheHitRate.toStringAsFixed(1)}%)，建议优化缓存策略');
    }

    // 执行时间建议
    final avgExecutionTime = stats['averageExecutionTime'] as double;
    if (avgExecutionTime > 5000) {
      recommendations.add(
          '平均执行时间较长(${(avgExecutionTime / 1000).toStringAsFixed(1)}s)，建议优化任务逻辑或增加并行度');
    }

    // 关键警告建议
    final criticalWarnings = stats['criticalWarnings'] as int;
    if (criticalWarnings > 0) {
      recommendations.add('存在$criticalWarnings个关键性能警告，需要立即处理');
    }

    return recommendations;
  }

  /// 获取最近的警告
  List<PerformanceWarning> getRecentWarnings({int limit = 10}) {
    final sortedWarnings = List<PerformanceWarning>.from(_warnings);
    sortedWarnings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedWarnings.take(limit).toList();
  }

  /// 清理过期数据
  void _cleanupExpiredData() {
    final cutoffTime = DateTime.now().subtract(_dataRetentionPeriod);

    // 清理过期数据点
    _dataPoints.removeWhere((point) => point.timestamp.isBefore(cutoffTime));

    // 清理过期警告
    _warnings.removeWhere((warning) => warning.timestamp.isBefore(cutoffTime));

    if (kDebugMode) {
      print('【LoadingPerformanceMonitor】清理过期数据完成');
    }
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredData();
    });
  }

  /// 导出性能报告
  Map<String, dynamic> exportPerformanceReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'overallStats': getOverallStats(),
      'taskStats': _taskExecutionCounts.keys
          .map((taskId) => getTaskStats(taskId))
          .toList(),
      'recentWarnings': getRecentWarnings().map((w) => w.toJson()).toList(),
      'recommendations': getPerformanceRecommendations(),
      'dataPoints': _dataPoints.map((p) => p.toJson()).toList(),
    };
  }

  /// 重置所有统计数据
  void reset() {
    _dataPoints.clear();
    _warnings.clear();
    _taskStartTimes.clear();
    _metricHistory.clear();
    _taskExecutionCounts.clear();
    _totalExecutionTimes.clear();
    _taskErrorCounts.clear();
    _cacheHits.clear();
    _cacheRequests.clear();

    if (kDebugMode) {
      print('【LoadingPerformanceMonitor】统计数据已重置');
    }
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    reset();
  }
}
