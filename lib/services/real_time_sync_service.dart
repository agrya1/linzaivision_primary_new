import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/shared/shared_state_bloc.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_event.dart';
import '../bloc/explore/explore_state.dart';
import '../models/goal.dart';
import '../models/explore_card.dart';
import '../utils/cross_page_sync_manager.dart';

/// 实时数据同步服务
/// 
/// 负责监控数据变化并实时同步到所有相关组件
class RealTimeSyncService {
  static RealTimeSyncService? _instance;
  static RealTimeSyncService get instance => _instance ??= RealTimeSyncService._();
  
  RealTimeSyncService._();
  
  // BLoC实例
  SharedStateBloc? _sharedStateBloc;
  GoalBloc? _goalBloc;
  ExploreBloc? _exploreBloc;
  
  // 状态监听器
  StreamSubscription<SharedState>? _sharedStateSubscription;
  StreamSubscription<GoalState>? _goalStateSubscription;
  StreamSubscription<ExploreState>? _exploreStateSubscription;
  
  // 同步状态
  bool _isInitialized = false;
  bool _isRealTimeSyncEnabled = true;
  DateTime? _lastSyncTime;
  
  // 同步队列和防抖
  final List<SyncOperation> _syncQueue = [];
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  // 性能监控
  final Map<String, int> _syncOperationCount = {};
  final Map<String, Duration> _syncOperationTime = {};
  final List<SyncPerformanceMetric> _performanceMetrics = [];
  
  // 错误处理
  final List<SyncError> _syncErrors = [];
  int _consecutiveErrorCount = 0;
  static const int _maxConsecutiveErrors = 5;
  
  /// 初始化实时同步服务
  void initialize({
    required SharedStateBloc sharedStateBloc,
    required GoalBloc goalBloc,
    required ExploreBloc exploreBloc,
  }) {
    if (_isInitialized) {
      _log('实时同步服务已初始化，跳过重复初始化');
      return;
    }
    
    _log('初始化实时数据同步服务');
    
    _sharedStateBloc = sharedStateBloc;
    _goalBloc = goalBloc;
    _exploreBloc = exploreBloc;
    
    // 设置状态监听器
    _setupStateListeners();
    
    // 初始化跨页面同步管理器
    CrossPageSyncManager.instance.initialize(
      sharedStateBloc: sharedStateBloc,
      goalBloc: goalBloc,
      exploreBloc: exploreBloc,
    );
    
    _isInitialized = true;
    _lastSyncTime = DateTime.now();
    
    _log('实时数据同步服务初始化完成');
  }
  
  /// 设置状态监听器
  void _setupStateListeners() {
    // 监听共享状态变化
    _sharedStateSubscription = _sharedStateBloc!.stream.listen(
      _handleSharedStateChange,
      onError: _handleSyncError,
    );
    
    // 监听目标状态变化
    _goalStateSubscription = _goalBloc!.stream.listen(
      _handleGoalStateChange,
      onError: _handleSyncError,
    );
    
    // 监听探索状态变化
    _exploreStateSubscription = _exploreBloc!.stream.listen(
      _handleExploreStateChange,
      onError: _handleSyncError,
    );
    
    _log('实时同步状态监听器设置完成');
  }
  
  /// 处理共享状态变化
  void _handleSharedStateChange(SharedState state) {
    if (!_isRealTimeSyncEnabled) return;
    
    final startTime = DateTime.now();
    
    if (state is SharedStateLoaded) {
      _log('共享状态更新: ${state.goals.length}个目标, ${state.exploreCards.length}个卡片');
      
      // 触发实时同步
      _queueSyncOperation(SyncOperation(
        type: SyncOperationType.sharedStateUpdate,
        data: state,
        timestamp: startTime,
        priority: SyncPriority.high,
      ));
      
    } else if (state is SharedStateError) {
      _handleSyncError(Exception('共享状态错误: ${state.message}'));
    }
    
    _recordSyncOperation('shared_state_sync', startTime);
  }
  
  /// 处理目标状态变化
  void _handleGoalStateChange(GoalState state) {
    if (!_isRealTimeSyncEnabled) return;
    
    final startTime = DateTime.now();
    
    if (state is GoalsLoaded) {
      _log('目标状态更新: ${state.goals.length}个目标');
      
      // 触发实时同步到共享状态
      _queueSyncOperation(SyncOperation(
        type: SyncOperationType.goalStateUpdate,
        data: state,
        timestamp: startTime,
        priority: SyncPriority.high,
      ));
      
    } else if (state is GoalError) {
      _handleSyncError(Exception('目标状态错误: ${state.message}'));
    }
    
    _recordSyncOperation('goal_state_sync', startTime);
  }
  
