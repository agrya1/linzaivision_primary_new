import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_event.dart';
import '../bloc/explore/explore_state.dart';
import '../bloc/shared/shared_state_bloc.dart';
import '../utils/cross_page_sync_manager.dart';
import '../models/goal.dart';

/// 组件状态键值规范
class ComponentStateKeys {
  // 目标相关状态
  static const String currentGoal = 'currentGoal';
  static const String goals = 'goals';
  static const String allGoals = 'allGoals';
  static const String selectedGoals = 'selectedGoals';
  static const String lastAddedGoal = 'lastAddedGoal';

  // UI状态
  static const String isEditingTitle = 'isEditingTitle';
  static const String isEditingDescription = 'isEditingDescription';
  static const String editingTitleText = 'editingTitleText';
  static const String editingDescriptionText = 'editingDescriptionText';
  static const String isEditingDate = 'isEditingDate';
  static const String editingDate = 'editingDate';
  static const String isEditingImage = 'isEditingImage';
  static const String editingImagePath = 'editingImagePath';

  // 视图状态
  static const String viewMode = 'viewMode';
  static const String currentIndex = 'currentIndex';
  static const String showCountdown = 'showCountdown';
  static const String showTime = 'showTime';
  static const String showDescription = 'showDescription';
  static const String showTitle = 'showTitle';

  // 探索相关状态
  static const String exploreCards = 'exploreCards';
  static const String selectedCard = 'selectedCard';
  static const String exploreViewMode = 'exploreViewMode';
  static const String activeCategory = 'activeCategory';

  // 加载状态
  static const String isLoading = 'isLoading';
  static const String error = 'error';

  // 树形视图状态
  static const String expansionState = 'expansionState';
  static const String searchQuery = 'searchQuery';
}

/// 组件状态管理器
///
/// 统一管理嵌套组件的状态和事件，与现有BLoC架构无缝集成
class ComponentStateManager extends ChangeNotifier {
  // 状态存储
  final Map<String, dynamic> _states = {};
  final Map<String, List<VoidCallback>> _listeners = {};

  // BLoC引用 - 复用现有BLoC实例
  final GoalBloc _goalBloc;
  final ExploreBloc _exploreBloc;
  final SharedStateBloc? _sharedStateBloc;

  // 跨页面同步适配器
  late final CrossPageSyncAdapter _syncAdapter;

  // 状态监听订阅
  StreamSubscription<GoalState>? _goalStateSubscription;
  StreamSubscription<ExploreState>? _exploreStateSubscription;
  StreamSubscription<SharedState>? _sharedStateSubscription;

  // 初始化状态
  bool _isInitialized = false;
  bool _isDisposed = false;

  ComponentStateManager({
    required GoalBloc goalBloc,
    required ExploreBloc exploreBloc,
    SharedStateBloc? sharedStateBloc,
    String pageName = 'component_state',
  })  : _goalBloc = goalBloc,
        _exploreBloc = exploreBloc,
        _sharedStateBloc = sharedStateBloc {
    // 初始化跨页面同步适配器
    _syncAdapter = CrossPageSyncAdapter(pageName: pageName);

    // 设置BLoC状态监听器
    _setupBlocListeners();

    // 初始化状态
    _initializeStates();

    _isInitialized = true;

    if (kDebugMode) {
      print('【ComponentStateManager】初始化完成 - $pageName');
    }
  }

  /// 设置BLoC状态监听器
  void _setupBlocListeners() {
    // 监听GoalBloc状态变化
    _goalStateSubscription = _goalBloc.stream.listen(
      _handleGoalStateChange,
      onError: (error) => _handleBlocError('GoalBloc', error),
    );

    // 监听ExploreBloc状态变化
    _exploreStateSubscription = _exploreBloc.stream.listen(
      _handleExploreStateChange,
      onError: (error) => _handleBlocError('ExploreBloc', error),
    );

    // 监听SharedStateBloc状态变化（如果存在）
    if (_sharedStateBloc != null) {
      _sharedStateSubscription = _sharedStateBloc.stream.listen(
        _handleSharedStateChange,
        onError: (error) => _handleBlocError('SharedStateBloc', error),
      );
    }
  }

