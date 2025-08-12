/// 事件合并机制
///
/// 将多个连续的小操作合并为一个批处理，减少不必要的中间状态和处理开销
library;

import 'dart:async';
import 'dart:collection';
import '../goal/goal_event.dart';
import '../../models/goal.dart';

/// 事件合并策略
enum EventMergeStrategy {
  timeWindow, // 时间窗口合并
  countBased, // 数量基础合并
  typeGrouping, // 类型分组合并
  adaptive, // 自适应合并
  immediate, // 立即处理（不合并）
}

/// 合并配置
class EventMergeConfig {
  final EventMergeStrategy strategy;
  final Duration timeWindow;
  final int maxBatchSize;
  final int minBatchSize;
  final Duration maxDelay;
  final bool enablePriorityMerging;
  final Map<Type, int> eventPriorities;

  const EventMergeConfig({
    this.strategy = EventMergeStrategy.adaptive,
    this.timeWindow = const Duration(milliseconds: 100),
    this.maxBatchSize = 50,
    this.minBatchSize = 2,
    this.maxDelay = const Duration(milliseconds: 500),
    this.enablePriorityMerging = true,
    this.eventPriorities = const {},
  });

  /// 高性能配置
  factory EventMergeConfig.highPerformance() {
    return const EventMergeConfig(
      strategy: EventMergeStrategy.timeWindow,
      timeWindow: Duration(milliseconds: 50),
      maxBatchSize: 100,
      minBatchSize: 5,
      maxDelay: Duration(milliseconds: 200),
      enablePriorityMerging: true,
    );
  }

  /// 低延迟配置
  factory EventMergeConfig.lowLatency() {
    return const EventMergeConfig(
      strategy: EventMergeStrategy.countBased,
      timeWindow: Duration(milliseconds: 20),
      maxBatchSize: 10,
      minBatchSize: 1,
      maxDelay: Duration(milliseconds: 50),
      enablePriorityMerging: false,
    );
  }
}

/// 可合并事件接口
abstract class MergeableEvent {
  /// 事件ID
  String get eventId;

  /// 事件类型
  String get eventType;

  /// 事件优先级
  int get priority => 0;

  /// 是否可以与其他事件合并
  bool canMergeWith(MergeableEvent other);

  /// 合并事件
  MergeableEvent mergeWith(List<MergeableEvent> others);

  /// 获取影响的资源
  Set<String> getAffectedResources();
}

/// 批量目标更新事件
class BatchGoalUpdateEvent extends GoalEvent implements MergeableEvent {
  final List<Goal> goals;
  final String batchId;

  const BatchGoalUpdateEvent(this.goals, {required this.batchId});

  @override
  String get eventId => batchId;

  @override
  String get eventType => 'batch_goal_update';

  @override
  int get priority => 5;

  @override
  bool canMergeWith(MergeableEvent other) {
    return other is BatchGoalUpdateEvent ||
        other.eventType == 'goal_update' ||
        other.eventType == 'goal_add';
  }

  @override
  MergeableEvent mergeWith(List<MergeableEvent> others) {
    final goalMap = <int, Goal>{};

    // 添加当前事件的目标
    for (final goal in goals) {
      goalMap[goal.id!] = goal;
    }

    // 合并其他事件的目标
    for (final event in others) {
      if (event is BatchGoalUpdateEvent) {
        for (final goal in event.goals) {
          goalMap[goal.id!] = goal; // 后来的覆盖前面的
        }
      }
      // 注意：这里不能直接访问UpdateGoal和AddGoal，因为others是MergeableEvent类型
      // 实际使用时需要在调用mergeWith之前确保类型正确
    }

    return BatchGoalUpdateEvent(
      goalMap.values.toList(),
      batchId: 'merged_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Set<String> getAffectedResources() {
    return goals.map((g) => 'goal_${g.id}').toSet();
  }

  @override
  List<Object?> get props => [goals, batchId];
}

/// 批量目标删除事件
class BatchGoalDeleteEvent extends GoalEvent implements MergeableEvent {
  final List<int> goalIds;
  final String batchId;

  const BatchGoalDeleteEvent(this.goalIds, {required this.batchId});

  @override
  String get eventId => batchId;

  @override
  String get eventType => 'batch_goal_delete';

  @override
  int get priority => 8;

  @override
  bool canMergeWith(MergeableEvent other) {
    return other is BatchGoalDeleteEvent || other.eventType == 'goal_delete';
  }

  @override
  MergeableEvent mergeWith(List<MergeableEvent> others) {
    final allIds = <int>{...goalIds};

    for (final event in others) {
      if (event is BatchGoalDeleteEvent) {
        allIds.addAll(event.goalIds);
      }
      // 注意：这里不能直接访问DeleteGoal，因为others是MergeableEvent类型
      // 实际使用时需要在调用mergeWith之前确保类型正确
    }

    return BatchGoalDeleteEvent(
      allIds.toList(),
      batchId: 'merged_delete_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Set<String> getAffectedResources() {
    return goalIds.map((id) => 'goal_$id').toSet();
  }

  @override
  List<Object?> get props => [goalIds, batchId];
}

/// 事件合并器
class EventMerger {
  final EventMergeConfig config;

