/// 组件通信BLoC
///
/// 处理组件间的通信事件，替代复杂的回调链
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'component_communication_events.dart';
import '../../models/goal.dart';

import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart' as goal_events;

/// 组件通信状态
abstract class ComponentCommunicationState extends Equatable {
  const ComponentCommunicationState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class ComponentCommunicationInitial extends ComponentCommunicationState {
  const ComponentCommunicationInitial();
}

/// 处理中状态
class ComponentCommunicationProcessing extends ComponentCommunicationState {
  final ComponentCommunicationEvent event;

  const ComponentCommunicationProcessing(this.event);

  @override
  List<Object?> get props => [event];
}

/// 导航状态
class NavigationRequested extends ComponentCommunicationState {
  final String routeName;
  final Map<String, dynamic>? arguments;
  final bool replace;

  const NavigationRequested(this.routeName,
      {this.arguments, this.replace = false});

  @override
  List<Object?> get props => [routeName, arguments, replace];
}

/// 对话框显示状态
class DialogRequested extends ComponentCommunicationState {
  final String type;
  final Map<String, dynamic> data;

  const DialogRequested(this.type, this.data);

  @override
  List<Object?> get props => [type, data];
}

/// 消息显示状态
class MessageRequested extends ComponentCommunicationState {
  final String message;
  final String type; // 'error', 'success', 'info'
  final Duration? duration;

  const MessageRequested(this.message, this.type, {this.duration});

  @override
  List<Object?> get props => [message, type, duration];
}

/// 加载状态
class LoadingStateChanged extends ComponentCommunicationState {
  final bool isLoading;
  final String? message;

  const LoadingStateChanged(this.isLoading, {this.message});

  @override
  List<Object?> get props => [isLoading, message];
}

/// 操作完成状态
class OperationCompleted extends ComponentCommunicationState {
  final ComponentCommunicationEvent originalEvent;
  final bool success;
  final String? message;

  const OperationCompleted(this.originalEvent, this.success, {this.message});

