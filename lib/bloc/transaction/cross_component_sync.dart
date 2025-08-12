/// 跨组件状态同步优化器
///
/// 优化复杂操作中的跨组件状态同步机制，减少不必要的重建和更新
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/goal.dart';

/// 同步事件类型
enum SyncEventType {
  goalAdded,
  goalUpdated,
  goalDeleted,
  goalStatusChanged,
  goalHierarchyChanged,
  bulkUpdate,
  stateReset,
}

/// 同步事件
class SyncEvent {
  final String id;
  final SyncEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String? sourceComponent;
  final Set<String> targetComponents;
  final int priority;

  SyncEvent({
    required this.id,
    required this.type,
    required this.data,
    this.sourceComponent,
    this.targetComponents = const {},
    this.priority = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建目标添加事件
  factory SyncEvent.goalAdded(Goal goal, {String? source}) {
    return SyncEvent(
      id: 'goal_added_${goal.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncEventType.goalAdded,
      data: {'goal': goal},
      sourceComponent: source,
      priority: 5,
    );
  }

  /// 创建目标更新事件
  factory SyncEvent.goalUpdated(Goal goal, {String? source}) {
    return SyncEvent(
      id: 'goal_updated_${goal.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncEventType.goalUpdated,
      data: {'goal': goal},
      sourceComponent: source,
      priority: 3,
    );
  }

  /// 创建目标删除事件
  factory SyncEvent.goalDeleted(int goalId, {String? source}) {
    return SyncEvent(
      id: 'goal_deleted_${goalId}_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncEventType.goalDeleted,
      data: {'goalId': goalId},
      sourceComponent: source,
      priority: 8,
    );
  }

  /// 创建批量更新事件
  factory SyncEvent.bulkUpdate(List<Goal> goals, {String? source}) {
    return SyncEvent(
      id: 'bulk_update_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncEventType.bulkUpdate,
      data: {'goals': goals},
      sourceComponent: source,
      priority: 10,
    );
  }
}

/// 组件同步配置
class ComponentSyncConfig {
  final String componentId;
  final Set<SyncEventType> subscribedEvents;
  final bool enableBatching;
  final Duration batchWindow;
  final int maxBatchSize;
  final bool enableDeduplication;
  final bool enablePriorityFiltering;
  final int minPriority;

  const ComponentSyncConfig({
    required this.componentId,
    this.subscribedEvents = const {},
    this.enableBatching = true,
    this.batchWindow = const Duration(milliseconds: 100),
    this.maxBatchSize = 50,
    this.enableDeduplication = true,
    this.enablePriorityFiltering = false,
    this.minPriority = 0,
  });
}

/// 同步统计
class SyncStats {
  final int totalEvents;
  final int processedEvents;
  final int droppedEvents;
  final int batchedEvents;
  final Duration averageProcessingTime;
  final Map<SyncEventType, int> eventTypeCount;
  final Map<String, int> componentEventCount;

  const SyncStats({
    required this.totalEvents,
    required this.processedEvents,
    required this.droppedEvents,
    required this.batchedEvents,
    required this.averageProcessingTime,
    required this.eventTypeCount,
    required this.componentEventCount,
  });

  double get processingRate =>
      totalEvents == 0 ? 0.0 : processedEvents / totalEvents;
  double get dropRate => totalEvents == 0 ? 0.0 : droppedEvents / totalEvents;
}

/// 跨组件状态同步管理器
class CrossComponentSyncManager {
  static final CrossComponentSyncManager _instance =
      CrossComponentSyncManager._internal();
  factory CrossComponentSyncManager() => _instance;
  CrossComponentSyncManager._internal();

  // 事件流
  final BehaviorSubject<SyncEvent> _eventSubject = BehaviorSubject<SyncEvent>();

  // 组件配置
  final Map<String, ComponentSyncConfig> _componentConfigs = {};

  // 组件订阅
  final Map<String, StreamSubscription<List<SyncEvent>>>
      _componentSubscriptions = {};

  // 事件队列
  final Queue<SyncEvent> _eventQueue = Queue<SyncEvent>();

  // 批处理定时器
  final Map<String, Timer> _batchTimers = {};

  // 批处理缓存
  final Map<String, List<SyncEvent>> _batchCache = {};

  // 统计信息
  int _totalEvents = 0;
  int _processedEvents = 0;
  int _droppedEvents = 0;
  int _batchedEvents = 0;
  final List<Duration> _processingTimes = [];
  final Map<SyncEventType, int> _eventTypeCount = {};
  final Map<String, int> _componentEventCount = {};

  /// 注册组件
  void registerComponent(ComponentSyncConfig config) {
    _componentConfigs[config.componentId] = config;

    // 创建组件专用的事件流
    final componentStream = _eventSubject.stream
        .where((event) => _shouldProcessEvent(event, config))
        .bufferTime(config.batchWindow)
        .where((events) => events.isNotEmpty)
        .map((events) => _processEventBatch(events, config));

    // 订阅组件事件流
    _componentSubscriptions[config.componentId] = componentStream.listen(
      (events) => _deliverEventsToComponent(config.componentId, events),
      onError: (error) =>
          debugPrint('Sync error for ${config.componentId}: $error'),
    );

    debugPrint('Registered component: ${config.componentId}');
  }

  /// 注销组件
  void unregisterComponent(String componentId) {
    _componentSubscriptions[componentId]?.cancel();
    _componentSubscriptions.remove(componentId);
    _componentConfigs.remove(componentId);
    _batchTimers[componentId]?.cancel();
    _batchTimers.remove(componentId);
    _batchCache.remove(componentId);

    debugPrint('Unregistered component: $componentId');
  }

  /// 发布同步事件
  void publishEvent(SyncEvent event) {
    _totalEvents++;
    _eventTypeCount[event.type] = (_eventTypeCount[event.type] ?? 0) + 1;

    if (event.sourceComponent != null) {
      _componentEventCount[event.sourceComponent!] =
          (_componentEventCount[event.sourceComponent!] ?? 0) + 1;
    }

    // 添加到事件流
    _eventSubject.add(event);

    debugPrint('Published event: ${event.type} from ${event.sourceComponent}');
  }

  /// 批量发布事件
  void publishEvents(List<SyncEvent> events) {
    for (final event in events) {
      publishEvent(event);
    }
  }

  /// 判断是否应该处理事件
  bool _shouldProcessEvent(SyncEvent event, ComponentSyncConfig config) {
    // 检查事件类型订阅
    if (config.subscribedEvents.isNotEmpty &&
        !config.subscribedEvents.contains(event.type)) {
      return false;
    }

    // 检查优先级过滤
    if (config.enablePriorityFiltering && event.priority < config.minPriority) {
      _droppedEvents++;
      return false;
    }

    // 检查目标组件
    if (event.targetComponents.isNotEmpty &&
        !event.targetComponents.contains(config.componentId)) {
      return false;
    }

    // 避免自循环
    if (event.sourceComponent == config.componentId) {
      return false;
    }

    return true;
  }

  /// 处理事件批次
  List<SyncEvent> _processEventBatch(
      List<SyncEvent> events, ComponentSyncConfig config) {
    final stopwatch = Stopwatch()..start();

    var processedEvents = events;

    // 去重处理
    if (config.enableDeduplication) {
      processedEvents = _deduplicateEvents(processedEvents);
    }

    // 批次大小限制
    if (processedEvents.length > config.maxBatchSize) {
      // 按优先级排序，保留高优先级事件
      processedEvents.sort((a, b) => b.priority.compareTo(a.priority));
      processedEvents = processedEvents.take(config.maxBatchSize).toList();
    }

    // 按优先级和时间戳排序
    processedEvents.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.timestamp.compareTo(b.timestamp);
    });

    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);
    _processedEvents += processedEvents.length;