  /// 处理探索状态变化
  void _handleExploreStateChange(ExploreState state) {
    if (!_isRealTimeSyncEnabled) return;
    
    final startTime = DateTime.now();
    
    if (state is ExploreLoaded) {
      _log('探索状态更新: ${state.cards.length}个卡片');
      
      // 触发实时同步到共享状态
      _queueSyncOperation(SyncOperation(
        type: SyncOperationType.exploreStateUpdate,
        data: state,
        timestamp: startTime,
        priority: SyncPriority.medium,
      ));
      
    } else if (state is ExploreError) {
      _handleSyncError(Exception('探索状态错误: ${state.message}'));
    }
    
    _recordSyncOperation('explore_state_sync', startTime);
  }
  
  /// 将同步操作加入队列
  void _queueSyncOperation(SyncOperation operation) {
    _syncQueue.add(operation);
    
    // 使用防抖机制避免频繁同步
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _processSyncQueue);
  }
  
  /// 处理同步队列
  void _processSyncQueue() {
    if (_syncQueue.isEmpty) return;
    
    final startTime = DateTime.now();
    _log('处理同步队列: ${_syncQueue.length}个操作');
    
    // 按优先级排序
    _syncQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    // 批量处理同步操作
    final operations = List<SyncOperation>.from(_syncQueue);
    _syncQueue.clear();
    
    _processSyncOperations(operations);
    
    _recordSyncOperation('queue_processing', startTime);
  }
  
  /// 处理同步操作
  void _processSyncOperations(List<SyncOperation> operations) {
    for (final operation in operations) {
      try {
        switch (operation.type) {
          case SyncOperationType.goalStateUpdate:
            _syncGoalStateToShared(operation.data as GoalsLoaded);
            break;
          case SyncOperationType.exploreStateUpdate:
            _syncExploreStateToShared(operation.data as ExploreLoaded);
            break;
          case SyncOperationType.sharedStateUpdate:
            _syncSharedStateToPages(operation.data as SharedStateLoaded);
            break;
        }
        
        _consecutiveErrorCount = 0; // 重置错误计数
        
      } catch (e) {
        _handleSyncError(e);
      }
    }
  }
  
  /// 同步目标状态到共享状态
  void _syncGoalStateToShared(GoalsLoaded goalState) {
    _sharedStateBloc?.add(SyncGoalData(
      goals: goalState.goals,
      allGoals: goalState.allGoals,
      currentGoal: goalState.currentGoal,
    ));
  }
  
  /// 同步探索状态到共享状态
  void _syncExploreStateToShared(ExploreLoaded exploreState) {
    _sharedStateBloc?.add(SyncExploreData(
      cards: exploreState.cards,
      selectedCard: exploreState.selectedCard,
    ));
  }
  
  /// 同步共享状态到各页面
  void _syncSharedStateToPages(SharedStateLoaded sharedState) {
    // 通知跨页面同步管理器
    final syncManager = CrossPageSyncManager.instance;
    
    // 检查数据一致性
    if (syncManager.checkDataConsistency()) {
      _log('数据一致性检查通过');
    } else {
      _log('警告: 检测到数据不一致，触发强制同步');
      _forceDataSync();
    }
  }
  
  /// 强制数据同步
  void _forceDataSync() {
    _sharedStateBloc?.add(const RequestDataRefresh(
      requestingPage: 'sync_service',
      dataTypes: ['all'],
    ));
  }
  
  /// 处理同步错误
  void _handleSyncError(dynamic error) {
    _consecutiveErrorCount++;
    
    final syncError = SyncError(
      error: error.toString(),
      timestamp: DateTime.now(),
      consecutiveCount: _consecutiveErrorCount,
    );
    
    _syncErrors.add(syncError);
    _log('同步错误 (${_consecutiveErrorCount}/${_maxConsecutiveErrors}): $error');
    
    // 如果连续错误过多，暂时禁用实时同步
    if (_consecutiveErrorCount >= _maxConsecutiveErrors) {
      _log('连续错误过多，暂时禁用实时同步');
      _isRealTimeSyncEnabled = false;
      
      // 5秒后重新启用
      Timer(const Duration(seconds: 5), () {
        _log('重新启用实时同步');
        _isRealTimeSyncEnabled = true;
        _consecutiveErrorCount = 0;
      });
    }
    
    // 保持错误列表大小
    if (_syncErrors.length > 100) {
      _syncErrors.removeRange(0, _syncErrors.length - 100);
    }
  }
  
  /// 记录同步操作性能
  void _recordSyncOperation(String operationType, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    
    _syncOperationCount[operationType] = (_syncOperationCount[operationType] ?? 0) + 1;
    _syncOperationTime[operationType] = (_syncOperationTime[operationType] ?? Duration.zero) + duration;
    
    // 记录性能指标
    _performanceMetrics.add(SyncPerformanceMetric(
      operationType: operationType,
      duration: duration,
      timestamp: startTime,
    ));
    
    // 保持性能指标列表大小
    if (_performanceMetrics.length > 1000) {
      _performanceMetrics.removeRange(0, _performanceMetrics.length - 1000);
    }
  }
  
  /// 获取同步状态
  SyncStatus getSyncStatus() {
    return SyncStatus(
      isInitialized: _isInitialized,
      isRealTimeSyncEnabled: _isRealTimeSyncEnabled,
      lastSyncTime: _lastSyncTime,
      queueSize: _syncQueue.length,
      consecutiveErrorCount: _consecutiveErrorCount,
      totalOperations: _syncOperationCount.values.fold(0, (a, b) => a + b),
      averageLatency: _calculateAverageLatency(),
    );
  }
  
  /// 计算平均延迟
  Duration _calculateAverageLatency() {
    if (_performanceMetrics.isEmpty) return Duration.zero;
    
    final totalMs = _performanceMetrics
        .map((m) => m.duration.inMilliseconds)
        .fold(0, (a, b) => a + b);
    
    return Duration(milliseconds: totalMs ~/ _performanceMetrics.length);
  }
  
  /// 获取性能统计
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final operationType in _syncOperationCount.keys) {
      final count = _syncOperationCount[operationType] ?? 0;
      final totalTime = _syncOperationTime[operationType] ?? Duration.zero;
      final avgTime = count > 0 ? totalTime.inMilliseconds / count : 0;
      
      stats[operationType] = {
        'count': count,
        'totalTime': totalTime.inMilliseconds,
        'avgTime': avgTime,
      };
    }
    
    stats['syncStatus'] = getSyncStatus().toMap();
    stats['errorCount'] = _syncErrors.length;
    stats['recentErrors'] = _syncErrors.take(5).map((e) => e.toMap()).toList();
    
    return stats;
  }
  
  /// 启用/禁用实时同步
  void setRealTimeSyncEnabled(bool enabled) {
    _isRealTimeSyncEnabled = enabled;
    _log('实时同步${enabled ? '启用' : '禁用'}');
  }
  
  /// 清理资源
  void dispose() {
    _log('清理实时同步服务资源');
    
    _debounceTimer?.cancel();
    _sharedStateSubscription?.cancel();
    _goalStateSubscription?.cancel();
    _exploreStateSubscription?.cancel();
    
    _syncQueue.clear();
    _syncErrors.clear();
    _performanceMetrics.clear();
    _syncOperationCount.clear();
    _syncOperationTime.clear();
    
    _isInitialized = false;
    _isRealTimeSyncEnabled = false;
    
    _log('实时同步服务资源清理完成');
  }
  
  /// 日志输出
  void _log(String message) {
    if (kDebugMode) {
      print('[RealTimeSyncService] $message');
    }
  }
}

