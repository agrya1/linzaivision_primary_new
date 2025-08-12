/// 事务监控和诊断工具
/// 
/// 提供事务执行的实时监控、性能分析和问题诊断功能
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'transaction_manager.dart';

/// 事务性能指标
class TransactionMetrics {
  final String transactionId;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? executionTime;
  final TransactionStatus status;
  final int operationsCount;
  final int successfulOperations;
  final int failedOperations;
  final List<Duration> operationDurations;
  final Map<String, dynamic> metadata;
  
  TransactionMetrics({
    required this.transactionId,
    required this.description,
    required this.startTime,
    this.endTime,
    this.executionTime,
    required this.status,
    required this.operationsCount,
    required this.successfulOperations,
    required this.failedOperations,
    required this.operationDurations,
    this.metadata = const {},
  });
  
  /// 成功率
  double get successRate {
    if (operationsCount == 0) return 0.0;
    return successfulOperations / operationsCount;
  }
  
  /// 平均操作时长
  Duration get averageOperationDuration {
    if (operationDurations.isEmpty) return Duration.zero;
    final totalMs = operationDurations.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: (totalMs / operationDurations.length).round());
  }
  
  /// 最长操作时长
  Duration get maxOperationDuration {
    if (operationDurations.isEmpty) return Duration.zero;
    return operationDurations.reduce((a, b) => a > b ? a : b);
  }
  
  /// 最短操作时长
  Duration get minOperationDuration {
    if (operationDurations.isEmpty) return Duration.zero;
    return operationDurations.reduce((a, b) => a < b ? a : b);
  }
}

/// 系统性能统计
class SystemPerformanceStats {
  final int totalTransactions;
  final int completedTransactions;
  final int failedTransactions;
  final int rolledBackTransactions;
  final int cancelledTransactions;
  final int currentlyExecuting;
  final int currentlyQueued;
  final Duration averageExecutionTime;
  final Duration maxExecutionTime;
  final double systemSuccessRate;
  final Map<String, int> operationTypeStats;
  final Map<TransactionPriority, int> priorityStats;
  final DateTime lastUpdated;
  