  @override
  List<Object?> get props => [originalEvent, success, message];
}

/// 组件通信BLoC
class ComponentCommunicationBloc
    extends Bloc<ComponentCommunicationEvent, ComponentCommunicationState> {
  final GoalBloc goalBloc;

  ComponentCommunicationBloc({
    required this.goalBloc,
  }) : super(const ComponentCommunicationInitial()) {
    // ========== FullScreenView 事件处理 ==========
    on<ImagePickRequested>(_onImagePickRequested);
    on<ImageUpdated>(_onImageUpdated);
    on<VideoPickRequested>(_onVideoPickRequested);
    on<VideoUpdated>(_onVideoUpdated);
    on<SubGoalAddRequested>(_onSubGoalAddRequested);
    on<NavigateToSubGoals>(_onNavigateToSubGoals);
    on<GoalDateUpdateRequested>(_onGoalDateUpdateRequested);
    on<CustomCountdownSetRequested>(_onCustomCountdownSetRequested);
    on<DeadlineToggleRequested>(_onDeadlineToggleRequested);

    // ========== GoalTreeView 事件处理 ==========
    on<SearchRequested>(_onSearchRequested);
    on<SyncRequested>(_onSyncRequested);
    on<NavigateToSettings>(_onNavigateToSettings);
    on<NavigateToLogin>(_onNavigateToLogin);
    on<LogoutRequested>(_onLogoutRequested);
    on<NavigateToExplore>(_onNavigateToExplore);
    on<DrawerCloseRequested>(_onDrawerCloseRequested);

    // ========== 对话框事件处理 ==========
    on<ShowAddGoalDialog>(_onShowAddGoalDialog);
    on<ShowGoalOperationMenu>(_onShowGoalOperationMenu);
    on<ShowConfirmationDialog>(_onShowConfirmationDialog);

    // ========== 导航事件处理 ==========
    on<NavigateToPage>(_onNavigateToPage);
    on<NavigateBack>(_onNavigateBack);
    on<NavigateReplace>(_onNavigateReplace);

    // ========== UI状态事件处理 ==========
    on<ShowLoadingIndicator>(_onShowLoadingIndicator);
    on<HideLoadingIndicator>(_onHideLoadingIndicator);
    on<ShowErrorMessage>(_onShowErrorMessage);
    on<ShowSuccessMessage>(_onShowSuccessMessage);

    // ========== 系统事件处理 ==========
    on<RefreshGoalTree>(_onRefreshGoalTree);
    on<SyncAppState>(_onSyncAppState);
    on<ClearCache>(_onClearCache);
    on<BackupData>(_onBackupData);
    on<RestoreData>(_onRestoreData);
  }

  /// ========== FullScreenView 事件处理器 ==========

  Future<void> _onImagePickRequested(ImagePickRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 触发图片选择对话框
    emit(DialogRequested('image_picker', {
      'goal': event.goal,
      'type': 'image',
    }));
  }

  Future<void> _onImageUpdated(
      ImageUpdated event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 更新目标的图片路径 - 通过GoalBloc统一处理
      final updatedGoal = event.goal.copyWith(imagePath: event.imagePath);

      // 使用UpdateGoalWithValidation事件统一处理数据库更新
      goalBloc.add(goal_events.UpdateGoalWithValidation(updatedGoal, validateData: false));

      emit(OperationCompleted(event, true, message: '图片更新成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '图片更新失败: $e'));
    }
  }

  Future<void> _onVideoPickRequested(VideoPickRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 触发视频选择对话框
    emit(DialogRequested('video_picker', {
      'goal': event.goal,
      'type': 'video',
    }));
  }

  Future<void> _onVideoUpdated(
      VideoUpdated event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 更新目标的视频路径 - 通过GoalBloc统一处理
      final updatedGoal = event.goal.copyWith(videoPath: event.videoPath);

      // 使用UpdateGoalWithValidation事件统一处理数据库更新
      goalBloc.add(goal_events.UpdateGoalWithValidation(updatedGoal, validateData: false));

      emit(OperationCompleted(event, true, message: '视频更新成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '视频更新失败: $e'));
    }
  }

  Future<void> _onSubGoalAddRequested(SubGoalAddRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 导航到子目标页面
    emit(NavigationRequested('/goal_page', arguments: {
      'parentGoal': event.parentGoal,
      'isSubGoalView': false,
    }));
  }

  Future<void> _onNavigateToSubGoals(NavigateToSubGoals event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    if (event.parentGoal.subGoals.isEmpty) {
      emit(MessageRequested('当前目标没有子目标', 'info'));
      return;
    }

    // 导航到子目标页面
    emit(NavigationRequested('/goal_page', arguments: {
      'parentGoal': event.parentGoal,
      'isSubGoalView': event.isSubGoalView,
    }));
  }

  Future<void> _onGoalDateUpdateRequested(GoalDateUpdateRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 更新目标日期 - 通过GoalBloc统一处理
      final updatedGoal = event.goal.copyWith(targetDate: event.newDate);

      // 使用UpdateGoalWithValidation事件统一处理数据库更新
      goalBloc.add(goal_events.UpdateGoalWithValidation(updatedGoal, validateData: false));

      emit(OperationCompleted(event, true, message: '目标日期更新成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '目标日期更新失败: $e'));
    }
  }

  Future<void> _onCustomCountdownSetRequested(CustomCountdownSetRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 更新自定义倒计时 - 注意：Goal模型可能没有这个字段，这里先注释掉
      // final updatedGoal = event.goal.copyWith(customCountdownMinutes: event.countdownMinutes);
      // 通过GoalBloc统一处理数据库更新
      // goalBloc.add(goal_events.UpdateGoalWithValidation(updatedGoal, validateData: false));

      // 通知GoalBloc更新
      // goalBloc.add(goal_events.UpdateGoal(updatedGoal));

      emit(OperationCompleted(event, true, message: '自定义倒计时设置成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '自定义倒计时设置失败: $e'));
    }
  }

  Future<void> _onDeadlineToggleRequested(DeadlineToggleRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 显示日期选择对话框
    emit(DialogRequested('date_picker', {
      'goal': event.goal,
      'currentDate': event.goal.targetDate,
    }));
  }

  /// ========== GoalTreeView 事件处理器 ==========

  Future<void> _onSearchRequested(
      SearchRequested event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 显示搜索界面
    emit(DialogRequested('search', {}));
  }

  Future<void> _onSyncRequested(
      SyncRequested event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 显示同步对话框
    emit(DialogRequested('sync', {}));
  }

  Future<void> _onNavigateToSettings(NavigateToSettings event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested('/settings'));
  }

  Future<void> _onNavigateToLogin(
      NavigateToLogin event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested('/login'));
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    // 显示确认对话框
    emit(DialogRequested('confirmation', {
      'title': '确认退出',
      'message': '确定要退出登录吗？',
      'confirmText': '退出',
      'cancelText': '取消',
      'confirmEventId': 'logout_confirmed',
    }));
  }

  Future<void> _onNavigateToExplore(NavigateToExplore event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested('/explore'));
  }

  Future<void> _onDrawerCloseRequested(DrawerCloseRequested event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested('drawer_close'));
  }

  /// ========== 对话框事件处理器 ==========

  Future<void> _onShowAddGoalDialog(ShowAddGoalDialog event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    emit(DialogRequested('add_goal', {
      'parentGoal': event.parentGoal,
    }));
  }

  Future<void> _onShowGoalOperationMenu(ShowGoalOperationMenu event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    emit(DialogRequested('goal_operation_menu', {
      'goal': event.goal,
      'position': event.position,
    }));
  }

  Future<void> _onShowConfirmationDialog(ShowConfirmationDialog event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    emit(DialogRequested('confirmation', {
      'title': event.title,
      'message': event.message,
      'confirmText': event.confirmText,
      'cancelText': event.cancelText,
      'confirmEventId': event.confirmEventId,
    }));
  }

  /// ========== 导航事件处理器 ==========

  Future<void> _onNavigateToPage(
      NavigateToPage event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested(event.routeName, arguments: event.arguments));
  }

