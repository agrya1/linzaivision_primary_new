import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/shared/shared_state_bloc.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_state.dart';
import '../utils/cross_page_sync_manager.dart';

/// 简化的实时数据同步服务
///
/// 提供基本的实时数据同步功能，专注于核心同步逻辑
class SimpleRealTimeSyncService {
  static SimpleRealTimeSyncService? _instance;
  static SimpleRealTimeSyncService get instance =>
      _instance ??= SimpleRealTimeSyncService._();

  SimpleRealTimeSyncService._();

  // BLoC实例
  SharedStateBloc? _sharedStateBloc;
  GoalBloc? _goalBloc;
  ExploreBloc? _exploreBloc;

  // 状态监听器
  StreamSubscription<GoalState>? _goalStateSubscription;
  StreamSubscription<ExploreState>? _exploreStateSubscription;

  // 同步状态
  bool _isInitialized = false;
  bool _isEnabled = true;
  DateTime? _lastSyncTime;
  int _syncOperationCount = 0;

  // 同步统计
  final Map<String, int> _syncStats = {
    'goalSync': 0,
    'exploreSync': 0,
    'totalOperations': 0,
  };

  /// 初始化简化实时同步服务
  void initialize({
    required SharedStateBloc sharedStateBloc,
    required GoalBloc goalBloc,
    required ExploreBloc exploreBloc,
  }) {
    if (_isInitialized) {
      _log('简化实时同步服务已初始化，跳过重复初始化');
      return;
    }

    _log('初始化简化实时数据同步服务');

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

    _log('简化实时数据同步服务初始化完成');
  }

  /// 设置状态监听器
  void _setupStateListeners() {
    // 监听目标状态变化
    _goalStateSubscription = _goalBloc!.stream.listen(
      _handleGoalStateChange,
      onError: (error) => _log('目标状态监听错误: $error'),
    );

    // 监听探索状态变化
    _exploreStateSubscription = _exploreBloc!.stream.listen(
      _handleExploreStateChange,
      onError: (error) => _log('探索状态监听错误: $error'),
    );

    _log('简化实时同步状态监听器设置完成');
  }

  /// 处理目标状态变化
  void _handleGoalStateChange(GoalState state) {
    if (!_isEnabled || !_isInitialized) return;

    if (state is GoalsLoaded) {
      _log('处理目标状态变化: ${state.goals.length}个目标');

      // 同步到共享状态
      _sharedStateBloc?.add(SyncGoalData(
        goals: state.goals,
        allGoals: state.allGoals,
        currentGoal: state.currentGoal,
      ));

      // 更新统计
      _syncStats['goalSync'] = (_syncStats['goalSync'] ?? 0) + 1;
      _syncStats['totalOperations'] = (_syncStats['totalOperations'] ?? 0) + 1;
      _syncOperationCount++;
      _lastSyncTime = DateTime.now();

      _log('目标状态同步完成，总操作数: $_syncOperationCount');
    }
  }

  /// 处理探索状态变化
  void _handleExploreStateChange(ExploreState state) {
    if (!_isEnabled || !_isInitialized) return;

    if (state is ExploreLoaded) {
      _log('处理探索状态变化: ${state.cards.length}个卡片');

      // 同步到共享状态
      _sharedStateBloc?.add(SyncExploreData(
        cards: state.cards,
        selectedCard: state.selectedCard,
      ));

      // 更新统计
      _syncStats['exploreSync'] = (_syncStats['exploreSync'] ?? 0) + 1;
      _syncStats['totalOperations'] = (_syncStats['totalOperations'] ?? 0) + 1;
      _syncOperationCount++;
      _lastSyncTime = DateTime.now();

      _log('探索状态同步完成，总操作数: $_syncOperationCount');
    }
  }

  /// 手动触发数据同步
  void triggerSync() {
    if (!_isInitialized) {
      _log('同步服务未初始化，无法触发同步');
      return;
    }

    _log('手动触发数据同步');

    // 触发数据刷新
    _sharedStateBloc?.add(const RequestDataRefresh(
      requestingPage: 'sync_service',
      dataTypes: ['all'],
    ));

    _syncStats['totalOperations'] = (_syncStats['totalOperations'] ?? 0) + 1;
    _syncOperationCount++;
    _lastSyncTime = DateTime.now();

    _log('手动同步触发完成');
  }

