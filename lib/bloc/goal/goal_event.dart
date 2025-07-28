import 'package:equatable/equatable.dart';
import '../../models/goal.dart';

// 事件定义
abstract class GoalEvent extends Equatable {
  const GoalEvent();

  @override
  List<Object?> get props => [];
}

// 加载目标列表
class LoadGoals extends GoalEvent {
  final int? parentId;
  
  const LoadGoals({this.parentId});
  
  @override
  List<Object?> get props => [parentId];
}

// 添加目标
class AddGoal extends GoalEvent {
  final Goal goal;
  
  const AddGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

// 更新目标
class UpdateGoal extends GoalEvent {
  final Goal goal;
  
  const UpdateGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

// 删除目标
class DeleteGoal extends GoalEvent {
  final int goalId;
  
  const DeleteGoal(this.goalId);
  
  @override
  List<Object?> get props => [goalId];
}

// 刷新目标树
class RefreshGoalTree extends GoalEvent {
  const RefreshGoalTree();
}

// 选择目标
class SelectGoal extends GoalEvent {
  final Goal goal;
  
  const SelectGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

// 切换视图模式
class ToggleViewMode extends GoalEvent {
  final int viewMode; // 0-全屏，1-时间轴，2-网格
  
  const ToggleViewMode(this.viewMode);
  
  @override
  List<Object?> get props => [viewMode];
}

// 切换倒计时显示
class ToggleCountdownDisplay extends GoalEvent {
  final bool showCountdown;
  
  const ToggleCountdownDisplay(this.showCountdown);
  
  @override
  List<Object?> get props => [showCountdown];
}

// 切换时间显示
class ToggleTimeDisplay extends GoalEvent {
  final bool showTime;
  
  const ToggleTimeDisplay(this.showTime);
  
  @override
  List<Object?> get props => [showTime];
}

// 切换描述显示
class ToggleDescriptionDisplay extends GoalEvent {
  final bool showDescription;
  
  const ToggleDescriptionDisplay(this.showDescription);
  
  @override
  List<Object?> get props => [showDescription];
}

// 切换标题显示
class ToggleTitleDisplay extends GoalEvent {
  final bool showTitle;
  
  const ToggleTitleDisplay(this.showTitle);
  
  @override
  List<Object?> get props => [showTitle];
}

// 开始编辑标题
class StartEditingTitle extends GoalEvent {
  const StartEditingTitle();
}

// 保存标题
class SaveTitle extends GoalEvent {
  final String title;
  
  const SaveTitle(this.title);
  
  @override
  List<Object?> get props => [title];
}

// 开始编辑描述
class StartEditingDescription extends GoalEvent {
  const StartEditingDescription();
}

// 保存描述
class SaveDescription extends GoalEvent {
  final String description;
  
  const SaveDescription(this.description);
  
  @override
  List<Object?> get props => [description];
}

// 更新目标日期
class UpdateGoalDate extends GoalEvent {
  final Goal goal;
  final DateTime? date;
  
  const UpdateGoalDate(this.goal, this.date);
  
  @override
  List<Object?> get props => [goal, date];
}

// 设置自定义倒计时
class SetCustomCountdown extends GoalEvent {
  final Goal goal;
  final int? days;
  
  const SetCustomCountdown(this.goal, this.days);
  
  @override
  List<Object?> get props => [goal, days];
}

// 切换目标状态
class ToggleGoalStatus extends GoalEvent {
  final Goal goal;
  final bool completed;
  
  const ToggleGoalStatus(this.goal, this.completed);
  
  @override
  List<Object?> get props => [goal, completed];
} 

/// 加载特定目标事件
class LoadSpecificGoal extends GoalEvent {
  final int goalId;
  
  const LoadSpecificGoal(this.goalId);
  
  @override
  List<Object> get props => [goalId];
} 

/// 保存初始目标事件
class SaveInitialGoals extends GoalEvent {
  final List<Goal> goals;
  
  const SaveInitialGoals(this.goals);
  
  @override
  List<Object> get props => [goals];
} 