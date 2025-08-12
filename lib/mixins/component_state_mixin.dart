import 'package:flutter/material.dart';
import '../utils/component_state_manager.dart';
import '../widgets/component_state_provider.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/explore/explore_event.dart';
import '../models/goal.dart';
import '../models/explore_card.dart';

/// 组件状态混入
///
/// 为StatefulWidget提供统一的组件状态访问接口
/// 简化组件状态管理，减少样板代码
mixin ComponentStateMixin<T extends StatefulWidget> on State<T> {
  ComponentStateManager? _stateManager;
  final List<VoidCallback> _stateListeners = [];

  /// 获取状态管理器
  ComponentStateManager get stateManager {
    _stateManager ??= ComponentStateProvider.maybeManagerOf(context);
    if (_stateManager == null) {
      throw FlutterError(
        'ComponentStateMixin: No ComponentStateProvider found in widget tree.\n'
        'Make sure to wrap your widget with ComponentStateProvider or AutoComponentStateProvider.',
      );
    }
    return _stateManager!;
  }

  /// 安全获取状态管理器（可能为null）
  ComponentStateManager? get stateManagerOrNull {
    _stateManager ??= ComponentStateProvider.maybeManagerOf(context);
    return _stateManager;
  }

  /// 检查状态管理器是否可用
  bool get hasStateManager => stateManagerOrNull != null;

  // ==================== 状态访问方法 ====================

  /// 获取组件状态
  S? getComponentState<S>(String key) {
    return stateManagerOrNull?.getState<S>(key);
  }

  /// 设置组件状态
  void setComponentState<S>(String key, S value) {
    stateManagerOrNull?.setState(key, value);
  }

  /// 监听状态变化
  void listenToState(String key, VoidCallback listener) {
    if (hasStateManager) {
      stateManager.addStateListener(key, listener);
      _stateListeners
          .add(() => stateManager.removeStateListener(key, listener));
    }
  }

  /// 监听多个状态变化
  void listenToStates(List<String> keys, VoidCallback listener) {
    for (final key in keys) {
      listenToState(key, listener);
    }
  }

  // ==================== 便捷状态访问器 ====================

  /// 当前目标
  Goal? get currentGoal =>
      getComponentState<Goal>(ComponentStateKeys.currentGoal);
  set currentGoal(Goal? goal) =>
      setComponentState(ComponentStateKeys.currentGoal, goal);

  /// 目标列表
  List<Goal> get goals =>
      getComponentState<List<Goal>>(ComponentStateKeys.goals) ?? [];
  set goals(List<Goal> goalList) =>
      setComponentState(ComponentStateKeys.goals, goalList);

  /// 所有目标
  List<Goal> get allGoals =>
      getComponentState<List<Goal>>(ComponentStateKeys.allGoals) ?? [];
  set allGoals(List<Goal> goalList) =>
      setComponentState(ComponentStateKeys.allGoals, goalList);

  /// 最后添加的目标
  Goal? get lastAddedGoal =>
      getComponentState<Goal>(ComponentStateKeys.lastAddedGoal);

  /// 是否正在编辑标题
  bool get isEditingTitle =>
      getComponentState<bool>(ComponentStateKeys.isEditingTitle) ?? false;
  set isEditingTitle(bool editing) =>
      setComponentState(ComponentStateKeys.isEditingTitle, editing);

  /// 是否正在编辑描述
  bool get isEditingDescription =>
      getComponentState<bool>(ComponentStateKeys.isEditingDescription) ?? false;
  set isEditingDescription(bool editing) =>
      setComponentState(ComponentStateKeys.isEditingDescription, editing);

  /// 编辑中的标题文本
  String? get editingTitleText =>
      getComponentState<String>(ComponentStateKeys.editingTitleText);
  set editingTitleText(String? text) =>
      setComponentState(ComponentStateKeys.editingTitleText, text);

  /// 编辑中的描述文本
  String? get editingDescriptionText =>
      getComponentState<String>(ComponentStateKeys.editingDescriptionText);
  set editingDescriptionText(String? text) =>
      setComponentState(ComponentStateKeys.editingDescriptionText, text);

  /// 视图模式
  int get viewMode => getComponentState<int>(ComponentStateKeys.viewMode) ?? 0;
  set viewMode(int mode) =>
      setComponentState(ComponentStateKeys.viewMode, mode);

  /// 当前索引
  int get currentIndex =>
      getComponentState<int>(ComponentStateKeys.currentIndex) ?? 0;
  set currentIndex(int index) =>
      setComponentState(ComponentStateKeys.currentIndex, index);

  /// 显示倒计时
  bool get showCountdown =>
      getComponentState<bool>(ComponentStateKeys.showCountdown) ?? false;
  set showCountdown(bool show) =>
      setComponentState(ComponentStateKeys.showCountdown, show);

  /// 显示时间
  bool get showTime =>
      getComponentState<bool>(ComponentStateKeys.showTime) ?? true;
  set showTime(bool show) =>
      setComponentState(ComponentStateKeys.showTime, show);

  /// 显示描述
  bool get showDescription =>
      getComponentState<bool>(ComponentStateKeys.showDescription) ?? true;
  set showDescription(bool show) =>
      setComponentState(ComponentStateKeys.showDescription, show);

  /// 显示标题
  bool get showTitle =>
      getComponentState<bool>(ComponentStateKeys.showTitle) ?? true;
  set showTitle(bool show) =>
      setComponentState(ComponentStateKeys.showTitle, show);

  /// 探索卡片列表
  List<ExploreCard> get exploreCards =>
      getComponentState<List<ExploreCard>>(ComponentStateKeys.exploreCards) ??
      [];

  /// 选中的探索卡片
  ExploreCard? get selectedCard =>
      getComponentState<ExploreCard>(ComponentStateKeys.selectedCard);
  set selectedCard(ExploreCard? card) =>
      setComponentState(ComponentStateKeys.selectedCard, card);

  /// 是否正在加载
  bool get isLoading =>
      getComponentState<bool>(ComponentStateKeys.isLoading) ?? false;

  /// 错误信息
  String? get error => getComponentState<String>(ComponentStateKeys.error);

  /// 展开状态
  Map<int?, bool> get expansionState =>
      getComponentState<Map<int?, bool>>(ComponentStateKeys.expansionState) ??
      {};
  set expansionState(Map<int?, bool> state) =>
      setComponentState(ComponentStateKeys.expansionState, state);

  // ==================== 事件分发方法 ====================

  /// 分发Goal事件
  void dispatchGoalEvent(GoalEvent event) {
    stateManagerOrNull?.dispatchGoalEvent(event);
  }

  /// 分发Explore事件
  void dispatchExploreEvent(ExploreEvent event) {
    stateManagerOrNull?.dispatchExploreEvent(event);
  }

  // ==================== 便捷操作方法 ====================

  /// 选择目标
  void selectGoal(Goal goal) {
    currentGoal = goal;
    dispatchGoalEvent(SelectGoal(goal));
  }

  /// 开始编辑标题
  void startEditingTitle() {
    isEditingTitle = true;
    editingTitleText = currentGoal?.title ?? '';
    dispatchGoalEvent(const StartEditingTitle());
  }

  /// 保存标题
  void saveTitle(String newTitle) {
    if (currentGoal != null && currentGoal!.id != null) {
      editingTitleText = newTitle;
      dispatchGoalEvent(SaveTitle(newTitle));
    }
  }

  /// 取消编辑标题
  void cancelEditingTitle() {
    isEditingTitle = false;
    editingTitleText = null;
    dispatchGoalEvent(const CancelEditing());
  }

  /// 开始编辑描述
  void startEditingDescription() {
    isEditingDescription = true;
    editingDescriptionText = currentGoal?.description ?? '';
    dispatchGoalEvent(const StartEditingDescription());
  }

  /// 保存描述
  void saveDescription(String newDescription) {
    if (currentGoal != null && currentGoal!.id != null) {
      editingDescriptionText = newDescription;
      dispatchGoalEvent(SaveDescription(newDescription));
    }
  }

  /// 取消编辑描述
  void cancelEditingDescription() {
    isEditingDescription = false;
    editingDescriptionText = null;
    dispatchGoalEvent(const CancelEditing());
  }

  /// 切换视图模式
  void toggleViewMode() {
    final newMode = viewMode == 0 ? 1 : 0;
    viewMode = newMode;
    dispatchGoalEvent(ToggleViewMode(newMode));
  }

  /// 切换倒计时显示
  void toggleCountdownDisplay() {
    showCountdown = !showCountdown;
    dispatchGoalEvent(ToggleCountdownDisplay(showCountdown));
  }

  /// 切换时间显示
  void toggleTimeDisplay() {
    showTime = !showTime;
    dispatchGoalEvent(ToggleTimeDisplay(showTime));
  }

  /// 切换描述显示
  void toggleDescriptionDisplay() {
    showDescription = !showDescription;
    dispatchGoalEvent(ToggleDescriptionDisplay(showDescription));
  }

  /// 切换标题显示
  void toggleTitleDisplay() {
    showTitle = !showTitle;
    dispatchGoalEvent(ToggleTitleDisplay(showTitle));
  }

  /// 添加新目标
  void addGoal(Goal goal) {
    dispatchGoalEvent(AddGoal(goal));
  }

  /// 更新目标
  void updateGoal(Goal goal) {
    dispatchGoalEvent(UpdateGoal(goal));
  }

  /// 删除目标
  void deleteGoal(int goalId) {
    dispatchGoalEvent(DeleteGoal(goalId));
  }

  /// 刷新目标树
  void refreshGoalTree() {
    dispatchGoalEvent(const RefreshGoalTree());
  }

  /// 使用探索卡片
  void useExploreCard(ExploreCard card) {
    selectedCard = card;
    dispatchExploreEvent(UseCard(card));
  }

  // ==================== 状态监听便捷方法 ====================

  /// 监听当前目标变化
  void listenToCurrentGoal(VoidCallback listener) {
    listenToState(ComponentStateKeys.currentGoal, listener);
  }

  /// 监听目标列表变化
  void listenToGoals(VoidCallback listener) {
    listenToState(ComponentStateKeys.goals, listener);
  }

  /// 监听编辑状态变化
  void listenToEditingState(VoidCallback listener) {
    listenToStates([
      ComponentStateKeys.isEditingTitle,
      ComponentStateKeys.isEditingDescription,
    ], listener);
  }

  /// 监听视图状态变化
  void listenToViewState(VoidCallback listener) {
    listenToStates([
      ComponentStateKeys.viewMode,
      ComponentStateKeys.showCountdown,
      ComponentStateKeys.showTime,
      ComponentStateKeys.showDescription,
      ComponentStateKeys.showTitle,
    ], listener);
  }

  // ==================== 生命周期管理 ====================

  @override
  void dispose() {
    // 清理状态监听器
    for (final cleanup in _stateListeners) {
      cleanup();
    }
    _stateListeners.clear();

    super.dispose();
  }
}