  SystemPerformanceStats({
    required this.totalTransactions,
    required this.completedTransactions,
    required this.failedTransactions,
    required this.rolledBackTransactions,
    required this.cancelledTransactions,
    required this.currentlyExecuting,
    required this.currentlyQueued,
    required this.averageExecutionTime,
    required this.maxExecutionTime,
    required this.systemSuccessRate,
    required this.operationTypeStats,
    required this.priorityStats,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

/// 事务监控器
class TransactionMonitor {
  static final TransactionMonitor _instance = TransactionMonitor._internal();
  factory TransactionMonitor() => _instance;
  TransactionMonitor._internal() {
    _startMonitoring();
  }
  
  final TransactionManager _transactionManager = TransactionManager();
  final Map<String, TransactionMetrics> _metricsHistory = {};
  final Queue<TransactionEvent> _recentEvents = Queue<TransactionEvent>();
  final int _maxEventHistory = 1000;
  
  late StreamSubscription<TransactionEvent> _eventSubscription;
  
  /// 性能统计流
  final StreamController<SystemPerformanceStats> _statsController = 
      StreamController<SystemPerformanceStats>.broadcast();
  
  Stream<SystemPerformanceStats> get performanceStats => _statsController.stream;
  
  /// 事件流
  Stream<TransactionEvent> get events => _transactionManager.events;
  
  /// 开始监控
  void _startMonitoring() {
    _eventSubscription = _transactionManager.events.listen(_handleTransactionEvent);
    
    // 定期更新性能统计
    Timer.periodic(const Duration(seconds: 5), (_) => _updatePerformanceStats());
  }
  
  /// 处理事务事件
  void _handleTransactionEvent(TransactionEvent event) {
    // 添加到事件历史
    _recentEvents.add(event);
    if (_recentEvents.length > _maxEventHistory) {
      _recentEvents.removeFirst();
    }
    
    // 更新指标
    _updateTransactionMetrics(event);
    
    // 检查性能问题
    _checkPerformanceIssues(event);
  }
  
  /// 更新事务指标
  void _updateTransactionMetrics(TransactionEvent event) {
    final transaction = event.transaction;
    final transactionId = transaction.id;
    
    switch (event.type) {
      case 'started':
        _metricsHistory[transactionId] = TransactionMetrics(
          transactionId: transactionId,
          description: transaction.description,
          startTime: transaction.startTime!,
          status: transaction.status,
          operationsCount: transaction.operations.length,
          successfulOperations: 0,
          failedOperations: 0,
          operationDurations: [],
          metadata: transaction.context.metadata,
        );
        break;
        
      case 'operation_completed':
        final metrics = _metricsHistory[transactionId];
        if (metrics != null) {
          final operationResult = transaction.results.last;
          final updatedDurations = List<Duration>.from(metrics.operationDurations)
            ..add(operationResult.executionTime);
          
          _metricsHistory[transactionId] = TransactionMetrics(
            transactionId: metrics.transactionId,
            description: metrics.description,
            startTime: metrics.startTime,
            endTime: metrics.endTime,
            executionTime: metrics.executionTime,
            status: transaction.status,
            operationsCount: metrics.operationsCount,
            successfulOperations: metrics.successfulOperations + (operationResult.success ? 1 : 0),
            failedOperations: metrics.failedOperations + (operationResult.success ? 0 : 1),
            operationDurations: updatedDurations,
            metadata: metrics.metadata,
          );
        }
        break;
        
      case 'completed':
      case 'failed':
      case 'rolled_back':
      case 'cancelled':
        final metrics = _metricsHistory[transactionId];
        if (metrics != null) {
          _metricsHistory[transactionId] = TransactionMetrics(
            transactionId: metrics.transactionId,
            description: metrics.description,
            startTime: metrics.startTime,
            endTime: transaction.endTime,
            executionTime: transaction.duration,
            status: transaction.status,
            operationsCount: metrics.operationsCount,
            successfulOperations: metrics.successfulOperations,
            failedOperations: metrics.failedOperations,
            operationDurations: metrics.operationDurations,
            metadata: metrics.metadata,
          );
        }
        break;
    }
  }
  
  /// 检查性能问题
  void _checkPerformanceIssues(TransactionEvent event) {
    final transaction = event.transaction;
    
    // 检查执行时间过长
    if (event.type == 'completed' && transaction.duration != null) {
      if (transaction.duration!.inSeconds > 60) {
        _reportPerformanceIssue(
          'Long execution time',
          'Transaction ${transaction.id} took ${transaction.duration!.inSeconds} seconds',
          PerformanceIssueSeverity.warning,
        );
      }
    }
    
    // 检查失败率
    if (event.type == 'failed') {
      final recentFailures = _recentEvents
          .where((e) => e.type == 'failed' && 
                      e.timestamp.isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
          .length;
      
      if (recentFailures > 5) {
        _reportPerformanceIssue(
          'High failure rate',
          '$recentFailures transactions failed in the last 5 minutes',
          PerformanceIssueSeverity.error,
        );
      }
    }
    
    // 检查队列积压
    final queuedCount = _transactionManager.getQueuedTransactions().length;
    if (queuedCount > 10) {
      _reportPerformanceIssue(
        'Queue backlog',
        '$queuedCount transactions are queued',
        PerformanceIssueSeverity.warning,
      );
    }
  }
  
  /// 更新性能统计
  void _updatePerformanceStats() {
    final allTransactions = _transactionManager.getAllTransactions();
    final executingTransactions = _transactionManager.getExecutingTransactions();
    final queuedTransactions = _transactionManager.getQueuedTransactions();
    
    final completed = allTransactions.where((t) => t.status == TransactionStatus.completed).length;
    final failed = allTransactions.where((t) => t.status == TransactionStatus.failed).length;
    final rolledBack = allTransactions.where((t) => t.status == TransactionStatus.rolledBack).length;
    final cancelled = allTransactions.where((t) => t.status == TransactionStatus.cancelled).length;
    
    // 计算平均执行时间
    final completedTransactions = allTransactions.where((t) => 
        t.status == TransactionStatus.completed && t.duration != null);
    final avgExecutionTime = completedTransactions.isEmpty 
        ? Duration.zero
        : Duration(milliseconds: 
            (completedTransactions.fold(0, (sum, t) => sum + t.duration!.inMilliseconds) / 
             completedTransactions.length).round());
    
    // 计算最大执行时间
    final maxExecutionTime = completedTransactions.isEmpty
        ? Duration.zero
        : completedTransactions.map((t) => t.duration!).reduce((a, b) => a > b ? a : b);
    
    // 计算成功率
    final totalFinished = completed + failed + rolledBack + cancelled;
    final successRate = totalFinished == 0 ? 0.0 : completed / totalFinished;
    
    // 统计操作类型
    final operationTypeStats = <String, int>{};
    for (final transaction in allTransactions) {
      for (final operation in transaction.operations) {
        final type = operation.runtimeType.toString();
        operationTypeStats[type] = (operationTypeStats[type] ?? 0) + 1;
      }
    }
    
    // 统计优先级
    final priorityStats = <TransactionPriority, int>{};
    for (final transaction in allTransactions) {
      final priority = transaction.context.priority;
      priorityStats[priority] = (priorityStats[priority] ?? 0) + 1;
    }
    
    final stats = SystemPerformanceStats(
      totalTransactions: allTransactions.length,
      completedTransactions: completed,
      failedTransactions: failed,
      rolledBackTransactions: rolledBack,
      cancelledTransactions: cancelled,
      currentlyExecuting: executingTransactions.length,
      currentlyQueued: queuedTransactions.length,
      averageExecutionTime: avgExecutionTime,
      maxExecutionTime: maxExecutionTime,
      systemSuccessRate: successRate,
      operationTypeStats: operationTypeStats,
      priorityStats: priorityStats,
    );
    
    _statsController.add(stats);
  }
  
  /// 报告性能问题
  void _reportPerformanceIssue(String title, String description, PerformanceIssueSeverity severity) {
    debugPrint('[$severity] $title: $description');
    
    // 这里可以添加更多的问题报告逻辑，比如发送到监控系统
  }
  
  /// 获取事务指标
  TransactionMetrics? getTransactionMetrics(String transactionId) {
    return _metricsHistory[transactionId];
  }
  
  /// 获取所有事务指标
  List<TransactionMetrics> getAllTransactionMetrics() {
    return List.unmodifiable(_metricsHistory.values);
  }
  
  /// 获取最近的事件
  List<TransactionEvent> getRecentEvents({int? limit}) {
    final events = _recentEvents.toList();
    if (limit != null && events.length > limit) {
      return events.sublist(events.length - limit);
    }
    return events;
  }
  
  /// 获取性能报告
  PerformanceReport generatePerformanceReport({Duration? period}) {
    final cutoff = period != null 
        ? DateTime.now().subtract(period)
        : DateTime.now().subtract(const Duration(hours: 24));
    
    final relevantMetrics = _metricsHistory.values
        .where((m) => m.startTime.isAfter(cutoff))
        .toList();
    
    if (relevantMetrics.isEmpty) {
      return PerformanceReport.empty();
    }
    
    // 计算统计数据
    final totalTransactions = relevantMetrics.length;
    final completedTransactions = relevantMetrics.where((m) => 
        m.status == TransactionStatus.completed).length;
    final failedTransactions = relevantMetrics.where((m) => 
        m.status == TransactionStatus.failed).length;
    
    final executionTimes = relevantMetrics
        .where((m) => m.executionTime != null)
        .map((m) => m.executionTime!)
        .toList();
    
    final avgExecutionTime = executionTimes.isEmpty
        ? Duration.zero
        : Duration(milliseconds: 
            (executionTimes.fold(0, (sum, d) => sum + d.inMilliseconds) / 
             executionTimes.length).round());
    
    final maxExecutionTime = executionTimes.isEmpty
        ? Duration.zero
        : executionTimes.reduce((a, b) => a > b ? a : b);
    
    final minExecutionTime = executionTimes.isEmpty
        ? Duration.zero
        : executionTimes.reduce((a, b) => a < b ? a : b);
    
    // 计算成功率趋势
    final successRates = <DateTime, double>{};
    final hourlyGroups = <int, List<TransactionMetrics>>{};
    
    for (final metric in relevantMetrics) {
      final hour = metric.startTime.hour;
      hourlyGroups.putIfAbsent(hour, () => []).add(metric);
    }
    
    for (final entry in hourlyGroups.entries) {
      final hour = entry.key;
      final metrics = entry.value;
      final completed = metrics.where((m) => m.status == TransactionStatus.completed).length;
      final total = metrics.length;
      final rate = total == 0 ? 0.0 : completed / total;
      
      final hourTime = DateTime.now().copyWith(hour: hour, minute: 0, second: 0, millisecond: 0);
      successRates[hourTime] = rate;
    }
    
    return PerformanceReport(
      period: period ?? const Duration(hours: 24),
      totalTransactions: totalTransactions,
      completedTransactions: completedTransactions,
      failedTransactions: failedTransactions,
      averageExecutionTime: avgExecutionTime,
      maxExecutionTime: maxExecutionTime,
      minExecutionTime: minExecutionTime,
      successRates: successRates,
      generatedAt: DateTime.now(),
    );
  }
  
  /// 清理历史数据
  void cleanupHistory({Duration? olderThan}) {
    final cutoff = olderThan != null 
        ? DateTime.now().subtract(olderThan)
        : DateTime.now().subtract(const Duration(days: 7));
    
    _metricsHistory.removeWhere((_, metrics) => metrics.startTime.isBefore(cutoff));
    
    // 清理事件历史
    while (_recentEvents.isNotEmpty && _recentEvents.first.timestamp.isBefore(cutoff)) {
      _recentEvents.removeFirst();
    }
  }
  
  /// 关闭监控器
  void dispose() {
    _eventSubscription.cancel();
    _statsController.close();
  }
}

/// 性能问题严重程度
enum PerformanceIssueSeverity {
  info,
  warning,
  error,
  critical,
}

/// 性能报告
class PerformanceReport {
  final Duration period;
  final int totalTransactions;
  final int completedTransactions;
  final int failedTransactions;
  final Duration averageExecutionTime;
  final Duration maxExecutionTime;
  final Duration minExecutionTime;
  final Map<DateTime, double> successRates;
  final DateTime generatedAt;
  
  PerformanceReport({
    required this.period,
    required this.totalTransactions,
    required this.completedTransactions,
    required this.failedTransactions,
    required this.averageExecutionTime,
    required this.maxExecutionTime,
    required this.minExecutionTime,
    required this.successRates,
    required this.generatedAt,
  });
  
  factory PerformanceReport.empty() {
    return PerformanceReport(
      period: Duration.zero,
      totalTransactions: 0,
      completedTransactions: 0,
      failedTransactions: 0,
      averageExecutionTime: Duration.zero,
      maxExecutionTime: Duration.zero,
      minExecutionTime: Duration.zero,
      successRates: {},
      generatedAt: DateTime.now(),
    );
  }
  
  /// 成功率
  double get successRate {
    if (totalTransactions == 0) return 0.0;
    return completedTransactions / totalTransactions;
  }
  
  /// 失败率
  double get failureRate {
    if (totalTransactions == 0) return 0.0;
    return failedTransactions / totalTransactions;
  }
}
