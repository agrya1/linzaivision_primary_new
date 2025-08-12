/// 加载性能优化器
///
/// 提供智能的加载优化策略，包括预加载、缓存、分页、懒加载等技术
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';

/// 加载策略
enum LoadingStrategy {
  eager, // 立即加载
  lazy, // 懒加载
  preload, // 预加载
  cached, // 缓存加载
  paginated, // 分页加载
  adaptive, // 自适应加载
}

/// 缓存策略
enum CacheStrategy {
  none, // 无缓存
  memory, // 内存缓存
  persistent, // 持久化缓存
  hybrid, // 混合缓存
}

/// 加载优化配置
class LoadingOptimizationConfig {
  final LoadingStrategy strategy;
  final CacheStrategy cacheStrategy;
  final int pageSize;
  final int maxCacheSize;
  final Duration cacheExpiry;
  final bool enablePreloading;
  final bool enablePrefetching;
  final int prefetchThreshold;
  final Duration loadTimeout;

  const LoadingOptimizationConfig({
    this.strategy = LoadingStrategy.adaptive,
    this.cacheStrategy = CacheStrategy.hybrid,
    this.pageSize = 20,
    this.maxCacheSize = 1000,
    this.cacheExpiry = const Duration(minutes: 30),
    this.enablePreloading = true,
    this.enablePrefetching = true,
    this.prefetchThreshold = 5,
    this.loadTimeout = const Duration(seconds: 10),
  });

  /// 高性能配置
  factory LoadingOptimizationConfig.highPerformance() {
    return const LoadingOptimizationConfig(
      strategy: LoadingStrategy.preload,
      cacheStrategy: CacheStrategy.hybrid,
      pageSize: 50,
      maxCacheSize: 2000,
      enablePreloading: true,
      enablePrefetching: true,
      prefetchThreshold: 3,
    );
  }

  /// 低内存配置
  factory LoadingOptimizationConfig.lowMemory() {
    return const LoadingOptimizationConfig(
      strategy: LoadingStrategy.lazy,
      cacheStrategy: CacheStrategy.none,
      pageSize: 10,
      maxCacheSize: 100,
      enablePreloading: false,
      enablePrefetching: false,
    );
  }
}

/// 加载结果
class LoadingResult<T> {
  final List<T> data;
  final bool hasMore;
  final int totalCount;
  final Duration loadTime;
  final bool fromCache;
  final String? error;

  const LoadingResult({
    required this.data,
    required this.hasMore,
    required this.totalCount,
    required this.loadTime,
    this.fromCache = false,
    this.error,
  });

  bool get isSuccess => error == null;
  bool get isEmpty => data.isEmpty;
  int get loadedCount => data.length;
}

/// 缓存项
class CacheItem<T> {
  final String key;
  final T data;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final int accessCount;

