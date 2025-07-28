import 'package:equatable/equatable.dart';
import '../../models/goal.dart';

// 状态定义
abstract class GoalState extends Equatable {
  const GoalState();
  
  @override
  List<Object?> get props => [];
}

// 初始状态
class GoalInitial extends GoalState {}

// 加载中状态
class GoalLoading extends GoalState {}

/// 目标加载完成状态
class GoalsLoaded extends GoalState {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  final Goal? lastAddedGoal; // 最后添加的目标
  final bool isEditingTitle;
  final bool isEditingDescription;
  final int viewMode;
  final bool showCountdown;
  final bool showTime;
  final bool showDescription;
  final bool showTitle;
  
  const GoalsLoaded({
    required this.goals,
    required this.allGoals,
    this.currentGoal,
    this.lastAddedGoal,
    this.isEditingTitle = false,
    this.isEditingDescription = false,
    this.viewMode = 0,
    this.showCountdown = false,
    this.showTime = true,
    this.showDescription = true,
    this.showTitle = true,
  });
  
  @override
  List<Object?> get props => [
    goals, 
    allGoals, 
    currentGoal, 
    lastAddedGoal,
    isEditingTitle, 
    isEditingDescription,
    viewMode,
    showCountdown,
    showTime,
    showDescription,
    showTitle,
  ];
  
  // 复制当前状态并更新部分属性
  GoalsLoaded copyWith({
    List<Goal>? goals,
    List<Goal>? allGoals,
    Goal? currentGoal,
    Goal? lastAddedGoal,
    bool? isEditingTitle,
    bool? isEditingDescription,
    int? viewMode,
    bool? showCountdown,
    bool? showTime,
    bool? showDescription,
    bool? showTitle,
  }) {
    return GoalsLoaded(
      goals: goals ?? this.goals,
      allGoals: allGoals ?? this.allGoals,
      currentGoal: currentGoal ?? this.currentGoal,
      lastAddedGoal: lastAddedGoal ?? this.lastAddedGoal,
      isEditingTitle: isEditingTitle ?? this.isEditingTitle,
      isEditingDescription: isEditingDescription ?? this.isEditingDescription,
      viewMode: viewMode ?? this.viewMode,
      showCountdown: showCountdown ?? this.showCountdown,
      showTime: showTime ?? this.showTime,
      showDescription: showDescription ?? this.showDescription,
      showTitle: showTitle ?? this.showTitle,
    );
  }
}

// 错误状态
class GoalError extends GoalState {
  final String message;
  
  const GoalError(this.message);
  
  @override
  List<Object?> get props => [message];
} 