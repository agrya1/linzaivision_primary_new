import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/shared/shared_state_bloc.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_state.dart';
import '../models/goal.dart';
import '../models/explore_card.dart';

/// 跨页面状态同步管理器
///
/// 负责协调GoalPage和ExplorePage之间的状态同步
class CrossPageSyncManager {
  static CrossPageSyncManager? _instance;
  static CrossPageSyncManager get instance =>
      _instance ??= CrossPageSyncManager._();

  CrossPageSyncManager._();

  // 状态监听器
  StreamSubscription<GoalState>? _goalStateSubscription;
  StreamSubscription<ExploreState>? _exploreStateSubscription;
  StreamSubscription<SharedState>? _sharedStateSubscription;

  // BLoC实例
  SharedStateBloc? _sharedStateBloc;
  GoalBloc? _goalBloc;
  ExploreBloc? _exploreBloc;

  // 同步状态
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  final Map<String, DateTime> _pageLastUpdateTime = {};

  // 性能监控
  final Map<String, int> _syncOperationCount = {};
  final Map<String, Duration> _syncOperationTime = {};

  /// 初始化跨页面同步管理器
  void initialize({
    required SharedStateBloc sharedStateBloc,
    required GoalBloc goalBloc,
    required ExploreBloc exploreBloc,
  }) {
    if (_isInitialized) {
      _log('跨页面同步管理器已初始化，跳过重复初始化');
      return;
    }

    _log('初始化跨页面状态同步管理器');

    _sharedStateBloc = sharedStateBloc;
    _goalBloc = goalBloc;
    _exploreBloc = exploreBloc;

    // 初始化共享状态
    _sharedStateBloc!.add(const InitializeSharedState());

    // 设置状态监听器
    _setupStateListeners();

    _isInitialized = true;
    _lastSyncTime = DateTime.now();

    _log('跨页面状态同步管理器初始化完成');
  }

  /// 设置状态监听器
  void _setupStateListeners() {
    // 监听GoalBloc状态变化
    _goalStateSubscription = _goalBloc!.stream.listen((goalState) {
      _handleGoalStateChange(goalState);
    });

    // 监听ExploreBloc状态变化
    _exploreStateSubscription = _exploreBloc!.stream.listen((exploreState) {
      _handleExploreStateChange(exploreState);
    });

    // 监听SharedStateBloc状态变化
    _sharedStateSubscription = _sharedStateBloc!.stream.listen((sharedState) {
      _handleSharedStateChange(sharedState);
    });

    _log('状态监听器设置完成');
  }

  /// 处理Goal状态变化
  void _handleGoalStateChange(GoalState goalState) {
    if (!_isInitialized || goalState is! GoalsLoaded) return;

    final startTime = DateTime.now();
    _log('处理Goal状态变化: ${goalState.goals.length}个目标');

    // 同步到共享状态
    _sharedStateBloc!.add(SyncGoalData(
      goals: goalState.goals,
      allGoals: goalState.allGoals,
      currentGoal: goalState.currentGoal,
    ));

    _updatePageTime('goal');
    _recordSyncOperation('goal_state_sync', startTime);
  }

  /// 处理Explore状态变化
  void _handleExploreStateChange(ExploreState exploreState) {
    if (!_isInitialized || exploreState is! ExploreLoaded) return;

    final startTime = DateTime.now();
    _log('处理Explore状态变化: ${exploreState.cards.length}个卡片');

    // 同步到共享状态
    _sharedStateBloc!.add(SyncExploreData(
      cards: exploreState.cards,
      selectedCard: exploreState.selectedCard,
    ));

    _updatePageTime('explore');
    _recordSyncOperation('explore_state_sync', startTime);
  }

  /// 处理共享状态变化
  void _handleSharedStateChange(SharedState sharedState) {
    if (sharedState is SharedStateLoaded) {
      _lastSyncTime = sharedState.lastSyncTime;
      _log(
          '共享状态已更新: ${sharedState.goals.length}个目标, ${sharedState.exploreCards.length}个卡片');
    } else if (sharedState is SharedStateError) {
      _log('共享状态错误: ${sharedState.message}');
    }
  }

