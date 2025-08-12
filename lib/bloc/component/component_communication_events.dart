/// 组件通信事件定义
///
/// 定义用于替代复杂回调链的BLoC事件通信机制
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../models/goal.dart';

/// 组件通信事件基类
abstract class ComponentCommunicationEvent extends Equatable {
  const ComponentCommunicationEvent();

  @override
  List<Object?> get props => [];
}

/// ========== FullScreenView 组件事件 ==========

/// 图片选择事件
class ImagePickRequested extends ComponentCommunicationEvent {
  final Goal goal;

  const ImagePickRequested(this.goal);

  @override
  List<Object?> get props => [goal];
}

/// 图片更新事件
class ImageUpdated extends ComponentCommunicationEvent {
  final Goal goal;
  final String imagePath;

  const ImageUpdated(this.goal, this.imagePath);

  @override
  List<Object?> get props => [goal, imagePath];
}

/// 视频选择事件
class VideoPickRequested extends ComponentCommunicationEvent {
  final Goal goal;

  const VideoPickRequested(this.goal);

  @override
  List<Object?> get props => [goal];
}

/// 视频更新事件
class VideoUpdated extends ComponentCommunicationEvent {
  final Goal goal;
  final String videoPath;

  const VideoUpdated(this.goal, this.videoPath);

  @override
  List<Object?> get props => [goal, videoPath];
}

/// 子目标添加请求事件
class SubGoalAddRequested extends ComponentCommunicationEvent {
  final Goal parentGoal;

  const SubGoalAddRequested(this.parentGoal);

  @override
  List<Object?> get props => [parentGoal];
}

/// 子目标页面导航事件
class NavigateToSubGoals extends ComponentCommunicationEvent {
  final Goal parentGoal;
  final bool isSubGoalView;

  const NavigateToSubGoals(this.parentGoal, {this.isSubGoalView = false});

  @override
  List<Object?> get props => [parentGoal, isSubGoalView];
}

/// 目标日期更新事件
class GoalDateUpdateRequested extends ComponentCommunicationEvent {
  final Goal goal;
  final DateTime? newDate;

  const GoalDateUpdateRequested(this.goal, this.newDate);

  @override
  List<Object?> get props => [goal, newDate];
}

/// 自定义倒计时设置事件
class CustomCountdownSetRequested extends ComponentCommunicationEvent {
  final Goal goal;
  final int? countdownMinutes;

  const CustomCountdownSetRequested(this.goal, this.countdownMinutes);

  @override
  List<Object?> get props => [goal, countdownMinutes];
}

/// 截止日期切换事件
class DeadlineToggleRequested extends ComponentCommunicationEvent {
  final Goal goal;

  const DeadlineToggleRequested(this.goal);

  @override
  List<Object?> get props => [goal];
}

/// ========== GoalTreeView 组件事件 ==========

/// 搜索请求事件
class SearchRequested extends ComponentCommunicationEvent {
  const SearchRequested();
}

/// 同步请求事件
class SyncRequested extends ComponentCommunicationEvent {
  const SyncRequested();
}

/// 设置页面导航事件
class NavigateToSettings extends ComponentCommunicationEvent {
  const NavigateToSettings();
}

/// 登录页面导航事件
class NavigateToLogin extends ComponentCommunicationEvent {
  const NavigateToLogin();
}

/// 退出登录事件
class LogoutRequested extends ComponentCommunicationEvent {
  const LogoutRequested();
}

/// 探索页面导航事件
class NavigateToExplore extends ComponentCommunicationEvent {
  const NavigateToExplore();
}

/// 抽屉关闭事件
class DrawerCloseRequested extends ComponentCommunicationEvent {
  const DrawerCloseRequested();
}

/// ========== 对话框组件事件 ==========

/// 添加目标对话框显示事件
class ShowAddGoalDialog extends ComponentCommunicationEvent {
  final Goal? parentGoal;

  const ShowAddGoalDialog({this.parentGoal});

  @override
  List<Object?> get props => [parentGoal];
}

/// 目标操作菜单显示事件
class ShowGoalOperationMenu extends ComponentCommunicationEvent {
  final Goal goal;
  final Offset? position;

  const ShowGoalOperationMenu(this.goal, {this.position});

  @override
  List<Object?> get props => [goal, position];
}

/// 确认对话框显示事件
class ShowConfirmationDialog extends ComponentCommunicationEvent {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final String confirmEventId; // 用于标识确认操作的事件ID

  const ShowConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmEventId,
  });

  @override
  List<Object?> get props =>
      [title, message, confirmText, cancelText, confirmEventId];
}