  // 待合并事件队列
  final Queue<MergeableEvent> _pendingEvents = Queue<MergeableEvent>();

  // 合并定时器
  Timer? _mergeTimer;

  // 事件处理回调
  final Function(List<MergeableEvent>) _eventProcessor;

  // 统计信息
  int _totalEvents = 0;
  int _mergedEvents = 0;
  int _batchesCreated = 0;
  final List<Duration> _processingTimes = [];

  EventMerger({
    required Function(List<MergeableEvent>) eventProcessor,
    this.config = const EventMergeConfig(),
  }) : _eventProcessor = eventProcessor;

  /// 添加事件到合并队列
  void addEvent(MergeableEvent event) {
    _totalEvents++;

    switch (config.strategy) {
      case EventMergeStrategy.immediate:
        _processImmediately([event]);
        break;

      case EventMergeStrategy.timeWindow:
        _addToTimeWindow(event);
        break;

      case EventMergeStrategy.countBased:
        _addToCountBased(event);
        break;

      case EventMergeStrategy.typeGrouping:
        _addToTypeGrouping(event);
        break;

      case EventMergeStrategy.adaptive:
        _addToAdaptive(event);
        break;
    }
  }

  /// 立即处理事件
  void _processImmediately(List<MergeableEvent> events) {
    final stopwatch = Stopwatch()..start();
    _eventProcessor(events);
    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);
  }

  /// 时间窗口合并
  void _addToTimeWindow(MergeableEvent event) {
    _pendingEvents.add(event);

    // 如果达到最大批次大小，立即处理
    if (_pendingEvents.length >= config.maxBatchSize) {
      _processPendingEvents();
      return;
    }

    // 设置或重置定时器
    _mergeTimer?.cancel();
    _mergeTimer = Timer(config.timeWindow, () {
      if (_pendingEvents.isNotEmpty) {
        _processPendingEvents();
      }
    });
  }

  /// 数量基础合并
  void _addToCountBased(MergeableEvent event) {
    _pendingEvents.add(event);

    if (_pendingEvents.length >= config.maxBatchSize) {
      _processPendingEvents();
    }
  }

  /// 类型分组合并
  void _addToTypeGrouping(MergeableEvent event) {
    _pendingEvents.add(event);

    // 按类型分组处理
    final typeGroups = <String, List<MergeableEvent>>{};

    for (final pendingEvent in _pendingEvents) {
      final type = pendingEvent.eventType;
      typeGroups.putIfAbsent(type, () => []).add(pendingEvent);
    }

    // 处理完整的类型组
    final toProcess = <MergeableEvent>[];
    final remaining = <MergeableEvent>[];

    for (final entry in typeGroups.entries) {
      if (entry.value.length >= config.minBatchSize) {
        toProcess.addAll(entry.value);
      } else {
        remaining.addAll(entry.value);
      }
    }

    if (toProcess.isNotEmpty) {
      _pendingEvents.clear();
      _pendingEvents.addAll(remaining);
      _processEvents(toProcess);
    }
  }

  /// 自适应合并
  void _addToAdaptive(MergeableEvent event) {
    _pendingEvents.add(event);

    // 根据系统负载和事件类型动态调整策略
    final systemLoad = _estimateSystemLoad();
    final eventPriority = _getEventPriority(event);

    if (eventPriority >= 8 || systemLoad > 0.8) {
      // 高优先级事件或高负载时立即处理
      final highPriorityEvents =
          _pendingEvents.where((e) => _getEventPriority(e) >= 8).toList();

      if (highPriorityEvents.isNotEmpty) {
        _pendingEvents.removeWhere((e) => highPriorityEvents.contains(e));
        _processEvents(highPriorityEvents);
      }
    } else if (_pendingEvents.length >= config.maxBatchSize ||
        systemLoad < 0.3) {
      // 批次满或低负载时处理
      _processPendingEvents();
    } else {
      // 设置延迟处理
      _mergeTimer?.cancel();
      _mergeTimer = Timer(config.timeWindow, () {
        if (_pendingEvents.isNotEmpty) {
          _processPendingEvents();
        }
      });
    }
  }

  /// 处理待合并事件
  void _processPendingEvents() {
    if (_pendingEvents.isEmpty) return;

    final events = _pendingEvents.toList();
    _pendingEvents.clear();
    _mergeTimer?.cancel();

    _processEvents(events);
  }

  /// 处理事件列表
  void _processEvents(List<MergeableEvent> events) {
    if (events.isEmpty) return;

    final stopwatch = Stopwatch()..start();

    // 按优先级排序
    if (config.enablePriorityMerging) {
      events.sort((a, b) => b.priority.compareTo(a.priority));
    }

    // 合并相似事件
    final mergedEvents = _mergeEvents(events);

    // 处理合并后的事件
    _eventProcessor(mergedEvents);

    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);
    _batchesCreated++;
    _mergedEvents += events.length - mergedEvents.length;
  }