  /// 通知目标创建
  void notifyGoalCreated(Goal goal, String sourcePage) {
    if (!_isInitialized) return;

    final startTime = DateTime.now();
    _log('通知目标创建: ${goal.title} (来源: $sourcePage)');

    _sharedStateBloc!.add(CrossPageGoalCreated(
      goal: goal,
      sourcePage: sourcePage,
    ));

    _recordSyncOperation('goal_created', startTime);
  }

  /// 通知目标更新
  void notifyGoalUpdated(Goal goal, String sourcePage) {
    if (!_isInitialized) return;

    final startTime = DateTime.now();
    _log('通知目标更新: ${goal.title} (来源: $sourcePage)');

    _sharedStateBloc!.add(CrossPageGoalUpdated(
      goal: goal,
      sourcePage: sourcePage,
    ));

    _recordSyncOperation('goal_updated', startTime);
  }

  /// 通知目标删除
  void notifyGoalDeleted(int goalId, String sourcePage) {
    if (!_isInitialized) return;

    final startTime = DateTime.now();
    _log('通知目标删除: ID=$goalId (来源: $sourcePage)');

    _sharedStateBloc!.add(CrossPageGoalDeleted(
      goalId: goalId,
      sourcePage: sourcePage,
    ));

    _recordSyncOperation('goal_deleted', startTime);
  }

  /// 请求数据刷新
  void requestDataRefresh(String requestingPage, List<String> dataTypes) {
    if (!_isInitialized) return;

    final startTime = DateTime.now();
    _log('请求数据刷新: $requestingPage -> $dataTypes');

    _sharedStateBloc!.add(RequestDataRefresh(
      requestingPage: requestingPage,
      dataTypes: dataTypes,
    ));

    _recordSyncOperation('data_refresh', startTime);
  }

  /// 获取当前共享状态
  SharedState? get currentSharedState => _sharedStateBloc?.state;

  /// 检查页面是否需要刷新
  bool shouldPageRefresh(String pageName) {
    if (_sharedStateBloc?.state is! SharedStateLoaded) return false;

    final sharedState = _sharedStateBloc!.state as SharedStateLoaded;
    final pageLastUpdate = _pageLastUpdateTime[pageName];
    final sharedLastUpdate = sharedState.pageLastUpdateTime[pageName];

    if (pageLastUpdate == null || sharedLastUpdate == null) return true;

    return sharedLastUpdate.isAfter(pageLastUpdate);
  }

  /// 更新页面时间戳
  void _updatePageTime(String pageName) {
    _pageLastUpdateTime[pageName] = DateTime.now();
  }

  /// 记录同步操作性能
  void _recordSyncOperation(String operationType, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);

    _syncOperationCount[operationType] =
        (_syncOperationCount[operationType] ?? 0) + 1;
    _syncOperationTime[operationType] =
        (_syncOperationTime[operationType] ?? Duration.zero) + duration;
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

    stats['lastSyncTime'] = _lastSyncTime?.toIso8601String();
    stats['isInitialized'] = _isInitialized;

    return stats;
  }

  /// 打印性能统计
  void printPerformanceStats() {
    if (!kDebugMode) return;

    final stats = getPerformanceStats();
    print('\n=== 跨页面同步性能统计 ===');
    print('初始化状态: ${stats['isInitialized']}');
    print('最后同步时间: ${stats['lastSyncTime']}');

    for (final operationType in _syncOperationCount.keys) {
      final operationStats = stats[operationType] as Map<String, dynamic>;
      print('$operationType: ${operationStats['count']}次, '
          '平均耗时: ${operationStats['avgTime'].toStringAsFixed(2)}ms');
    }
    print('========================\n');
  }

  /// 清理资源
  void dispose() {
    _log('清理跨页面同步管理器资源');

    _goalStateSubscription?.cancel();
    _exploreStateSubscription?.cancel();
    _sharedStateSubscription?.cancel();

    _goalStateSubscription = null;
    _exploreStateSubscription = null;
    _sharedStateSubscription = null;

    _sharedStateBloc = null;
    _goalBloc = null;
    _exploreBloc = null;

    _isInitialized = false;
    _lastSyncTime = null;
    _pageLastUpdateTime.clear();
    _syncOperationCount.clear();
    _syncOperationTime.clear();

    _log('跨页面同步管理器资源清理完成');
  }

  /// 日志输出
  void _log(String message) {
    if (kDebugMode) {
      print('[CrossPageSyncManager] $message');
    }
  }
}

