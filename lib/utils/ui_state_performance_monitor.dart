import 'dart:math' as math;

/// UI状态性能监控器
/// 
/// 用于监控UI状态切换的性能指标，支持批次1的灰度实施
class UIStatePerformanceMonitor {
  // 响应时间记录
  static final Map<String, List<int>> _responseTimes = {};
  
  // 事件计数
  static final Map<String, int> _eventCounts = {};
  
  // 错误计数
  static final Map<String, int> _errorCounts = {};
  
  // 当前测量的计时器
  static final Map<String, Stopwatch> _activeTimers = {};
  
  /// 记录事件发生
  static void recordEvent(String eventType) {
    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;
    print('【性能监控】事件记录: $eventType, 总计: ${_eventCounts[eventType]}');
  }
  
  /// 记录错误
  static void recordError(String eventType) {
    _errorCounts[eventType] = (_errorCounts[eventType] ?? 0) + 1;
    print('【性能监控】错误记录: $eventType, 总计: ${_errorCounts[eventType]}');
  }
  
  /// 开始测量响应时间
  static void startMeasure(String eventType) {
    _activeTimers[eventType] = Stopwatch()..start();
  }
  
  /// 结束测量响应时间
  static void endMeasure(String eventType) {
    final timer = _activeTimers[eventType];
    if (timer != null) {
      timer.stop();
      final responseTime = timer.elapsedMilliseconds;
      
      // 记录响应时间
      _responseTimes[eventType] ??= [];
      _responseTimes[eventType]!.add(responseTime);
      
      // 清理计时器
      _activeTimers.remove(eventType);
      
      print('【性能监控】响应时间: $eventType = ${responseTime}ms');
      
      // 性能告警
      if (responseTime > 100) {
        print('【性能告警】$eventType 响应时间过长: ${responseTime}ms');
      }
    }
  }
  
  /// 记录响应时间（直接记录）
  static void recordResponseTime(String eventType, int milliseconds) {
    _responseTimes[eventType] ??= [];
    _responseTimes[eventType]!.add(milliseconds);
    
    print('【性能监控】响应时间记录: $eventType = ${milliseconds}ms');
  }
  
  /// 获取性能统计
  static Map<String, dynamic> getStats(String eventType) {
    final responseTimes = _responseTimes[eventType] ?? [];
    final eventCount = _eventCounts[eventType] ?? 0;
    final errorCount = _errorCounts[eventType] ?? 0;
    
    if (responseTimes.isEmpty) {
      return {
        'eventType': eventType,
        'totalEvents': eventCount,
        'totalErrors': errorCount,
        'errorRate': eventCount > 0 ? errorCount / eventCount : 0.0,
        'avgResponseTime': 0,
        'maxResponseTime': 0,
        'minResponseTime': 0,
        'totalSamples': 0,
      };
    }
    
    final avgResponseTime = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final maxResponseTime = responseTimes.reduce(math.max);
    final minResponseTime = responseTimes.reduce(math.min);
    
    return {
      'eventType': eventType,
      'totalEvents': eventCount,
      'totalErrors': errorCount,
      'errorRate': eventCount > 0 ? errorCount / eventCount : 0.0,
      'avgResponseTime': avgResponseTime,
      'maxResponseTime': maxResponseTime,
      'minResponseTime': minResponseTime,
      'totalSamples': responseTimes.length,
    };
  }
  
  /// 获取所有事件类型的统计
  static Map<String, Map<String, dynamic>> getAllStats() {
    final allEventTypes = <String>{
      ..._responseTimes.keys,
      ..._eventCounts.keys,
      ..._errorCounts.keys,
    };
    
    final result = <String, Map<String, dynamic>>{};
    for (final eventType in allEventTypes) {
      result[eventType] = getStats(eventType);
    }
    
    return result;
  }
  
  /// 生成日报
  static Map<String, dynamic> getDailyReport() {
    final allStats = getAllStats();
    
    // 计算总体指标
    int totalEvents = 0;
    int totalErrors = 0;
    double totalAvgResponseTime = 0;
    int totalSamples = 0;
    
    for (final stats in allStats.values) {
      totalEvents += stats['totalEvents'] as int;
      totalErrors += stats['totalErrors'] as int;
      totalSamples += stats['totalSamples'] as int;
      if (stats['totalSamples'] > 0) {
        totalAvgResponseTime += (stats['avgResponseTime'] as double) * (stats['totalSamples'] as int);
      }
    }
    
    final overallAvgResponseTime = totalSamples > 0 ? totalAvgResponseTime / totalSamples : 0.0;
    final overallErrorRate = totalEvents > 0 ? totalErrors / totalEvents : 0.0;
    
    return {
      'date': DateTime.now().toIso8601String().split('T')[0],
      'summary': {
        'totalEvents': totalEvents,
        'totalErrors': totalErrors,
        'overallErrorRate': overallErrorRate,
        'overallAvgResponseTime': overallAvgResponseTime,
        'totalSamples': totalSamples,
      },
      'byEventType': allStats,
    };
  }
  
  /// 清理统计数据
  static void clearStats() {
    _responseTimes.clear();
    _eventCounts.clear();
    _errorCounts.clear();
    _activeTimers.clear();
    print('【性能监控】统计数据已清理');
  }
  
  /// 检查性能是否达标
  static bool isPerformanceAcceptable(String eventType) {
    final stats = getStats(eventType);
    
    // 性能标准
    final avgResponseTime = stats['avgResponseTime'] as double;
    final maxResponseTime = stats['maxResponseTime'] as int;
    final errorRate = stats['errorRate'] as double;
    
    // 判断标准
    final avgOk = avgResponseTime <= 50.0;  // 平均响应时间 <= 50ms
    final maxOk = maxResponseTime <= 100;   // 最大响应时间 <= 100ms
    final errorOk = errorRate <= 0.01;      // 错误率 <= 1%
    
    final acceptable = avgOk && maxOk && errorOk;
    
    if (!acceptable) {
      print('【性能告警】$eventType 性能不达标:');
      print('  平均响应时间: ${avgResponseTime.toStringAsFixed(1)}ms (标准: ≤50ms)');
      print('  最大响应时间: ${maxResponseTime}ms (标准: ≤100ms)');
      print('  错误率: ${(errorRate * 100).toStringAsFixed(2)}% (标准: ≤1%)');
    }
    
    return acceptable;
  }
}