  CacheItem({
    required this.key,
    required this.data,
    DateTime? createdAt,
    DateTime? lastAccessed,
    this.accessCount = 1,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessed = lastAccessed ?? DateTime.now();

  /// 创建访问更新的副本
  CacheItem<T> withAccess() {
    return CacheItem<T>(
      key: key,
      data: data,
      createdAt: createdAt,
      lastAccessed: DateTime.now(),
      accessCount: accessCount + 1,
    );
  }

  /// 检查是否过期
  bool isExpired(Duration expiry) {
    return DateTime.now().difference(createdAt) > expiry;
  }
}

/// 智能缓存管理器
class SmartCacheManager<T> {
  final int maxSize;
  final Duration expiry;
  final LinkedHashMap<String, CacheItem<T>> _cache =
      LinkedHashMap<String, CacheItem<T>>();

  SmartCacheManager({
    required this.maxSize,
    required this.expiry,
  });

  /// 获取缓存项
  T? get(String key) {
    final item = _cache[key];
    if (item == null) return null;

    // 检查是否过期
    if (item.isExpired(expiry)) {
      _cache.remove(key);
      return null;
    }

    // 更新访问信息
    _cache[key] = item.withAccess();

    // 移动到末尾（LRU）
    _cache.remove(key);
    _cache[key] = item.withAccess();

    return item.data;
  }

  /// 设置缓存项
  void set(String key, T data) {
    // 如果已存在，先移除
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }

    // 检查容量限制
    if (_cache.length >= maxSize) {
      _evictLeastUsed();
    }

    // 添加新项
    _cache[key] = CacheItem<T>(key: key, data: data);
  }

  /// 移除缓存项
  void remove(String key) {
    _cache.remove(key);
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
  }

  /// 获取缓存统计
  CacheStats getStats() {
    int expiredCount = 0;
    int totalAccess = 0;

    for (final item in _cache.values) {
      if (item.isExpired(expiry)) {
        expiredCount++;
      }
      totalAccess += item.accessCount;
    }

    return CacheStats(
      totalItems: _cache.length,
      expiredItems: expiredCount,
      totalAccess: totalAccess,
      hitRate: totalAccess > 0 ? _cache.length / totalAccess : 0.0,
    );
  }

  /// 清理过期项
  void cleanupExpired() {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired(expiry)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// 驱逐最少使用的项
  void _evictLeastUsed() {
    if (_cache.isEmpty) return;

    // 找到访问次数最少且最久未访问的项
    String? lruKey;
    CacheItem<T>? lruItem;

    for (final entry in _cache.entries) {
      final item = entry.value;

      if (lruItem == null ||
          item.accessCount < lruItem.accessCount ||
          (item.accessCount == lruItem.accessCount &&
              item.lastAccessed.isBefore(lruItem.lastAccessed))) {
        lruKey = entry.key;
        lruItem = item;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
    }
  }
}

/// 缓存统计
class CacheStats {
  final int totalItems;
  final int expiredItems;
  final int totalAccess;
  final double hitRate;

  const CacheStats({
    required this.totalItems,
    required this.expiredItems,
    required this.totalAccess,
    required this.hitRate,
  });
}

/// 加载性能优化器
class LoadingOptimizer {
  final LoadingOptimizationConfig config;
  final DatabaseHelper databaseHelper;
  final SmartCacheManager<List<Goal>> _goalCache;
  final SmartCacheManager<Goal> _singleGoalCache;

  // 预加载队列
  final Queue<String> _preloadQueue = Queue<String>();
  Timer? _preloadTimer;

  // 性能统计
  int _totalLoads = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final List<Duration> _loadTimes = [];

  LoadingOptimizer({
    required this.databaseHelper,
    this.config = const LoadingOptimizationConfig(),
  })  : _goalCache = SmartCacheManager<List<Goal>>(
          maxSize: config.maxCacheSize,
          expiry: config.cacheExpiry,
        ),
        _singleGoalCache = SmartCacheManager<Goal>(
          maxSize: config.maxCacheSize,
          expiry: config.cacheExpiry,
        ) {
    _startPreloadTimer();
  }

  /// 优化加载目标列表
  Future<LoadingResult<Goal>> loadGoals({
    int offset = 0,
    int? limit,
    String? parentId,
    GoalStatus? status,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalLoads++;

    try {
      final cacheKey = _generateCacheKey('goals', {
        'offset': offset,
        'limit': limit,
        'parentId': parentId,
        'status': status?.toString(),
      });

      // 尝试从缓存获取
      if (config.cacheStrategy != CacheStrategy.none) {
        final cached = _goalCache.get(cacheKey);
        if (cached != null) {
          _cacheHits++;
          stopwatch.stop();

          return LoadingResult<Goal>(
            data: cached,
            hasMore: cached.length == (limit ?? config.pageSize),
            totalCount: cached.length,
            loadTime: stopwatch.elapsed,
            fromCache: true,
          );
        }
      }

      _cacheMisses++;

      // 从数据库加载
      final actualLimit = limit ?? config.pageSize;
      final goals = await _loadGoalsFromDatabase(
        offset: offset,
        limit: actualLimit,
        parentId: parentId,
        status: status,
      );

      // 缓存结果
      if (config.cacheStrategy != CacheStrategy.none) {
        _goalCache.set(cacheKey, goals);
      }

      // 预加载下一页
      if (config.enablePrefetching && goals.length == actualLimit) {
        _schedulePreload(
            cacheKey, offset + actualLimit, actualLimit, parentId, status);
      }

      stopwatch.stop();
      _loadTimes.add(stopwatch.elapsed);

      return LoadingResult<Goal>(
        data: goals,
        hasMore: goals.length == actualLimit,
        totalCount: goals.length,
        loadTime: stopwatch.elapsed,
        fromCache: false,
      );
    } catch (e) {
      stopwatch.stop();

      return LoadingResult<Goal>(
        data: [],
        hasMore: false,
        totalCount: 0,
        loadTime: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }

  /// 优化加载单个目标
  Future<Goal?> loadGoal(int goalId) async {
    final stopwatch = Stopwatch()..start();
    _totalLoads++;

    try {
      final cacheKey = 'goal_$goalId';

      // 尝试从缓存获取
      if (config.cacheStrategy != CacheStrategy.none) {
        final cached = _singleGoalCache.get(cacheKey);
        if (cached != null) {
          _cacheHits++;
          return cached;
        }
      }

      _cacheMisses++;

      // 从数据库加载
      final goal = await databaseHelper.getGoal(goalId);

      // 缓存结果
      if (goal != null && config.cacheStrategy != CacheStrategy.none) {
        _singleGoalCache.set(cacheKey, goal);
      }

      stopwatch.stop();
      _loadTimes.add(stopwatch.elapsed);

      return goal;
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error loading goal $goalId: $e');
      return null;
    }
  }

  /// 预加载目标
  Future<void> preloadGoals(List<int> goalIds) async {
    if (!config.enablePreloading) return;

    for (final goalId in goalIds) {
      final cacheKey = 'goal_$goalId';

      // 检查是否已缓存
      if (_singleGoalCache.get(cacheKey) == null) {
        _preloadQueue.add(cacheKey);
      }
    }
  }

  /// 清理缓存
  void clearCache() {
    _goalCache.clear();
    _singleGoalCache.clear();
  }

  /// 获取性能统计
  LoadingPerformanceStats getPerformanceStats() {
    final avgLoadTime = _loadTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                (_loadTimes.fold(0, (sum, d) => sum + d.inMilliseconds) /
                        _loadTimes.length)
                    .round());

    final maxLoadTime = _loadTimes.isEmpty
        ? Duration.zero
        : _loadTimes.reduce((a, b) => a > b ? a : b);

    final cacheHitRate = _totalLoads == 0 ? 0.0 : _cacheHits / _totalLoads;

    return LoadingPerformanceStats(
      totalLoads: _totalLoads,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      cacheHitRate: cacheHitRate,
      averageLoadTime: avgLoadTime,
      maxLoadTime: maxLoadTime,
      goalCacheStats: _goalCache.getStats(),
      singleGoalCacheStats: _singleGoalCache.getStats(),
    );
  }

  /// 从数据库加载目标
  Future<List<Goal>> _loadGoalsFromDatabase({
    required int offset,
    required int limit,
    String? parentId,
    GoalStatus? status,
  }) async {
    // 这里需要根据实际的DatabaseHelper API调整
    final allGoals = await databaseHelper.getGoals();

    // 简化的过滤和分页逻辑
    var filteredGoals = allGoals.where((goal) {
      if (parentId != null && goal.parentId?.toString() != parentId) {
        return false;
      }
      if (status != null && goal.status != status) return false;
      return true;
    }).toList();

    // 分页
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredGoals.length);

    if (startIndex >= filteredGoals.length) return [];

    return filteredGoals.sublist(startIndex, endIndex);
  }

  /// 生成缓存键
  String _generateCacheKey(String prefix, Map<String, dynamic> params) {
    final sortedParams = params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();

    return '$prefix:${sortedParams.join('&')}';
  }

  /// 调度预加载
  void _schedulePreload(String baseKey, int offset, int limit, String? parentId,
      GoalStatus? status) {
    final preloadKey = _generateCacheKey('preload_goals', {
      'offset': offset,
      'limit': limit,
      'parentId': parentId,
      'status': status?.toString(),
    });

    if (!_preloadQueue.contains(preloadKey)) {
      _preloadQueue.add(preloadKey);
    }
  }

  /// 启动预加载定时器
  void _startPreloadTimer() {
    _preloadTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processPreloadQueue();
    });
  }

  /// 处理预加载队列
  void _processPreloadQueue() async {
    if (_preloadQueue.isEmpty) return;

    final key = _preloadQueue.removeFirst();

    // 解析预加载键并执行加载
    if (key.startsWith('preload_goals:')) {
      // 简化实现：实际应用中需要解析参数
      try {
        await loadGoals();
      } catch (e) {
        debugPrint('Preload failed for $key: $e');
      }
    } else if (key.startsWith('goal_')) {
      final goalId = int.tryParse(key.substring(5));
      if (goalId != null) {
        try {
          await loadGoal(goalId);
        } catch (e) {
          debugPrint('Preload failed for goal $goalId: $e');
        }
      }
    }
  }

  /// 释放资源
  void dispose() {
    _preloadTimer?.cancel();
    clearCache();
  }
}

/// 加载性能统计
class LoadingPerformanceStats {
  final int totalLoads;
  final int cacheHits;
  final int cacheMisses;
  final double cacheHitRate;
  final Duration averageLoadTime;
  final Duration maxLoadTime;
  final CacheStats goalCacheStats;
  final CacheStats singleGoalCacheStats;

  const LoadingPerformanceStats({
    required this.totalLoads,
    required this.cacheHits,
    required this.cacheMisses,
    required this.cacheHitRate,
    required this.averageLoadTime,
    required this.maxLoadTime,
    required this.goalCacheStats,
    required this.singleGoalCacheStats,
  });

  /// 获取性能等级
  String get performanceLevel {
    if (cacheHitRate > 0.8 && averageLoadTime.inMilliseconds < 100) {
      return 'Excellent';
    } else if (cacheHitRate > 0.6 && averageLoadTime.inMilliseconds < 300) {
      return 'Good';
    } else if (cacheHitRate > 0.4 && averageLoadTime.inMilliseconds < 500) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }
}