    if (processedEvents.length > 1) {
      _batchedEvents += processedEvents.length;
    }

    return processedEvents;
  }

  /// 去重事件
  List<SyncEvent> _deduplicateEvents(List<SyncEvent> events) {
    final Map<String, SyncEvent> deduped = {};

    for (final event in events) {
      String dedupeKey;

      switch (event.type) {
        case SyncEventType.goalUpdated:
          final goal = event.data['goal'] as Goal?;
          dedupeKey = 'goal_update_${goal?.id}';
          break;
        case SyncEventType.goalStatusChanged:
          final goalId = event.data['goalId'];
          dedupeKey = 'status_change_$goalId';
          break;
        case SyncEventType.goalDeleted:
          final goalId = event.data['goalId'];
          dedupeKey = 'goal_delete_$goalId';
          break;
        default:
          dedupeKey = event.id;
      }

      // 保留最新的事件
      if (!deduped.containsKey(dedupeKey) ||
          event.timestamp.isAfter(deduped[dedupeKey]!.timestamp)) {
        deduped[dedupeKey] = event;
      }
    }

    return deduped.values.toList();
  }

  /// 将事件传递给组件
  void _deliverEventsToComponent(String componentId, List<SyncEvent> events) {
    if (events.isEmpty) return;

    // 这里可以添加具体的组件通知逻辑
    // 例如调用组件的更新方法或发送通知

    debugPrint('Delivered ${events.length} events to $componentId');

    // 触发组件更新回调
    _notifyComponentUpdate(componentId, events);
  }

  /// 通知组件更新
  void _notifyComponentUpdate(String componentId, List<SyncEvent> events) {
    // 这里可以实现具体的组件通知机制
    // 例如通过回调函数、事件总线等方式通知组件

    for (final event in events) {
      switch (event.type) {
        case SyncEventType.goalAdded:
          _handleGoalAdded(componentId, event);
          break;
        case SyncEventType.goalUpdated:
          _handleGoalUpdated(componentId, event);
          break;
        case SyncEventType.goalDeleted:
          _handleGoalDeleted(componentId, event);
          break;
        case SyncEventType.bulkUpdate:
          _handleBulkUpdate(componentId, event);
          break;
        default:
          _handleGenericEvent(componentId, event);
      }
    }
  }

  /// 处理目标添加事件
  void _handleGoalAdded(String componentId, SyncEvent event) {
    final goal = event.data['goal'] as Goal;
    debugPrint('Component $componentId: Goal added - ${goal.title}');
  }

  /// 处理目标更新事件
  void _handleGoalUpdated(String componentId, SyncEvent event) {
    final goal = event.data['goal'] as Goal;
    debugPrint('Component $componentId: Goal updated - ${goal.title}');
  }

  /// 处理目标删除事件
  void _handleGoalDeleted(String componentId, SyncEvent event) {
    final goalId = event.data['goalId'] as int;
    debugPrint('Component $componentId: Goal deleted - $goalId');
  }

  /// 处理批量更新事件
  void _handleBulkUpdate(String componentId, SyncEvent event) {
    final goals = event.data['goals'] as List<Goal>;
    debugPrint('Component $componentId: Bulk update - ${goals.length} goals');
  }

  /// 处理通用事件
  void _handleGenericEvent(String componentId, SyncEvent event) {
    debugPrint('Component $componentId: Generic event - ${event.type}');
  }

  /// 获取同步统计
  SyncStats getStats() {
    final avgProcessingTime = _processingTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                (_processingTimes.fold(0, (sum, d) => sum + d.inMilliseconds) /
                        _processingTimes.length)
                    .round());

    return SyncStats(
      totalEvents: _totalEvents,
      processedEvents: _processedEvents,
      droppedEvents: _droppedEvents,
      batchedEvents: _batchedEvents,
      averageProcessingTime: avgProcessingTime,
      eventTypeCount: Map.from(_eventTypeCount),
      componentEventCount: Map.from(_componentEventCount),
    );
  }

  /// 重置统计
  void resetStats() {
    _totalEvents = 0;
    _processedEvents = 0;
    _droppedEvents = 0;
    _batchedEvents = 0;
    _processingTimes.clear();
    _eventTypeCount.clear();
    _componentEventCount.clear();
  }

  /// 获取已注册的组件
  List<String> getRegisteredComponents() {
    return _componentConfigs.keys.toList();
  }

  /// 获取组件配置
  ComponentSyncConfig? getComponentConfig(String componentId) {
    return _componentConfigs[componentId];
  }

  /// 清理资源
  void dispose() {
    for (final subscription in _componentSubscriptions.values) {
      subscription.cancel();
    }
    _componentSubscriptions.clear();

    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();

    _eventSubject.close();
    _componentConfigs.clear();
    _batchCache.clear();
  }
}

