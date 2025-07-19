import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/goal.dart';
import '../../repository/goal_repository.dart';

// 事件定义
abstract class GoalEvent extends Equatable {
  const GoalEvent();

  @override
  List<Object?> get props => [];
}

class LoadGoals extends GoalEvent {
  final int? parentId;
  
  const LoadGoals({this.parentId});
  
  @override
  List<Object?> get props => [parentId];
}

class AddGoal extends GoalEvent {
  final Goal goal;
  
  const AddGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

class UpdateGoal extends GoalEvent {
  final Goal goal;
  
  const UpdateGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

class DeleteGoal extends GoalEvent {
  final int goalId;
  
  const DeleteGoal(this.goalId);
  
  @override
  List<Object?> get props => [goalId];
}

class RefreshGoalTree extends GoalEvent {}

// 状态定义
abstract class GoalState extends Equatable {
  const GoalState();
  
  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {}

class GoalLoading extends GoalState {}

class GoalsLoaded extends GoalState {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  
  const GoalsLoaded({
    required this.goals,
    required this.allGoals,
    this.currentGoal,
  });
  
  @override
  List<Object?> get props => [goals, allGoals, currentGoal];
}

class GoalError extends GoalState {
  final String message;
  
  const GoalError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC实现
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final GoalRepository repository;
  
  GoalBloc({required this.repository}) : super(GoalInitial()) {
    on<LoadGoals>(_onLoadGoals);
    on<AddGoal>(_onAddGoal);
    on<UpdateGoal>(_onUpdateGoal);
    on<DeleteGoal>(_onDeleteGoal);
    on<RefreshGoalTree>(_onRefreshGoalTree);
  }
  
  Future<void> _onLoadGoals(LoadGoals event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    try {
      final goals = await repository.getGoals(parentId: event.parentId);
      final allGoals = await repository.getGoalTree();
      
      emit(GoalsLoaded(
        goals: goals,
        allGoals: allGoals,
        currentGoal: goals.isNotEmpty ? goals[0] : null,
      ));
    } catch (e) {
      emit(GoalError('加载目标失败: $e'));
    }
  }
  
  Future<void> _onAddGoal(AddGoal event, Emitter<GoalState> emit) async {
    try {
      final goalId = await repository.insertGoal(event.goal);
      event.goal.id = goalId;
      
      // 重新加载目标列表
      add(const LoadGoals());
    } catch (e) {
      emit(GoalError('添加目标失败: $e'));
    }
  }
  
  Future<void> _onUpdateGoal(UpdateGoal event, Emitter<GoalState> emit) async {
    try {
      await repository.updateGoal(event.goal);
      
      // 重新加载目标列表
      add(const LoadGoals());
    } catch (e) {
      emit(GoalError('更新目标失败: $e'));
    }
  }
  
  Future<void> _onDeleteGoal(DeleteGoal event, Emitter<GoalState> emit) async {
    try {
      await repository.deleteGoal(event.goalId);
      
      // 重新加载目标列表
      add(const LoadGoals());
    } catch (e) {
      emit(GoalError('删除目标失败: $e'));
    }
  }
  
  Future<void> _onRefreshGoalTree(RefreshGoalTree event, Emitter<GoalState> emit) async {
    try {
      final allGoals = await repository.getGoalTree();
      
      if (state is GoalsLoaded) {
        final currentState = state as GoalsLoaded;
        emit(GoalsLoaded(
          goals: currentState.goals,
          allGoals: allGoals,
          currentGoal: currentState.currentGoal,
        ));
      }
    } catch (e) {
      emit(GoalError('刷新目标树失败: $e'));
    }
  }
} 