  /// 启用/禁用实时同步
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _log('简化实时同步${enabled ? '启用' : '禁用'}');
  }

  /// 获取同步状态
  SimpleSyncStatus getStatus() {
    return SimpleSyncStatus(
      isInitialized: _isInitialized,
      isEnabled: _isEnabled,
      lastSyncTime: _lastSyncTime,
      totalOperations: _syncOperationCount,
      syncStats: Map<String, int>.from(_syncStats),
    );
  }

  /// 获取同步统计
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'isEnabled': _isEnabled,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'totalOperations': _syncOperationCount,
      'goalSyncCount': _syncStats['goalSync'] ?? 0,
      'exploreSyncCount': _syncStats['exploreSync'] ?? 0,
      'crossPageSyncManager':
          CrossPageSyncManager.instance.getPerformanceStats(),
    };
  }

  /// 重置统计
  void resetStats() {
    _syncOperationCount = 0;
    _syncStats.clear();
    _syncStats.addAll({
      'goalSync': 0,
      'exploreSync': 0,
      'totalOperations': 0,
    });
    _log('同步统计已重置');
  }

  /// 清理资源
  void dispose() {
    _log('清理简化实时同步服务资源');

    _goalStateSubscription?.cancel();
    _exploreStateSubscription?.cancel();

    _syncStats.clear();
    _isInitialized = false;
    _isEnabled = false;
    _syncOperationCount = 0;

    _log('简化实时同步服务资源清理完成');
  }

  /// 日志输出
  void _log(String message) {
    if (kDebugMode) {
      print('[SimpleRealTimeSyncService] $message');
    }
  }
}

/// 简化同步状态
class SimpleSyncStatus {
  final bool isInitialized;
  final bool isEnabled;
  final DateTime? lastSyncTime;
  final int totalOperations;
  final Map<String, int> syncStats;

  SimpleSyncStatus({
    required this.isInitialized,
    required this.isEnabled,
    this.lastSyncTime,
    required this.totalOperations,
    required this.syncStats,
  });

  Map<String, dynamic> toMap() {
    return {
      'isInitialized': isInitialized,
      'isEnabled': isEnabled,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'totalOperations': totalOperations,
      'syncStats': syncStats,
    };
  }
}

/// 实时同步扩展方法
extension SimpleRealTimeSyncExtension on SimpleRealTimeSyncService {
  /// 快速检查同步状态
  bool get isReady {
    final status = getStatus();
    return status.isInitialized && status.isEnabled;
  }

  /// 获取最后同步时间的格式化字符串
  String get lastSyncTimeFormatted {
    if (_lastSyncTime == null) return '从未同步';

    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '${diff.inHours}小时前';
    }
  }

  /// 获取同步效率（操作/分钟）
  double get syncEfficiency {
    if (_lastSyncTime == null || _syncOperationCount == 0) return 0.0;

    final now = DateTime.now();
    final minutes = now.difference(_lastSyncTime!).inMinutes;

    if (minutes == 0) return _syncOperationCount.toDouble();

    return _syncOperationCount / minutes;
  }
}

/// 实时同步监控器
class SimpleRealTimeSyncMonitor {
  final SimpleRealTimeSyncService _syncService;
  Timer? _monitorTimer;

  SimpleRealTimeSyncMonitor()
      : _syncService = SimpleRealTimeSyncService.instance;

  /// 开始监控
  void startMonitoring({Duration interval = const Duration(seconds: 5)}) {
    _monitorTimer?.cancel();

    _monitorTimer = Timer.periodic(interval, (timer) {
      final status = _syncService.getStatus();
      final stats = _syncService.getStats();

      if (kDebugMode) {
        print('=== 实时同步监控报告 ===');
        print('状态: ${status.isEnabled ? "启用" : "禁用"}');
        print('总操作数: ${status.totalOperations}');
        print('最后同步: ${_syncService.lastSyncTimeFormatted}');
        print('同步效率: ${_syncService.syncEfficiency.toStringAsFixed(2)} 操作/分钟');
        print('目标同步: ${stats['goalSyncCount']}次');
        print('探索同步: ${stats['exploreSyncCount']}次');
        print('========================');
      }
    });
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// 清理资源
  void dispose() {
    stopMonitoring();
  }
}
