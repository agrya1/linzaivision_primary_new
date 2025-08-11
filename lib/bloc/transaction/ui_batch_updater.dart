/// UI批量更新优化器
///
/// 优化UI层的批量更新操作，减少不必要的重建，提升用户界面响应性能
library;

import 'dart:async';
import 'i_ui_batch_updater.dart';
import 'dart:collection';
import 'package:flutter/scheduler.dart';
import '../../models/goal.dart';

/// UI更新类型
enum UIUpdateType {
  goalListUpdate, // 目标列表更新
  goalItemUpdate, // 单个目标更新
  statusBarUpdate, // 状态栏更新
  navigationUpdate, // 导航更新
  statisticsUpdate, // 统计信息更新
  themeUpdate, // 主题更新
}

/// UI更新优先级
enum UIUpdatePriority {
  immediate, // 立即更新（用户交互）
  high, // 高优先级（重要状态变化）
  normal, // 普通优先级（常规更新）
  low, // 低优先级（统计信息等）
  background, // 后台更新（缓存等）
}

/// UI更新配置
class UIBatchUpdateConfig {
  final Duration batchWindow;
  final int maxBatchSize;
  final bool enableFrameSync;
  final bool enablePriorityQueuing;
  final Duration maxDelay;
  final Map<UIUpdateType, UIUpdatePriority> typePriorities;

  const UIBatchUpdateConfig({
    this.batchWindow = const Duration(milliseconds: 16), // 60 FPS
    this.maxBatchSize = 20,
    this.enableFrameSync = true,
    this.enablePriorityQueuing = true,
    this.maxDelay = const Duration(milliseconds: 100),
    this.typePriorities = const {
      UIUpdateType.goalItemUpdate: UIUpdatePriority.immediate,
      UIUpdateType.goalListUpdate: UIUpdatePriority.high,
      UIUpdateType.statusBarUpdate: UIUpdatePriority.normal,
      UIUpdateType.navigationUpdate: UIUpdatePriority.normal,
      UIUpdateType.statisticsUpdate: UIUpdatePriority.low,
      UIUpdateType.themeUpdate: UIUpdatePriority.background,
    },
  });

  /// 高性能配置
  factory UIBatchUpdateConfig.highPerformance() {
    return const UIBatchUpdateConfig(
      batchWindow: Duration(milliseconds: 8), // 120 FPS
      maxBatchSize: 50,
      enableFrameSync: true,
      enablePriorityQueuing: true,
      maxDelay: Duration(milliseconds: 50),
    );
  }

  /// 低功耗配置
  factory UIBatchUpdateConfig.lowPower() {
    return const UIBatchUpdateConfig(
      batchWindow: Duration(milliseconds: 33), // 30 FPS
      maxBatchSize: 10,
      enableFrameSync: false,
      enablePriorityQueuing: false,
      maxDelay: Duration(milliseconds: 200),
    );
  }
}

/// UI更新项
class UIUpdateItem {
  final String id;
  final UIUpdateType type;
  final UIUpdatePriority priority;
  final Map<String, dynamic> data;
  final VoidCallback? updateCallback;
  final DateTime timestamp;
  final Set<String> affectedWidgets;

  UIUpdateItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.data,
    this.updateCallback,
    DateTime? timestamp,
    this.affectedWidgets = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建目标列表更新项
  factory UIUpdateItem.goalListUpdate(
      List<Goal> goals, VoidCallback? callback) {
    return UIUpdateItem(
      id: 'goal_list_${DateTime.now().millisecondsSinceEpoch}',
      type: UIUpdateType.goalListUpdate,
      priority: UIUpdatePriority.high,
      data: {'goals': goals},
      updateCallback: callback,
      affectedWidgets: {'goal_list', 'goal_count'},
    );
  }