  /// 初始化状态
  void _initializeStates() {
    // 从当前BLoC状态初始化组件状态
    _handleGoalStateChange(_goalBloc.state);
    _handleExploreStateChange(_exploreBloc.state);

    if (_sharedStateBloc != null) {
      _handleSharedStateChange(_sharedStateBloc.state);
    }
  }

  /// 处理GoalBloc状态变化
  void _handleGoalStateChange(GoalState state) {
    if (_isDisposed) return;

    if (state is GoalsLoaded) {
      // 同步目标相关状态
      _updateStatesSilently({
        ComponentStateKeys.goals: state.goals,
        ComponentStateKeys.allGoals: state.allGoals,
        ComponentStateKeys.currentGoal: state.currentGoal,
        ComponentStateKeys.lastAddedGoal: state.lastAddedGoal,
        ComponentStateKeys.viewMode: state.viewMode,
        ComponentStateKeys.isEditingTitle: state.isEditingTitle,
        ComponentStateKeys.isEditingDescription: state.isEditingDescription,
        ComponentStateKeys.editingTitleText: state.editingTitleText,
        ComponentStateKeys.editingDescriptionText: state.editingDescriptionText,
        ComponentStateKeys.isEditingDate: state.isEditingDate,
        ComponentStateKeys.editingDate: state.editingDate,
        ComponentStateKeys.isEditingImage: state.isEditingImage,
        ComponentStateKeys.editingImagePath: state.editingImagePath,
        ComponentStateKeys.showCountdown: state.showCountdown,
        ComponentStateKeys.showTime: state.showTime,
        ComponentStateKeys.showDescription: state.showDescription,
        ComponentStateKeys.showTitle: state.showTitle,
        ComponentStateKeys.isLoading: false,
        ComponentStateKeys.error: null,
      });

      if (kDebugMode) {
        print('【ComponentStateManager】同步GoalBloc状态: ${state.goals.length}个目标');
      }
    } else if (state is GoalLoading) {
      _updateStatesSilently({
        ComponentStateKeys.isLoading: true,
        ComponentStateKeys.error: null,
      });
    } else if (state is GoalError) {
      _updateStatesSilently({
        ComponentStateKeys.isLoading: false,
        ComponentStateKeys.error: state.message,
      });
    }

    // 通知监听器
    notifyListeners();
  }

  /// 处理ExploreBloc状态变化
  void _handleExploreStateChange(ExploreState state) {
    if (_isDisposed) return;

    if (state is ExploreLoaded) {
      _updateStatesSilently({
        ComponentStateKeys.exploreCards: state.cards,
        ComponentStateKeys.selectedCard: state.selectedCard,
        ComponentStateKeys.exploreViewMode: state.viewMode,
        ComponentStateKeys.activeCategory: state.activeCategory,
      });

      if (kDebugMode) {
        print(
            '【ComponentStateManager】同步ExploreBloc状态: ${state.cards.length}个卡片');
      }
    } else if (state is ExploreLoading) {
      _updateStatesSilently({
        ComponentStateKeys.isLoading: true,
      });
    } else if (state is ExploreError) {
      _updateStatesSilently({
        ComponentStateKeys.isLoading: false,
        ComponentStateKeys.error: state.message,
      });
    }

    notifyListeners();
  }

  /// 处理SharedStateBloc状态变化
  void _handleSharedStateChange(SharedState state) {
    if (_isDisposed) return;

    if (state is SharedStateLoaded) {
      // 从共享状态同步数据，但不覆盖本地编辑状态
      final currentEditingTitle =
          getState<bool>(ComponentStateKeys.isEditingTitle) ?? false;
      final currentEditingDescription =
          getState<bool>(ComponentStateKeys.isEditingDescription) ?? false;

      if (!currentEditingTitle && !currentEditingDescription) {
        _updateStatesSilently({
          ComponentStateKeys.goals: state.goals,
          ComponentStateKeys.allGoals: state.allGoals,
          ComponentStateKeys.currentGoal: state.currentGoal,
          ComponentStateKeys.exploreCards: state.exploreCards,
          ComponentStateKeys.selectedCard: state.selectedCard,
        });

        notifyListeners();
      }
    }
  }