/// ========== 导航相关事件 ==========

/// 页面导航事件
class NavigateToPage extends ComponentCommunicationEvent {
  final String routeName;
  final Map<String, dynamic>? arguments;

  const NavigateToPage(this.routeName, {this.arguments});

  @override
  List<Object?> get props => [routeName, arguments];
}

/// 页面返回事件
class NavigateBack extends ComponentCommunicationEvent {
  final dynamic result;

  const NavigateBack({this.result});

  @override
  List<Object?> get props => [result];
}

/// 页面替换事件
class NavigateReplace extends ComponentCommunicationEvent {
  final String routeName;
  final Map<String, dynamic>? arguments;

  const NavigateReplace(this.routeName, {this.arguments});

  @override
  List<Object?> get props => [routeName, arguments];
}

/// ========== UI状态事件 ==========

/// 加载状态显示事件
class ShowLoadingIndicator extends ComponentCommunicationEvent {
  final String? message;

  const ShowLoadingIndicator({this.message});

  @override
  List<Object?> get props => [message];
}

/// 加载状态隐藏事件
class HideLoadingIndicator extends ComponentCommunicationEvent {
  const HideLoadingIndicator();
}

/// 错误消息显示事件
class ShowErrorMessage extends ComponentCommunicationEvent {
  final String message;
  final Duration? duration;

  const ShowErrorMessage(this.message, {this.duration});

  @override
  List<Object?> get props => [message, duration];
}

/// 成功消息显示事件
class ShowSuccessMessage extends ComponentCommunicationEvent {
  final String message;
  final Duration? duration;

  const ShowSuccessMessage(this.message, {this.duration});

  @override
  List<Object?> get props => [message, duration];
}

/// ========== 系统事件 ==========

/// 目标树刷新事件
class RefreshGoalTree extends ComponentCommunicationEvent {
  const RefreshGoalTree();
}

/// 应用状态同步事件
class SyncAppState extends ComponentCommunicationEvent {
  const SyncAppState();
}

/// 缓存清理事件
class ClearCache extends ComponentCommunicationEvent {
  const ClearCache();
}

/// 数据备份事件
class BackupData extends ComponentCommunicationEvent {
  const BackupData();
}

/// 数据恢复事件
class RestoreData extends ComponentCommunicationEvent {
  final String backupPath;

  const RestoreData(this.backupPath);

  @override
  List<Object?> get props => [backupPath];
}

/// ========== 事件优先级定义 ==========

/// 事件优先级枚举
enum EventPriority {
  immediate, // 立即处理（用户交互）
  high, // 高优先级（重要操作）
  normal, // 普通优先级（常规操作）
  low, // 低优先级（后台操作）
  background, // 后台处理（系统维护）
}

/// 事件优先级扩展
extension ComponentCommunicationEventPriority on ComponentCommunicationEvent {
  /// 获取事件优先级
  EventPriority get priority {
    switch (runtimeType) {
      // 立即处理事件
      case ImagePickRequested:
      case VideoPickRequested:
      case ShowConfirmationDialog:
      case ShowErrorMessage:
        return EventPriority.immediate;

      // 高优先级事件
      case SubGoalAddRequested:
      case NavigateToSubGoals:
      case GoalDateUpdateRequested:
      case SearchRequested:
      case NavigateToPage:
        return EventPriority.high;

      // 普通优先级事件
      case ImageUpdated:
      case VideoUpdated:
      case CustomCountdownSetRequested:
      case DeadlineToggleRequested:
      case SyncRequested:
      case ShowAddGoalDialog:
        return EventPriority.normal;

      // 低优先级事件
      case ShowSuccessMessage:
      case NavigateToSettings:
      case NavigateToLogin:
      case LogoutRequested:
        return EventPriority.low;

      // 后台处理事件
      case RefreshGoalTree:
      case SyncAppState:
      case ClearCache:
      case BackupData:
      case RestoreData:
        return EventPriority.background;

      default:
        return EventPriority.normal;
    }
  }

  /// 是否需要用户确认
  bool get requiresConfirmation {
    switch (runtimeType) {
      case LogoutRequested:
      case ClearCache:
      case RestoreData:
        return true;
      default:
        return false;
    }
  }

  /// 是否可以批处理
  bool get canBatch {
    switch (runtimeType) {
      case ImageUpdated:
      case VideoUpdated:
      case RefreshGoalTree:
      case SyncAppState:
        return true;
      default:
        return false;
    }
  }
}