  /// 创建目标项更新项
  factory UIUpdateItem.goalItemUpdate(Goal goal, VoidCallback? callback) {
    return UIUpdateItem(
      id: 'goal_item_${goal.id}',
      type: UIUpdateType.goalItemUpdate,
      priority: UIUpdatePriority.immediate,
      data: {'goal': goal},
      updateCallback: callback,
      affectedWidgets: {'goal_item_${goal.id}'},
    );
  }

  /// 创建统计更新项
  factory UIUpdateItem.statisticsUpdate(
      Map<String, dynamic> stats, VoidCallback? callback) {
    return UIUpdateItem(
      id: 'statistics_${DateTime.now().millisecondsSinceEpoch}',
      type: UIUpdateType.statisticsUpdate,
      priority: UIUpdatePriority.low,
      data: stats,
      updateCallback: callback,
      affectedWidgets: {'statistics_panel', 'progress_indicator'},
    );
  }
}

/// UI批量更新器
class UIBatchUpdater implements IUIBatchUpdater {
  final UIBatchUpdateConfig config;

  // 更新队列（按优先级分组）
  final Map<UIUpdatePriority, Queue<UIUpdateItem>> _updateQueues = {
    for (var priority in UIUpdatePriority.values)
      priority: Queue<UIUpdateItem>()
  };

  // 批处理定时器
  Timer? _batchTimer;

  // 帧同步
  int? _frameCallbackId;

  // 去重映射
  final Map<String, UIUpdateItem> _deduplicationMap = {};

  // 统计信息
  int _totalUpdates = 0;
  int _batchedUpdates = 0;
  int _skippedUpdates = 0;
  final List<Duration> _processingTimes = [];

  UIBatchUpdater({this.config = const UIBatchUpdateConfig()});

  /// 添加UI更新项
  @override
  void addUpdate(UIUpdateItem item) {
    _totalUpdates++;

    // 去重检查
    if (_shouldDeduplicate(item)) {
      _skippedUpdates++;
      return;
    }

    // 添加到对应优先级队列
    final priority = _getEffectivePriority(item);
    _updateQueues[priority]!.add(item);
    _deduplicationMap[item.id] = item;

    // 根据优先级决定处理策略
    switch (priority) {
      case UIUpdatePriority.immediate:
        _processImmediately([item]);
        break;

      case UIUpdatePriority.high:
        if (config.enableFrameSync) {
          _scheduleFrameUpdate();
        } else {
          _scheduleBatchUpdate();
        }
        break;

      case UIUpdatePriority.normal:
      case UIUpdatePriority.low:
      case UIUpdatePriority.background:
        _scheduleBatchUpdate();
        break;
    }
  }

  /// 批量添加更新项
  @override
  void addUpdates(List<UIUpdateItem> items) {
    for (final item in items) {
      addUpdate(item);
    }
  }

  /// 判断是否应该去重
  bool _shouldDeduplicate(UIUpdateItem item) {
    final existing = _deduplicationMap[item.id];
    if (existing == null) return false;

    // 如果新项优先级更高，替换现有项
    if (_getPriorityValue(item.priority) >
        _getPriorityValue(existing.priority)) {
      _removeFromQueues(existing);
      return false;
    }

    // 如果是相同类型的更新，合并数据
    if (existing.type == item.type) {
      _mergeUpdateItems(existing, item);
      return true;
    }

    return false;
  }

  /// 获取有效优先级
  UIUpdatePriority _getEffectivePriority(UIUpdateItem item) {
    return config.typePriorities[item.type] ?? item.priority;
  }

  /// 获取优先级数值
  int _getPriorityValue(UIUpdatePriority priority) {
    switch (priority) {
      case UIUpdatePriority.immediate:
        return 5;
      case UIUpdatePriority.high:
        return 4;
      case UIUpdatePriority.normal:
        return 3;
      case UIUpdatePriority.low:
        return 2;
      case UIUpdatePriority.background:
        return 1;
    }
  }