/// 同步操作
class SyncOperation {
  final SyncOperationType type;
  final dynamic data;
  final DateTime timestamp;
  final SyncPriority priority;
  
  SyncOperation({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.priority,
  });
}

/// 同步操作类型
enum SyncOperationType {
  goalStateUpdate,
  exploreStateUpdate,
  sharedStateUpdate,
}

/// 同步优先级
enum SyncPriority {
  low,
  medium,
  high,
}

/// 同步错误
class SyncError {
  final String error;
  final DateTime timestamp;
  final int consecutiveCount;
  
  SyncError({
    required this.error,
    required this.timestamp,
    required this.consecutiveCount,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'consecutiveCount': consecutiveCount,
    };
  }
}

/// 性能指标
class SyncPerformanceMetric {
  final String operationType;
  final Duration duration;
  final DateTime timestamp;
  
  SyncPerformanceMetric({
    required this.operationType,
    required this.duration,
    required this.timestamp,
  });
}

/// 同步状态
class SyncStatus {
  final bool isInitialized;
  final bool isRealTimeSyncEnabled;
  final DateTime? lastSyncTime;
  final int queueSize;
  final int consecutiveErrorCount;
  final int totalOperations;
  final Duration averageLatency;
  
  SyncStatus({
    required this.isInitialized,
    required this.isRealTimeSyncEnabled,
    this.lastSyncTime,
    required this.queueSize,
    required this.consecutiveErrorCount,
    required this.totalOperations,
    required this.averageLatency,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'isInitialized': isInitialized,
      'isRealTimeSyncEnabled': isRealTimeSyncEnabled,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'queueSize': queueSize,
      'consecutiveErrorCount': consecutiveErrorCount,
      'totalOperations': totalOperations,
      'averageLatency': averageLatency.inMilliseconds,
    };
  }
}