/// 组件同步混入
mixin ComponentSyncMixin {
  late final String _componentId;
  late final CrossComponentSyncManager _syncManager;

  /// 初始化同步
  void initializeSync(String componentId, ComponentSyncConfig config) {
    _componentId = componentId;
    _syncManager = CrossComponentSyncManager();
    _syncManager.registerComponent(config);
  }

  /// 发布事件
  void publishSyncEvent(SyncEvent event) {
    _syncManager.publishEvent(event);
  }

  /// 批量发布事件
  void publishSyncEvents(List<SyncEvent> events) {
    _syncManager.publishEvents(events);
  }

  /// 清理同步
  void disposeSync() {
    _syncManager.unregisterComponent(_componentId);
  }
}

/// 跨组件同步集成示例
class CrossComponentSyncIntegration {
  static final CrossComponentSyncManager _syncManager =
      CrossComponentSyncManager();

  /// 初始化GoalPage组件同步
  static void initializeGoalPageSync() {
    final config = ComponentSyncConfig(
      componentId: 'goal_page',
      subscribedEvents: {
        SyncEventType.goalAdded,
        SyncEventType.goalUpdated,
        SyncEventType.goalDeleted,
        SyncEventType.bulkUpdate,
      },
      enableBatching: true,
      batchWindow: const Duration(milliseconds: 50),
      maxBatchSize: 20,
      enableDeduplication: true,
    );

    _syncManager.registerComponent(config);
  }