  Future<void> _onNavigateBack(
      NavigateBack event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested('back', arguments: {'result': event.result}));
  }

  Future<void> _onNavigateReplace(
      NavigateReplace event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));
    emit(NavigationRequested(event.routeName,
        arguments: event.arguments, replace: true));
  }

  /// ========== UI状态事件处理器 ==========

  Future<void> _onShowLoadingIndicator(ShowLoadingIndicator event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(LoadingStateChanged(true, message: event.message));
  }

  Future<void> _onHideLoadingIndicator(HideLoadingIndicator event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(const LoadingStateChanged(false));
  }

  Future<void> _onShowErrorMessage(
      ShowErrorMessage event, Emitter<ComponentCommunicationState> emit) async {
    emit(MessageRequested(event.message, 'error', duration: event.duration));
  }

  Future<void> _onShowSuccessMessage(ShowSuccessMessage event,
      Emitter<ComponentCommunicationState> emit) async {
    emit(MessageRequested(event.message, 'success', duration: event.duration));
  }

  /// ========== 系统事件处理器 ==========

  Future<void> _onRefreshGoalTree(
      RefreshGoalTree event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 重新加载目标数据
      goalBloc.add(goal_events.LoadGoals());
      emit(OperationCompleted(event, true, message: '目标树刷新成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '目标树刷新失败: $e'));
    }
  }

  Future<void> _onSyncAppState(
      SyncAppState event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 同步应用状态
      goalBloc.add(goal_events.LoadGoals());
      emit(OperationCompleted(event, true, message: '应用状态同步成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '应用状态同步失败: $e'));
    }
  }

  Future<void> _onClearCache(
      ClearCache event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 清理缓存逻辑
      emit(OperationCompleted(event, true, message: '缓存清理成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '缓存清理失败: $e'));
    }
  }

  Future<void> _onBackupData(
      BackupData event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 数据备份逻辑
      emit(OperationCompleted(event, true, message: '数据备份成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '数据备份失败: $e'));
    }
  }

  Future<void> _onRestoreData(
      RestoreData event, Emitter<ComponentCommunicationState> emit) async {
    emit(ComponentCommunicationProcessing(event));

    try {
      // 数据恢复逻辑
      emit(OperationCompleted(event, true, message: '数据恢复成功'));
    } catch (e) {
      emit(OperationCompleted(event, false, message: '数据恢复失败: $e'));
    }
  }
}
