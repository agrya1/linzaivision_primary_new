import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/goal_repository.dart';
import '../../models/goal.dart';
import 'goal_event.dart';
import 'goal_state.dart';

// BLoC实现
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final GoalRepository repository;

  GoalBloc({required this.repository}) : super(GoalInitial()) {
    on<LoadGoals>(_onLoadGoals);
    on<AddGoal>(_onAddGoal);
    on<UpdateGoal>(_onUpdateGoal);
    on<DeleteGoal>(_onDeleteGoal);
    on<RefreshGoalTree>(_onRefreshGoalTree);
    on<SelectGoal>(_onSelectGoal);
    on<ToggleViewMode>(_onToggleViewMode);
    on<ToggleCountdownDisplay>(_onToggleCountdownDisplay);
    on<ToggleTimeDisplay>(_onToggleTimeDisplay);
    on<ToggleDescriptionDisplay>(_onToggleDescriptionDisplay);
    on<ToggleTitleDisplay>(_onToggleTitleDisplay);
    on<StartEditingTitle>(_onStartEditingTitle);
    on<SaveTitle>(_onSaveTitle);
    on<StartEditingDescription>(_onStartEditingDescription);
    on<SaveDescription>(_onSaveDescription);
    on<UpdateGoalDate>(_onUpdateGoalDate);
    on<SetCustomCountdown>(_onSetCustomCountdown);
    on<ToggleGoalStatus>(_onToggleGoalStatus);
    on<LoadSpecificGoal>(_onLoadSpecificGoal); // 添加对LoadSpecificGoal事件的处理
    on<SaveInitialGoals>(_onSaveInitialGoals); // 添加对SaveInitialGoals事件的处理
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
      // 确保ID是整数类型
      final int goalId = await repository.insertGoal(event.goal);

      // 显式类型转换，确保正确设置ID
      event.goal.id = goalId;

      print(
          '【GoalBloc】添加目标成功: ID=$goalId, 标题=${event.goal.title}, 父ID=${event.goal.parentId}');

      // 获取当前状态
      List<Goal> currentGoals = [];
      List<Goal> allGoals = [];

      if (state is GoalsLoaded) {
        final currentState = state as GoalsLoaded;
        currentGoals = List.from(currentState.goals);
        allGoals = List.from(currentState.allGoals);

        // 添加新目标到列表
        currentGoals.insert(0, event.goal);

        // 发出新状态，包含新添加的目标
        emit(GoalsLoaded(
          goals: currentGoals,
          allGoals: allGoals,
          currentGoal: event.goal,
          lastAddedGoal: event.goal, // 设置最后添加的目标
          // 保留其他状态
          viewMode: currentState.viewMode,
          isEditingTitle: currentState.isEditingTitle,
          isEditingDescription: currentState.isEditingDescription,
          showCountdown: currentState.showCountdown,
          showTime: currentState.showTime,
          showDescription: currentState.showDescription,
          showTitle: currentState.showTitle,
        ));
      } else {
        // 如果没有当前状态，重新加载目标列表
        add(const LoadGoals());
      }
    } catch (e) {
      print('【GoalBloc】添加目标失败: $e');
      emit(GoalError('添加目标失败: $e'));
    }
  }

  Future<void> _onUpdateGoal(UpdateGoal event, Emitter<GoalState> emit) async {
    try {
      // 保存当前状态，以便稍后恢复当前选中的目标
      Goal? currentSelectedGoal;
      if (state is GoalsLoaded) {
        currentSelectedGoal = (state as GoalsLoaded).currentGoal;
      }

      // 更新目标
      await repository.updateGoal(event.goal);

      // 重新加载目标列表，但保留当前选中的目标
      final goals = await repository.getGoals(parentId: null);
      final allGoals = await repository.getGoalTree();

      // 如果更新的是当前选中的目标，则使用更新后的目标
      if (currentSelectedGoal != null &&
          currentSelectedGoal.id == event.goal.id) {
        currentSelectedGoal = event.goal;
      }

      // 确保当前选中的目标仍然存在于加载的目标中
      bool currentGoalExists =
          goals.any((g) => g.id == currentSelectedGoal?.id);

      // 发出新状态，保留当前选中的目标
      emit(GoalsLoaded(
        goals: goals,
        allGoals: allGoals,
        currentGoal: currentGoalExists
            ? currentSelectedGoal
            : (goals.isNotEmpty ? goals[0] : null),
        // 保留其他状态
        viewMode: state is GoalsLoaded ? (state as GoalsLoaded).viewMode : 0,
        isEditingTitle: false, // 编辑完成后关闭编辑状态
        isEditingDescription: state is GoalsLoaded
            ? (state as GoalsLoaded).isEditingDescription
            : false,
        showCountdown:
            state is GoalsLoaded ? (state as GoalsLoaded).showCountdown : false,
        showTime: state is GoalsLoaded ? (state as GoalsLoaded).showTime : true,
        showDescription: state is GoalsLoaded
            ? (state as GoalsLoaded).showDescription
            : true,
        showTitle:
            state is GoalsLoaded ? (state as GoalsLoaded).showTitle : true,
      ));
    } catch (e) {
      emit(GoalError('更新目标失败: $e'));
    }
  }

  Future<void> _onDeleteGoal(DeleteGoal event, Emitter<GoalState> emit) async {
    try {
      // 保存当前状态，以便稍后恢复当前选中的目标
      Goal? currentSelectedGoal;
      if (state is GoalsLoaded) {
        currentSelectedGoal = (state as GoalsLoaded).currentGoal;
      }

      await repository.deleteGoal(event.goalId);

      // 重新加载目标列表，但尝试保留当前选中的目标
      final goals = await repository.getGoals(parentId: null);
      final allGoals = await repository.getGoalTree();

      // 如果当前选中的目标就是被删除的目标，则需要选择其他目标
      Goal? newSelectedGoal;
      if (currentSelectedGoal != null &&
          currentSelectedGoal.id == event.goalId) {
        // 选择列表中的第一个目标作为新的当前目标
        newSelectedGoal = goals.isNotEmpty ? goals[0] : null;
      } else {
        // 尝试保留当前选中的目标
        bool currentGoalExists =
            goals.any((g) => g.id == currentSelectedGoal?.id);
        newSelectedGoal = currentGoalExists
            ? currentSelectedGoal
            : (goals.isNotEmpty ? goals[0] : null);
      }

      // 发出新状态
      if (state is GoalsLoaded) {
        final currentState = state as GoalsLoaded;
        emit(GoalsLoaded(
          goals: goals,
          allGoals: allGoals,
          currentGoal: newSelectedGoal,
          // 保留其他状态
          viewMode: currentState.viewMode,
          isEditingTitle: false,
          isEditingDescription: currentState.isEditingDescription,
          showCountdown: currentState.showCountdown,
          showTime: currentState.showTime,
          showDescription: currentState.showDescription,
          showTitle: currentState.showTitle,
        ));
      } else {
        emit(GoalsLoaded(
          goals: goals,
          allGoals: allGoals,
          currentGoal: newSelectedGoal,
        ));
      }
    } catch (e) {
      emit(GoalError('删除目标失败: $e'));
    }
  }

  Future<void> _onRefreshGoalTree(
      RefreshGoalTree event, Emitter<GoalState> emit) async {
    try {
      final allGoals = await repository.getGoalTree();

      if (state is GoalsLoaded) {
        final currentState = state as GoalsLoaded;
        emit(currentState.copyWith(
          allGoals: allGoals,
        ));
      }
    } catch (e) {
      emit(GoalError('刷新目标树失败: $e'));
    }
  }

  // 选择目标
  void _onSelectGoal(SelectGoal event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        currentGoal: event.goal,
      ));
    }
  }

  // 切换视图模式
  void _onToggleViewMode(ToggleViewMode event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        viewMode: event.viewMode,
      ));
    }
  }

  // 切换倒计时显示
  void _onToggleCountdownDisplay(
      ToggleCountdownDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        showCountdown: event.showCountdown,
      ));
    }
  }

  // 切换时间显示
  void _onToggleTimeDisplay(ToggleTimeDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        showTime: event.showTime,
      ));
    }
  }

  // 切换描述显示
  void _onToggleDescriptionDisplay(
      ToggleDescriptionDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        showDescription: event.showDescription,
      ));
    }
  }

  // 切换标题显示
  void _onToggleTitleDisplay(
      ToggleTitleDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        showTitle: event.showTitle,
      ));
    }
  }

  // 开始编辑标题
  void _onStartEditingTitle(StartEditingTitle event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingTitle: true,
      ));
    }
  }

  // 保存标题
  Future<void> _onSaveTitle(SaveTitle event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      final currentGoal = currentState.currentGoal;

      if (currentGoal != null) {
        try {
          // 保存当前状态，以便稍后恢复当前选中的目标
          Goal? currentSelectedGoal = currentState.currentGoal;

          // 更新标题
          final updatedGoal = currentGoal.copyWith(
            title: event.title,
          );

          // 保存到数据库
          await repository.updateGoal(updatedGoal);

          // 重新加载目标列表，但保留当前选中的目标
          final goals = await repository.getGoals(parentId: null);
          final allGoals = await repository.getGoalTree();

          // 如果更新的是当前选中的目标，则使用更新后的目标
          if (currentSelectedGoal != null &&
              currentSelectedGoal.id == updatedGoal.id) {
            currentSelectedGoal = updatedGoal;
          }

          // 确保当前选中的目标仍然存在于加载的目标中
          bool currentGoalExists =
              goals.any((g) => g.id == currentSelectedGoal?.id);

          // 发出新状态，保留当前选中的目标
          emit(GoalsLoaded(
            goals: goals,
            allGoals: allGoals,
            currentGoal: currentGoalExists
                ? currentSelectedGoal
                : (goals.isNotEmpty ? goals[0] : null),
            // 保留其他状态
            viewMode: currentState.viewMode,
            isEditingTitle: false, // 编辑完成后关闭编辑状态
            isEditingDescription: currentState.isEditingDescription,
            showCountdown: currentState.showCountdown,
            showTime: currentState.showTime,
            showDescription: currentState.showDescription,
            showTitle: currentState.showTitle,
          ));
        } catch (e) {
          emit(GoalError('保存标题失败: $e'));
          emit(currentState); // 恢复原状态
        }
      }
    }
  }

  // 开始编辑描述
  void _onStartEditingDescription(
      StartEditingDescription event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingDescription: true,
      ));
    }
  }

  // 保存描述
  Future<void> _onSaveDescription(
      SaveDescription event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      final currentGoal = currentState.currentGoal;

      if (currentGoal != null) {
        try {
          // 保存当前状态，以便稍后恢复当前选中的目标
          Goal? currentSelectedGoal = currentState.currentGoal;

          // 更新描述
          final updatedGoal = currentGoal.copyWith(
            description: event.description,
          );

          // 保存到数据库
          await repository.updateGoal(updatedGoal);

          // 重新加载目标列表，但保留当前选中的目标
          final goals = await repository.getGoals(parentId: null);
          final allGoals = await repository.getGoalTree();

          // 如果更新的是当前选中的目标，则使用更新后的目标
          if (currentSelectedGoal != null &&
              currentSelectedGoal.id == updatedGoal.id) {
            currentSelectedGoal = updatedGoal;
          }

          // 确保当前选中的目标仍然存在于加载的目标中
          bool currentGoalExists =
              goals.any((g) => g.id == currentSelectedGoal?.id);

          // 发出新状态，保留当前选中的目标
          emit(GoalsLoaded(
            goals: goals,
            allGoals: allGoals,
            currentGoal: currentGoalExists
                ? currentSelectedGoal
                : (goals.isNotEmpty ? goals[0] : null),
            // 保留其他状态
            viewMode: currentState.viewMode,
            isEditingTitle: currentState.isEditingTitle,
            isEditingDescription: false, // 编辑完成后关闭编辑状态
            showCountdown: currentState.showCountdown,
            showTime: currentState.showTime,
            showDescription: currentState.showDescription,
            showTitle: currentState.showTitle,
          ));
        } catch (e) {
          emit(GoalError('保存描述失败: $e'));
          emit(currentState); // 恢复原状态
        }
      }
    }
  }

  // 更新目标日期
  Future<void> _onUpdateGoalDate(
      UpdateGoalDate event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;

      try {
        // 保存当前状态，以便稍后恢复当前选中的目标
        Goal? currentSelectedGoal = currentState.currentGoal;

        // 更新日期
        final updatedGoal = event.goal.copyWith(
          targetDate: event.date,
        );

        // 保存到数据库
        await repository.updateGoal(updatedGoal);

        // 重新加载目标列表，但保留当前选中的目标
        final goals = await repository.getGoals(parentId: null);
        final allGoals = await repository.getGoalTree();

        // 如果更新的是当前选中的目标，则使用更新后的目标
        if (currentSelectedGoal != null &&
            currentSelectedGoal.id == event.goal.id) {
          currentSelectedGoal = updatedGoal;
        }

        // 确保当前选中的目标仍然存在于加载的目标中
        bool currentGoalExists =
            goals.any((g) => g.id == currentSelectedGoal?.id);

        // 发出新状态，保留当前选中的目标
        emit(GoalsLoaded(
          goals: goals,
          allGoals: allGoals,
          currentGoal: currentGoalExists
              ? currentSelectedGoal
              : (goals.isNotEmpty ? goals[0] : null),
          // 保留其他状态
          viewMode: currentState.viewMode,
          isEditingTitle: currentState.isEditingTitle,
          isEditingDescription: currentState.isEditingDescription,
          showCountdown: currentState.showCountdown,
          showTime: currentState.showTime,
          showDescription: currentState.showDescription,
          showTitle: currentState.showTitle,
        ));
      } catch (e) {
        emit(GoalError('更新目标日期失败: $e'));
        emit(currentState); // 恢复原状态
      }
    }
  }

  // 设置自定义倒计时
  Future<void> _onSetCustomCountdown(
      SetCustomCountdown event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;

      // 简化版本：只发出状态更新，切换倒计时显示
      emit(currentState.copyWith(
        showCountdown: event.days != null,
      ));
    }
  }

  // 切换目标状态
  Future<void> _onToggleGoalStatus(
      ToggleGoalStatus event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;

      try {
        // 保存当前状态，以便稍后恢复当前选中的目标
        Goal? currentSelectedGoal = currentState.currentGoal;

        // 更新状态
        final updatedGoal = event.goal.copyWith(
          status: event.completed ? GoalStatus.completed : GoalStatus.pending,
        );

        // 保存到数据库
        await repository.updateGoal(updatedGoal);

        // 重新加载目标列表，但保留当前选中的目标
        final goals = await repository.getGoals(parentId: null);
        final allGoals = await repository.getGoalTree();

        // 如果更新的是当前选中的目标，则使用更新后的目标
        if (currentSelectedGoal != null &&
            currentSelectedGoal.id == event.goal.id) {
          currentSelectedGoal = updatedGoal;
        }

        // 确保当前选中的目标仍然存在于加载的目标中
        bool currentGoalExists =
            goals.any((g) => g.id == currentSelectedGoal?.id);

        // 发出新状态，保留当前选中的目标
        emit(GoalsLoaded(
          goals: goals,
          allGoals: allGoals,
          currentGoal: currentGoalExists
              ? currentSelectedGoal
              : (goals.isNotEmpty ? goals[0] : null),
          // 保留其他状态
          viewMode: currentState.viewMode,
          isEditingTitle: currentState.isEditingTitle,
          isEditingDescription: currentState.isEditingDescription,
          showCountdown: currentState.showCountdown,
          showTime: currentState.showTime,
          showDescription: currentState.showDescription,
          showTitle: currentState.showTitle,
        ));
      } catch (e) {
        emit(GoalError('切换目标状态失败: $e'));
        emit(currentState); // 恢复原状态
      }
    }
  }

  Future<void> _onLoadSpecificGoal(
      LoadSpecificGoal event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    try {
      // 获取特定目标的ID
      final goalId = event.goalId;

      print('【GoalBloc】开始加载特定目标: $goalId');

      // 直接从数据库加载特定目标
      final goal = await repository.getGoal(goalId);

      if (goal != null) {
        print('【GoalBloc】成功加载特定目标ID: ${goal.id}, 标题: ${goal.title}');

        // 加载完整的目标树以确保有完整的上下文
        final allGoals = await repository.getGoalTree();

        // 确定目标所在的层级
        List<Goal> currentLevelGoals = [];

        if (goal.parentId != null) {
          // 如果是子目标，加载同级目标
          currentLevelGoals =
              await repository.getGoals(parentId: goal.parentId);
          print('【GoalBloc】加载子目标的同级目标: ${currentLevelGoals.length}个');
        } else {
          // 如果是根目标，加载所有根目标
          currentLevelGoals = await repository.getGoals(parentId: null);
          print('【GoalBloc】加载根目标: ${currentLevelGoals.length}个');
        }

        // 确保加载的是正确的目标
        if (goal.id != goalId) {
          print('【GoalBloc】警告：加载的目标ID(${goal.id})与请求的ID($goalId)不匹配');
        }

        emit(GoalsLoaded(
          currentGoal: goal,
          goals: currentLevelGoals,
          allGoals: allGoals,
          viewMode: 0, // 默认全屏视图
          isEditingTitle: false,
          isEditingDescription: false,
          showCountdown: false,
          showTime: true,
          showDescription: true,
          showTitle: true,
        ));
      } else {
        print('【GoalBloc】未找到目标: $goalId');
        emit(GoalError('未找到目标: $goalId'));
      }
    } catch (e) {
      print('【GoalBloc】加载特定目标失败: $e');
      emit(GoalError('加载特定目标失败: $e'));
    }
  }

  Future<void> _onSaveInitialGoals(
      SaveInitialGoals event, Emitter<GoalState> emit) async {
    try {
      // 保存所有目标
      for (final goal in event.goals) {
        final goalId = await repository.insertGoal(goal);
        goal.id = goalId;

        // 保存子目标
        for (final subGoal in goal.subGoals) {
          subGoal.parentId = goalId;
          final subGoalId = await repository.insertGoal(subGoal);
          subGoal.id = subGoalId;
        }
      }

      // 重新加载目标列表
      add(const LoadGoals());
    } catch (e) {
      emit(GoalError('保存初始目标数据失败: $e'));
    }
  }
}