/// 跨页面同步适配器
///
/// 为页面提供简化的跨页面同步接口
class CrossPageSyncAdapter {
  final String pageName;
  final CrossPageSyncManager _syncManager;

  CrossPageSyncAdapter({
    required this.pageName,
  }) : _syncManager = CrossPageSyncManager.instance;

  /// 通知目标创建
  void notifyGoalCreated(Goal goal) {
    _syncManager.notifyGoalCreated(goal, pageName);
  }

  /// 通知目标更新
  void notifyGoalUpdated(Goal goal) {
    _syncManager.notifyGoalUpdated(goal, pageName);
  }

  /// 通知目标删除
  void notifyGoalDeleted(int goalId) {
    _syncManager.notifyGoalDeleted(goalId, pageName);
  }

  /// 请求刷新目标数据
  void requestGoalDataRefresh() {
    _syncManager.requestDataRefresh(pageName, ['goals']);
  }

  /// 请求刷新探索数据
  void requestExploreDataRefresh() {
    _syncManager.requestDataRefresh(pageName, ['explore']);
  }

  /// 请求刷新所有数据
  void requestAllDataRefresh() {
    _syncManager.requestDataRefresh(pageName, ['all']);
  }

  /// 检查是否需要刷新
  bool shouldRefresh() {
    return _syncManager.shouldPageRefresh(pageName);
  }

  /// 获取当前共享状态
  SharedState? get currentSharedState => _syncManager.currentSharedState;

  /// 获取当前目标数据
  List<Goal>? get currentGoals {
    final state = _syncManager.currentSharedState;
    return state is SharedStateLoaded ? state.goals : null;
  }

  /// 获取当前所有目标数据
  List<Goal>? get currentAllGoals {
    final state = _syncManager.currentSharedState;
    return state is SharedStateLoaded ? state.allGoals : null;
  }

  /// 获取当前选中目标
  Goal? get currentGoal {
    final state = _syncManager.currentSharedState;
    return state is SharedStateLoaded ? state.currentGoal : null;
  }

  /// 获取当前探索卡片
  List<ExploreCard>? get currentExploreCards {
    final state = _syncManager.currentSharedState;
    return state is SharedStateLoaded ? state.exploreCards : null;
  }

  /// 获取当前选中卡片
  ExploreCard? get currentSelectedCard {
    final state = _syncManager.currentSharedState;
    return state is SharedStateLoaded ? state.selectedCard : null;
  }
}

/// 跨页面同步扩展方法
extension CrossPageSyncExtension on CrossPageSyncManager {
  /// 快速同步目标数据到所有页面
  void syncGoalDataToAllPages(
      List<Goal> goals, List<Goal> allGoals, Goal? currentGoal) {
    if (!_isInitialized) return;

    _sharedStateBloc!.add(SyncGoalData(
      goals: goals,
      allGoals: allGoals,
      currentGoal: currentGoal,
    ));
  }

  /// 快速同步探索数据到所有页面
  void syncExploreDataToAllPages(
      List<ExploreCard> cards, ExploreCard? selectedCard) {
    if (!_isInitialized) return;

    _sharedStateBloc!.add(SyncExploreData(
      cards: cards,
      selectedCard: selectedCard,
    ));
  }

  /// 检查数据一致性
  bool checkDataConsistency() {
    if (_sharedStateBloc?.state is! SharedStateLoaded) return false;

    final sharedState = _sharedStateBloc!.state as SharedStateLoaded;
    final goalState = _goalBloc?.state;
    final exploreState = _exploreBloc?.state;

    bool isConsistent = true;

    // 检查目标数据一致性
    if (goalState is GoalsLoaded) {
      if (sharedState.goals.length != goalState.goals.length ||
          sharedState.allGoals.length != goalState.allGoals.length) {
        _log('警告: 目标数据不一致');
        isConsistent = false;
      }
    }

    // 检查探索数据一致性
    if (exploreState is ExploreLoaded) {
      if (sharedState.exploreCards.length != exploreState.cards.length) {
        _log('警告: 探索数据不一致');
        isConsistent = false;
      }
    }

    return isConsistent;
  }
}