  /// 合并事件
  List<MergeableEvent> _mergeEvents(List<MergeableEvent> events) {
    final merged = <MergeableEvent>[];
    final processed = <bool>[...List.filled(events.length, false)];

    for (int i = 0; i < events.length; i++) {
      if (processed[i]) continue;

      final currentEvent = events[i];
      final mergeable = <MergeableEvent>[];

      // 查找可合并的事件
      for (int j = i + 1; j < events.length; j++) {
        if (processed[j]) continue;

        final otherEvent = events[j];
        if (currentEvent.canMergeWith(otherEvent) &&
            !_hasResourceConflict(currentEvent, otherEvent)) {
          mergeable.add(otherEvent);
          processed[j] = true;
        }
      }

      // 合并事件
      if (mergeable.isNotEmpty) {
        final mergedEvent = currentEvent.mergeWith(mergeable);
        merged.add(mergedEvent);
      } else {
        merged.add(currentEvent);
      }

      processed[i] = true;
    }

    return merged;
  }

  /// 检查资源冲突
  bool _hasResourceConflict(MergeableEvent event1, MergeableEvent event2) {
    final resources1 = event1.getAffectedResources();
    final resources2 = event2.getAffectedResources();
    return resources1.intersection(resources2).isNotEmpty;
  }

  /// 估算系统负载
  double _estimateSystemLoad() {
    // 简化的系统负载估算
    final queueSize = _pendingEvents.length;
    final avgProcessingTime = _processingTimes.isEmpty
        ? 0.0
        : _processingTimes.fold(0.0, (sum, d) => sum + d.inMilliseconds) /
            _processingTimes.length;

    // 基于队列大小和处理时间估算负载
    final queueLoad = (queueSize / config.maxBatchSize).clamp(0.0, 1.0);
    final timeLoad = (avgProcessingTime / 100.0).clamp(0.0, 1.0);

    return (queueLoad + timeLoad) / 2.0;
  }

  /// 获取事件优先级
  int _getEventPriority(MergeableEvent event) {
    return config.eventPriorities[event.runtimeType] ?? event.priority;
  }

  /// 强制处理所有待合并事件
  void flush() {
    _mergeTimer?.cancel();
    if (_pendingEvents.isNotEmpty) {
      _processPendingEvents();
    }
  }

  /// 获取合并统计
  EventMergeStats getStats() {
    final avgProcessingTime = _processingTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                (_processingTimes.fold(0, (sum, d) => sum + d.inMilliseconds) /
                        _processingTimes.length)
                    .round());

    final mergeRate = _totalEvents == 0 ? 0.0 : _mergedEvents / _totalEvents;

    return EventMergeStats(
      totalEvents: _totalEvents,
      mergedEvents: _mergedEvents,
      batchesCreated: _batchesCreated,
      mergeRate: mergeRate,
      averageProcessingTime: avgProcessingTime,
      pendingEvents: _pendingEvents.length,
    );
  }

  /// 重置统计
  void resetStats() {
    _totalEvents = 0;
    _mergedEvents = 0;
    _batchesCreated = 0;
    _processingTimes.clear();
  }

  /// 释放资源
  void dispose() {
    _mergeTimer?.cancel();
    flush(); // 处理剩余事件
  }
}

/// 事件合并统计
class EventMergeStats {
  final int totalEvents;
  final int mergedEvents;
  final int batchesCreated;
  final double mergeRate;
  final Duration averageProcessingTime;
  final int pendingEvents;

  const EventMergeStats({
    required this.totalEvents,
    required this.mergedEvents,
    required this.batchesCreated,
    required this.mergeRate,
    required this.averageProcessingTime,
    required this.pendingEvents,
  });

  /// 获取效率等级
  String get efficiencyLevel {
    if (mergeRate > 0.7) return 'Excellent';
    if (mergeRate > 0.5) return 'Good';
    if (mergeRate > 0.3) return 'Fair';
    return 'Poor';
  }
}

/// 扩展现有的GoalEvent使其支持合并
extension MergeableGoalEvent on GoalEvent {
  /// 转换为可合并事件
  MergeableEvent? toMergeableEvent() {
    if (this is UpdateGoal) {
      final updateEvent = this as UpdateGoal;
      return BatchGoalUpdateEvent(
        [updateEvent.goal],
        batchId: 'single_update_${updateEvent.goal.id}',
      );
    } else if (this is AddGoal) {
      final addEvent = this as AddGoal;
      return BatchGoalUpdateEvent(
        [addEvent.goal],
        batchId: 'single_add_${addEvent.goal.id}',
      );
    } else if (this is DeleteGoal) {
      final deleteEvent = this as DeleteGoal;
      return BatchGoalDeleteEvent(
        [deleteEvent.goalId],
        batchId: 'single_delete_${deleteEvent.goalId}',
      );
    }
    return null;
  }
}