  /// 处理BLoC错误
  void _handleBlocError(String blocName, dynamic error) {
    if (_isDisposed) return;

    // 记录错误日志
    if (kDebugMode) {
      print('【ComponentStateManager】$blocName 错误: $error');
    }

    _updateStatesSilently({
      ComponentStateKeys.isLoading: false,
      ComponentStateKeys.error: '状态同步错误: $error',
    });

    notifyListeners();
  }

  /// 静默更新状态（不触发通知）
  void _updateStatesSilently(Map<String, dynamic> updates) {
    for (final entry in updates.entries) {
      _states[entry.key] = entry.value;
      _notifyKeyListeners(entry.key);
    }
  }

  /// 获取状态值
  T? getState<T>(String key) {
    return _states[key] as T?;
  }

  /// 设置状态值
  void setState<T>(String key, T value) {
    if (_isDisposed) return;

    // 直接更新状态（移除防抖以简化实现）
    _states[key] = value;
    _notifyKeyListeners(key);

    // 同步到跨页面管理器
    _syncToOtherPages(key, value);

    notifyListeners();
  }

  /// 同步状态到其他页面
  void _syncToOtherPages<T>(String key, T value) {
    try {
      // 根据状态键决定是否需要跨页面同步
      if (key == ComponentStateKeys.currentGoal && value is Goal) {
        _syncAdapter.notifyGoalUpdated(value);
      } else if (key == ComponentStateKeys.goals && value is List<Goal>) {
        // 批量目标更新时请求数据刷新
        _syncAdapter.requestGoalDataRefresh();
      }
    } catch (e) {
      if (kDebugMode) {
        print('【ComponentStateManager】跨页面同步失败: $e');
      }
    }
  }

  /// 分发GoalBloc事件
  void dispatchGoalEvent(GoalEvent event) {
    if (_isDisposed) return;

    try {
      _goalBloc.add(event);
    } catch (e) {
      _handleEventError('GoalEvent', e.toString());
    }
  }

  /// 分发ExploreBloc事件
  void dispatchExploreEvent(ExploreEvent event) {
    if (_isDisposed) return;

    try {
      _exploreBloc.add(event);
    } catch (e) {
      _handleEventError('ExploreEvent', e.toString());
    }
  }

  /// 处理事件分发错误
  void _handleEventError(String eventType, String error) {
    if (kDebugMode) {
      print('【ComponentStateManager】$eventType 分发失败: $error');
    }

    setState(ComponentStateKeys.error, '操作失败: $error');
  }

  /// 添加状态监听器
  void addStateListener(String key, VoidCallback listener) {
    _listeners.putIfAbsent(key, () => []).add(listener);
  }

  /// 移除状态监听器
  void removeStateListener(String key, VoidCallback listener) {
    _listeners[key]?.remove(listener);
    if (_listeners[key]?.isEmpty == true) {
      _listeners.remove(key);
    }
  }

  /// 通知特定键的监听器
  void _notifyKeyListeners(String key) {
    _listeners[key]?.forEach((listener) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) {
          print('【ComponentStateManager】监听器执行失败: $e');
        }
      }
    });
  }

  /// 获取当前BLoC状态
  GoalState get currentGoalState => _goalBloc.state;
  ExploreState get currentExploreState => _exploreBloc.state;
  SharedState? get currentSharedState => _sharedStateBloc?.state;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查是否已释放
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    // 取消BLoC状态监听
    _goalStateSubscription?.cancel();
    _exploreStateSubscription?.cancel();
    _sharedStateSubscription?.cancel();

    // 清理状态和监听器
    _states.clear();
    _listeners.clear();

    if (kDebugMode) {
      print('【ComponentStateManager】已释放资源');
    }

    super.dispose();
  }
}