  /// 初始化ExplorePage组件同步
  static void initializeExplorePageSync() {
    final config = ComponentSyncConfig(
      componentId: 'explore_page',
      subscribedEvents: {
        SyncEventType.goalAdded,
        SyncEventType.goalUpdated,
        SyncEventType.goalDeleted,
      },
      enableBatching: true,
      batchWindow: const Duration(milliseconds: 100),
      maxBatchSize: 10,
      enableDeduplication: true,
      enablePriorityFiltering: true,
      minPriority: 3,
    );

    _syncManager.registerComponent(config);
  }

  /// 初始化导航抽屉同步
  static void initializeDrawerSync() {
    final config = ComponentSyncConfig(
      componentId: 'navigation_drawer',
      subscribedEvents: {
        SyncEventType.goalAdded,
        SyncEventType.goalDeleted,
        SyncEventType.goalHierarchyChanged,
      },
      enableBatching: false, // 导航抽屉需要立即更新
      enableDeduplication: true,
    );

    _syncManager.registerComponent(config);
  }

  /// 发布目标添加事件
  static void publishGoalAdded(Goal goal, String sourceComponent) {
    final event = SyncEvent.goalAdded(goal, source: sourceComponent);
    _syncManager.publishEvent(event);
  }

  /// 发布目标更新事件
  static void publishGoalUpdated(Goal goal, String sourceComponent) {
    final event = SyncEvent.goalUpdated(goal, source: sourceComponent);
    _syncManager.publishEvent(event);
  }

  /// 发布目标删除事件
  static void publishGoalDeleted(int goalId, String sourceComponent) {
    final event = SyncEvent.goalDeleted(goalId, source: sourceComponent);
    _syncManager.publishEvent(event);
  }

  /// 发布批量更新事件
  static void publishBulkUpdate(List<Goal> goals, String sourceComponent) {
    final event = SyncEvent.bulkUpdate(goals, source: sourceComponent);
    _syncManager.publishEvent(event);
  }

  /// 获取同步统计
  static SyncStats getSyncStats() {
    return _syncManager.getStats();
  }

  /// 重置统计
  static void resetStats() {
    _syncManager.resetStats();
  }

  /// 清理所有同步
  static void dispose() {
    _syncManager.dispose();
  }
}