  /// 立即处理更新
  void _processImmediately(List<UIUpdateItem> items) {
    final stopwatch = Stopwatch()..start();

    for (final item in items) {
      item.updateCallback?.call();
      _deduplicationMap.remove(item.id);
    }

    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);
  }

  /// 调度帧更新
  void _scheduleFrameUpdate() {
    if (_frameCallbackId != null) return;

    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameCallbackId = null;
      _processBatchUpdates();
    });
  }

  /// 调度批量更新
  void _scheduleBatchUpdate() {
    _batchTimer?.cancel();
    _batchTimer = Timer(config.batchWindow, () {
      _processBatchUpdates();
    });
  }

  /// 处理批量更新
  void _processBatchUpdates() {
    final stopwatch = Stopwatch()..start();
    final allUpdates = <UIUpdateItem>[];

    // 按优先级收集更新项
    for (final priority in UIUpdatePriority.values.reversed) {
      final queue = _updateQueues[priority]!;
      while (queue.isNotEmpty && allUpdates.length < config.maxBatchSize) {
        allUpdates.add(queue.removeFirst());
      }
    }

    if (allUpdates.isEmpty) return;

    // 按影响的组件分组
    final componentGroups = _groupByAffectedComponents(allUpdates);

    // 按组处理更新
    for (final group in componentGroups) {
      _processUpdateGroup(group);
    }

    // 清理去重映射
    for (final item in allUpdates) {
      _deduplicationMap.remove(item.id);
    }

    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);
    _batchedUpdates += allUpdates.length;
  }

  /// 按影响的组件分组
  List<List<UIUpdateItem>> _groupByAffectedComponents(
      List<UIUpdateItem> updates) {
    final groups = <String, List<UIUpdateItem>>{};

    for (final update in updates) {
      if (update.affectedWidgets.isEmpty) {
        // 没有指定影响组件的更新单独处理
        groups['_ungrouped_${update.id}'] = [update];
      } else {
        // 按第一个影响的组件分组
        final primaryComponent = update.affectedWidgets.first;
        groups.putIfAbsent(primaryComponent, () => []).add(update);
      }
    }

    return groups.values.toList();
  }

  /// 处理更新组
  void _processUpdateGroup(List<UIUpdateItem> group) {
    // 按类型进一步分组
    final typeGroups = <UIUpdateType, List<UIUpdateItem>>{};

    for (final item in group) {
      typeGroups.putIfAbsent(item.type, () => []).add(item);
    }

    // 处理每种类型的更新
    for (final entry in typeGroups.entries) {
      _processTypeGroup(entry.key, entry.value);
    }
  }

  /// 处理类型组
  void _processTypeGroup(UIUpdateType type, List<UIUpdateItem> items) {
    switch (type) {
      case UIUpdateType.goalListUpdate:
        _processGoalListUpdates(items);
        break;

      case UIUpdateType.goalItemUpdate:
        _processGoalItemUpdates(items);
        break;

      case UIUpdateType.statusBarUpdate:
        _processStatusBarUpdates(items);
        break;

      case UIUpdateType.navigationUpdate:
        _processNavigationUpdates(items);
        break;

      case UIUpdateType.statisticsUpdate:
        _processStatisticsUpdates(items);
        break;

      case UIUpdateType.themeUpdate:
        _processThemeUpdates(items);
        break;
    }
  }

  /// 处理目标列表更新
  void _processGoalListUpdates(List<UIUpdateItem> items) {
    // 合并所有目标列表更新
    final allGoals = <Goal>[];
    VoidCallback? lastCallback;

    for (final item in items) {
      final goals = item.data['goals'] as List<Goal>?;
      if (goals != null) {
        allGoals.addAll(goals);
      }
      lastCallback = item.updateCallback ?? lastCallback;
    }

    // 去重目标
    final uniqueGoals = <int, Goal>{};
    for (final goal in allGoals) {
      if (goal.id != null) {
        uniqueGoals[goal.id!] = goal;
      }
    }

    // 执行合并后的更新
    lastCallback?.call();
  }

  /// 处理目标项更新
  void _processGoalItemUpdates(List<UIUpdateItem> items) {
    // 每个目标项单独更新
    for (final item in items) {
      item.updateCallback?.call();
    }
  }

  /// 处理状态栏更新
  void _processStatusBarUpdates(List<UIUpdateItem> items) {
    // 只执行最后一个状态栏更新
    if (items.isNotEmpty) {
      items.last.updateCallback?.call();
    }
  }

  /// 处理导航更新
  void _processNavigationUpdates(List<UIUpdateItem> items) {
    // 只执行最后一个导航更新
    if (items.isNotEmpty) {
      items.last.updateCallback?.call();
    }
  }

  /// 处理统计信息更新
  void _processStatisticsUpdates(List<UIUpdateItem> items) {
    // 合并统计数据
    final mergedStats = <String, dynamic>{};
    VoidCallback? lastCallback;

    for (final item in items) {
      mergedStats.addAll(item.data);
      lastCallback = item.updateCallback ?? lastCallback;
    }

    // 执行合并后的更新
    lastCallback?.call();
  }

  /// 处理主题更新
  void _processThemeUpdates(List<UIUpdateItem> items) {
    // 只执行最后一个主题更新
    if (items.isNotEmpty) {
      items.last.updateCallback?.call();
    }
  }

  /// 从队列中移除项目
  void _removeFromQueues(UIUpdateItem item) {
    for (final queue in _updateQueues.values) {
      queue.remove(item);
    }
  }

  /// 合并更新项
  void _mergeUpdateItems(UIUpdateItem existing, UIUpdateItem newItem) {
    // 简化实现：更新时间戳
    existing.data.addAll(newItem.data);
  }

  /// 强制处理所有待更新项
  @override
  void flush() {
    _batchTimer?.cancel();
    if (_frameCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId!);
      _frameCallbackId = null;
    }

    _processBatchUpdates();
  }

  /// 获取更新统计
  @override
  UIBatchUpdateStats getStats() {
    final avgProcessingTime = _processingTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                (_processingTimes.fold(0, (sum, d) => sum + d.inMilliseconds) /
                        _processingTimes.length)
                    .round());

    final batchRate =
        _totalUpdates == 0 ? 0.0 : _batchedUpdates / _totalUpdates;
    final skipRate = _totalUpdates == 0 ? 0.0 : _skippedUpdates / _totalUpdates;

    return UIBatchUpdateStats(
      totalUpdates: _totalUpdates,
      batchedUpdates: _batchedUpdates,
      skippedUpdates: _skippedUpdates,
      batchRate: batchRate,
      skipRate: skipRate,
      averageProcessingTime: avgProcessingTime,
      pendingUpdates:
          _updateQueues.values.fold(0, (sum, queue) => sum + queue.length),
    );
  }

  /// 重置统计
  void resetStats() {
    _totalUpdates = 0;
    _batchedUpdates = 0;
    _skippedUpdates = 0;
    _processingTimes.clear();
  }

  /// 释放资源
  @override
  void dispose() {
    _batchTimer?.cancel();
    if (_frameCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId!);
    }
    flush(); // 处理剩余更新
  }
}

/// UI批量更新统计
class UIBatchUpdateStats {
  final int totalUpdates;
  final int batchedUpdates;
  final int skippedUpdates;
  final double batchRate;
  final double skipRate;
  final Duration averageProcessingTime;
  final int pendingUpdates;

  const UIBatchUpdateStats({
    required this.totalUpdates,
    required this.batchedUpdates,
    required this.skippedUpdates,
    required this.batchRate,
    required this.skipRate,
    required this.averageProcessingTime,
    required this.pendingUpdates,
  });

  /// 获取效率等级
  String get efficiencyLevel {
    if (batchRate > 0.8 && skipRate > 0.3) return 'Excellent';
    if (batchRate > 0.6 && skipRate > 0.2) return 'Good';
    if (batchRate > 0.4 && skipRate > 0.1) return 'Fair';
    return 'Poor';
  }
}
