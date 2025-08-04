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
// 添加目标事件
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

// 第二阶段新增：详细编辑事件

// 更新编辑中的标题文本
class UpdateEditingTitle extends GoalEvent {
  final String title;

  const UpdateEditingTitle(this.title);

  @override
  List<Object?> get props => [title];
}

// 更新编辑中的描述文本
class UpdateEditingDescription extends GoalEvent {
  final String description;

  const UpdateEditingDescription(this.description);

  @override
  List<Object?> get props => [description];
}

// 取消编辑
class CancelEditing extends GoalEvent {
  const CancelEditing();
}

// 开始编辑日期
class StartEditingDate extends GoalEvent {
  const StartEditingDate();
}

// 更新编辑中的日期
class UpdateEditingDate extends GoalEvent {
  final DateTime date;

  const UpdateEditingDate(this.date);

  @override
  List<Object?> get props => [date];
}

// 保存日期
class SaveDate extends GoalEvent {
  const SaveDate();
}

// 取消日期编辑
class CancelDateEditing extends GoalEvent {
  const CancelDateEditing();
}

// 开始编辑图片
class StartEditingImage extends GoalEvent {
  const StartEditingImage();
}

// 更新编辑中的图片
class UpdateEditingImage extends GoalEvent {
  final String imagePath;

  const UpdateEditingImage(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

// 保存图片
class SaveImage extends GoalEvent {
  const SaveImage();
}

// 取消图片编辑
class CancelImageEditing extends GoalEvent {
  const CancelImageEditing();
}

// 增强的目标操作事件

// 带详细信息的新增目标事件
class AddGoalWithDetails extends GoalEvent {
  final Goal goal;
  final bool setAsCurrent;
  final int? insertIndex;

  const AddGoalWithDetails(
    this.goal, {
    this.setAsCurrent = false,
    this.insertIndex,
  });

  @override
  List<Object?> get props => [goal, setAsCurrent, insertIndex];
}

// 带验证的更新目标事件
class UpdateGoalWithValidation extends GoalEvent {
  final Goal goal;
  final bool validateData;
  final bool updateRelated;

  const UpdateGoalWithValidation(
    this.goal, {
    this.validateData = true,
    this.updateRelated = true,
  });

  @override
  List<Object?> get props => [goal, validateData, updateRelated];
}

// 带清理的删除目标事件
class DeleteGoalWithCleanup extends GoalEvent {
  final Goal goal;
  final bool deleteSubGoals;
  final bool updateCurrent;

  const DeleteGoalWithCleanup(
    this.goal, {
    this.deleteSubGoals = false,
    this.updateCurrent = true,
  });

  @override
  List<Object?> get props => [goal, deleteSubGoals, updateCurrent];
}

// 批量更新目标事件
class BatchUpdateGoals extends GoalEvent {
  final List<Goal> goals;
  final String operation;

  const BatchUpdateGoals(this.goals, this.operation);

  @override
  List<Object?> get props => [goals, operation];
}
