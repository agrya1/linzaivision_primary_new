import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/goal_repository.dart';
import '../../models/goal.dart';
import 'goal_event.dart';
import 'goal_state.dart';
import '../transaction/ui_batch_updater.dart';
import '../transaction/i_ui_batch_updater.dart';
import '../../utils/ui_state_performance_monitor.dart';

// BLoC实现
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final GoalRepository repository;
  final bool disableBatching; // 测试/降级用：禁用批处理，直接 emit

  /// 批次3阶段5：GoalBloc emit策略统一说明
  ///
  /// 【emit策略分类】：
  /// 1. 立即emit策略：关键编辑操作（标题/描述/日期/图片）
  ///    - 使用就地更新（map操作修改列表中的特定目标）
  ///    - 立即emit确保UI及时反馈，响应时间<=100ms
  ///    - 适用：SaveTitle、SaveDescription、SaveDate、SaveImage
  ///
  /// 2. 就地更新+必要时RefreshGoalTree策略：CRUD操作
  ///    - 优先使用就地更新避免不必要的数据库查询
  ///    - 仅在影响父子关系时才RefreshGoalTree
  ///    - 适用：ToggleGoalStatus、UpdateGoal、DeleteGoal
  ///
  /// 3. 完整reload策略：批量操作
  ///    - 刻意选择reload确保数据一致性
  ///    - 适用于复杂的批量操作场景
  ///    - 适用：BatchUpdateGoals（标注保留原因）

  // UI批量更新器
  late final IUIBatchUpdater _uiBatchUpdater;

  // 批量更新统计
  int _totalEmits = 0;
  int _batchedEmits = 0;

  GoalBloc({required this.repository, this.disableBatching = false, IUIBatchUpdater? batchUpdater})
      : super(GoalInitial()) {
    // 初始化UI批量更新器
    _uiBatchUpdater = batchUpdater ?? UIBatchUpdater(
      config: UIBatchUpdateConfig.highPerformance(),
    );

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

    // 第二阶段新增：详细编辑事件处理器
    on<UpdateEditingTitle>(_onUpdateEditingTitle);
    on<UpdateEditingDescription>(_onUpdateEditingDescription);
    on<CancelEditing>(_onCancelEditing);
    on<StartEditingDate>(_onStartEditingDate);
    on<UpdateEditingDate>(_onUpdateEditingDate);
    on<SaveDate>(_onSaveDate);
    on<CancelDateEditing>(_onCancelDateEditing);
    on<StartEditingImage>(_onStartEditingImage);
    on<UpdateEditingImage>(_onUpdateEditingImage);
    on<SaveImage>(_onSaveImage);
    on<CancelImageEditing>(_onCancelImageEditing);

    // 增强的目标操作事件处理器
    on<AddGoalWithDetails>(_onAddGoalWithDetails);
    on<UpdateGoalWithValidation>(_onUpdateGoalWithValidation);
    on<DeleteGoalWithCleanup>(_onDeleteGoalWithCleanup);
    on<BatchUpdateGoals>(_onBatchUpdateGoals);
  }

  Future<void> _onLoadGoals(LoadGoals event, Emitter<GoalState> emit) async {
    emit(GoalLoading()); // 加载状态立即发射

    try {
      final goals = await repository.getGoals(parentId: event.parentId);
      final allGoals = await repository.getGoalTree();

      final loadedState = GoalsLoaded(
        goals: goals,
        allGoals: allGoals,
        currentGoal: goals.isNotEmpty ? goals[0] : null,
      );

      // 临时修复：强制使用直接发射模式，绕过批处理问题
      const bool forceDirectEmit = true;
      if (disableBatching || forceDirectEmit) {
        emit(loadedState);
        return;
      }

      // 生产模式：走批处理
      _smartEmit(
          loadedState,
          emit,
          priority: UIUpdatePriority.high); // 初始加载使用高优先级
    } catch (e) {
      emit(GoalError('加载目标失败: $e')); // 错误状态立即发射
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

        // 使用UI批量更新器优化状态发射
        final newState = GoalsLoaded(
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
        );

        // 添加UI更新项到批量更新器
        _uiBatchUpdater.addUpdate(
          UIUpdateItem.goalListUpdate(allGoals, () => emit(newState)),
        );
      } else {
        // 如果没有当前状态，重新加载目标列表
        add(const LoadGoals());
      }
    } catch (e) {
      print('【GoalBloc】添加目标失败: $e');
      emit(GoalError('添加目标失败: $e')); // 错误状态立即发射
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

      // 使用智能批量更新
      _smartEmit(
          GoalsLoaded(
            goals: goals,
            allGoals: allGoals,
            currentGoal: currentGoalExists
                ? currentSelectedGoal
                : (goals.isNotEmpty ? goals[0] : null),
            // 保留其他状态
            viewMode:
                state is GoalsLoaded ? (state as GoalsLoaded).viewMode : 0,
            isEditingTitle: false, // 编辑完成后关闭编辑状态
            isEditingDescription: state is GoalsLoaded
                ? (state as GoalsLoaded).isEditingDescription
                : false,
            showCountdown: state is GoalsLoaded
                ? (state as GoalsLoaded).showCountdown
                : false,
            showTime:
                state is GoalsLoaded ? (state as GoalsLoaded).showTime : true,
            showDescription: state is GoalsLoaded
                ? (state as GoalsLoaded).showDescription
                : true,
            showTitle:
                state is GoalsLoaded ? (state as GoalsLoaded).showTitle : true,
          ),
          emit,
          priority: UIUpdatePriority.high); // 更新操作使用高优先级
      _uiBatchUpdater.flush();
    } catch (e) {
      emit(GoalError('更新目标失败: $e')); // 错误状态立即发射
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

      // 发出新状态（通过批处理并立即flush，确保在handler内发射）
      if (state is GoalsLoaded) {
        final currentState = state as GoalsLoaded;
        _smartEmit(
          GoalsLoaded(
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
          ),
          emit,
          priority: UIUpdatePriority.high,
        );
      } else {
        _smartEmit(
          GoalsLoaded(
            goals: goals,
            allGoals: allGoals,
            currentGoal: newSelectedGoal,
          ),
          emit,
          priority: UIUpdatePriority.high,
        );
      }
      _uiBatchUpdater.flush();
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
      // 目标选择使用立即优先级，确保用户交互响应及时
      _smartEmit(
          currentState.copyWith(
            currentGoal: event.goal,
          ),
          emit,
          priority: UIUpdatePriority.immediate);
      _uiBatchUpdater.flush();
    }
  }

  // 切换视图模式
  void _onToggleViewMode(ToggleViewMode event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      // UI状态切换使用正常优先级，可以批量处理
      _smartEmit(
          currentState.copyWith(
            viewMode: event.viewMode,
          ),
          emit,
          priority: UIUpdatePriority.normal);
      _uiBatchUpdater.flush();
    }
  }

  // 切换倒计时显示
  void _onToggleCountdownDisplay(
      ToggleCountdownDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      // UI状态切换使用正常优先级，可以批量处理
      _smartEmit(
          currentState.copyWith(
            showCountdown: event.showCountdown,
          ),
          emit,
          priority: UIUpdatePriority.normal);
      _uiBatchUpdater.flush();
    }
  }

  // 切换时间显示
  void _onToggleTimeDisplay(ToggleTimeDisplay event, Emitter<GoalState> emit) {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      // UI状态切换使用正常优先级，可以批量处理
      _smartEmit(
          currentState.copyWith(
            showTime: event.showTime,
          ),
          emit,
          priority: UIUpdatePriority.normal);
      _uiBatchUpdater.flush();
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

      // 批次1灰度：性能监控结束
      UIStatePerformanceMonitor.endMeasure('title_toggle');

      // 统一处理：immediate优先级 + 立即flush
      _smartEmit(
          currentState.copyWith(showTitle: event.showTitle),
          emit,
          priority: UIUpdatePriority.immediate);
      _uiBatchUpdater.flush();

      print('【批次1灰度】BLoC处理ToggleTitleDisplay: ${event.showTitle}');
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

  // 保存描述（优化版本：直接状态更新，避免重新加载）
  Future<void> _onSaveDescription(
      SaveDescription event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      final currentGoal = currentState.currentGoal;

      if (currentGoal != null) {
        try {
          // 更新描述
          final updatedGoal = currentGoal.copyWith(
            description: event.description,
          );

          // 保存到数据库
          await repository.updateGoal(updatedGoal);

          // 直接更新状态，避免重新加载导致的UI延迟
          final updatedGoals = currentState.goals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          final updatedAllGoals = currentState.allGoals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          // 立即发出新状态
          emit(currentState.copyWith(
            goals: updatedGoals,
            allGoals: updatedAllGoals,
            currentGoal: updatedGoal,
            isEditingDescription: false, // 编辑完成后关闭编辑状态
            editingDescriptionText: null, // 清空编辑文本
          ));

          print('【批次2优化】描述保存成功，立即更新UI: ${event.description}');
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

  /// 批次3阶段5：切换目标状态
  /// 【emit策略】：就地更新+必要时RefreshGoalTree
  /// - 优先使用就地更新避免不必要的数据库查询
  /// - 状态切换通常不影响父子关系，使用就地更新即可
  /// - 性能目标：<=100ms响应时间
  Future<void> _onToggleGoalStatus(
      ToggleGoalStatus event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;

      try {
        // 批次3阶段5：改为就地更新策略，避免不必要的数据库查询
        final updatedGoal = event.goal.copyWith(
          status: event.completed ? GoalStatus.completed : GoalStatus.pending,
        );

        // 保存到数据库
        await repository.updateGoal(updatedGoal);

        // 就地更新：使用map操作更新列表中的特定目标
        final updatedGoals = currentState.goals.map((goal) {
          return goal.id == updatedGoal.id ? updatedGoal : goal;
        }).toList();

        final updatedAllGoals = currentState.allGoals.map((goal) {
          return goal.id == updatedGoal.id ? updatedGoal : goal;
        }).toList();

        // 更新当前选中的目标（如果是被更新的目标）
        final updatedCurrentGoal = currentState.currentGoal?.id == updatedGoal.id
            ? updatedGoal
            : currentState.currentGoal;

        // 立即emit确保UI及时反馈
        emit(currentState.copyWith(
          goals: updatedGoals,
          allGoals: updatedAllGoals,
          currentGoal: updatedCurrentGoal,
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

  // 第二阶段新增：详细编辑事件处理方法

  Future<void> _onUpdateEditingTitle(
      UpdateEditingTitle event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        editingTitleText: event.title,
        isTitleValid: event.title.trim().isNotEmpty,
        editingError: event.title.trim().isEmpty ? '标题不能为空' : null,
      ));
    }
  }

  Future<void> _onUpdateEditingDescription(
      UpdateEditingDescription event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        editingDescriptionText: event.description,
        isDescriptionValid: true, // 描述可以为空
        editingError: null,
      ));
    }
  }

  Future<void> _onCancelEditing(
      CancelEditing event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingTitle: false,
        isEditingDescription: false,
        isEditingDate: false,
        isEditingImage: false,
        editingTitleText: null,
        editingDescriptionText: null,
        editingDate: null,
        editingImagePath: null,
        editingError: null,
      ));
    }
  }

  Future<void> _onStartEditingDate(
      StartEditingDate event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingDate: true,
        editingDate: currentState.currentGoal?.targetDate ?? DateTime.now(),
      ));
    }
  }

  Future<void> _onUpdateEditingDate(
      UpdateEditingDate event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        editingDate: event.date,
      ));
    }
  }

  /// 批次3阶段5：保存日期
  /// 【emit策略】：立即emit策略
  /// - 使用就地更新（map操作修改列表中的特定目标）
  /// - 立即emit确保UI及时反馈，响应时间<=100ms
  /// - 日期编辑是关键用户交互，需要即时响应
  Future<void> _onSaveDate(SaveDate event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      if (currentState.currentGoal != null &&
          currentState.editingDate != null) {
        try {
          final updatedGoal = currentState.currentGoal!.copyWith(
            targetDate: currentState.editingDate,
          );

          await repository.updateGoal(updatedGoal);

          final updatedGoals = currentState.goals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          final updatedAllGoals = currentState.allGoals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          emit(currentState.copyWith(
            goals: updatedGoals,
            allGoals: updatedAllGoals,
            currentGoal: updatedGoal,
            isEditingDate: false,
            editingDate: null,
          ));
        } catch (e) {
          emit(currentState.copyWith(
            editingError: '保存日期失败: $e',
          ));
        }
      }
    }
  }

  Future<void> _onCancelDateEditing(
      CancelDateEditing event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingDate: false,
        editingDate: null,
        editingError: null,
      ));
    }
  }

  Future<void> _onStartEditingImage(
      StartEditingImage event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingImage: true,
        editingImagePath: currentState.currentGoal?.imagePath,
      ));
    }
  }

  Future<void> _onUpdateEditingImage(
      UpdateEditingImage event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        editingImagePath: event.imagePath,
      ));
    }
  }

  /// 批次3阶段5：保存图片
  /// 【emit策略】：立即emit策略
  /// - 使用就地更新（map操作修改列表中的特定目标）
  /// - 立即emit确保UI及时反馈，响应时间<=100ms
  /// - 图片更新是关键用户交互，需要即时响应
  Future<void> _onSaveImage(SaveImage event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      if (currentState.currentGoal != null) {
        try {
          final updatedGoal = currentState.currentGoal!.copyWith(
            imagePath: currentState.editingImagePath,
          );

          await repository.updateGoal(updatedGoal);

          final updatedGoals = currentState.goals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          final updatedAllGoals = currentState.allGoals.map((goal) {
            return goal.id == updatedGoal.id ? updatedGoal : goal;
          }).toList();

          emit(currentState.copyWith(
            goals: updatedGoals,
            allGoals: updatedAllGoals,
            currentGoal: updatedGoal,
            isEditingImage: false,
            editingImagePath: null,
          ));
        } catch (e) {
          emit(currentState.copyWith(
            editingError: '保存图片失败: $e',
          ));
        }
      }
    }
  }

  Future<void> _onCancelImageEditing(
      CancelImageEditing event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      emit(currentState.copyWith(
        isEditingImage: false,
        editingImagePath: null,
        editingError: null,
      ));
    }
  }

  // 增强的目标操作事件处理方法

  Future<void> _onAddGoalWithDetails(
      AddGoalWithDetails event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      try {
        // 保存到数据库
        final goalId = await repository.insertGoal(event.goal);
        event.goal.id = goalId;

        // 更新目标列表
        List<Goal> updatedGoals;
        if (event.insertIndex != null &&
            event.insertIndex! < currentState.goals.length) {
          updatedGoals = List.from(currentState.goals);
          updatedGoals.insert(event.insertIndex!, event.goal);
        } else {
          updatedGoals = [event.goal, ...currentState.goals];
        }

        // 更新所有目标列表
        final updatedAllGoals = [event.goal, ...currentState.allGoals];

        emit(currentState.copyWith(
          goals: updatedGoals,
          allGoals: updatedAllGoals,
          currentGoal:
              event.setAsCurrent ? event.goal : currentState.currentGoal,
          lastAddedGoal: event.goal,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          editingError: '添加目标失败: $e',
        ));
      }
    }
  }

  Future<void> _onUpdateGoalWithValidation(
      UpdateGoalWithValidation event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      try {
        // 数据验证
        if (event.validateData) {
          if (event.goal.title.trim().isEmpty) {
            emit(currentState.copyWith(
              editingError: '目标标题不能为空',
            ));
            return;
          }
        }

        // 更新数据库
        await repository.updateGoal(event.goal);

        // 更新目标列表
        final updatedGoals = currentState.goals.map((goal) {
          return goal.id == event.goal.id ? event.goal : goal;
        }).toList();

        final updatedAllGoals = currentState.allGoals.map((goal) {
          return goal.id == event.goal.id ? event.goal : goal;
        }).toList();

        // 如果需要更新相关目标（如子目标）
        if (event.updateRelated) {
          // 这里可以添加更新相关目标的逻辑
        }

        emit(currentState.copyWith(
          goals: updatedGoals,
          allGoals: updatedAllGoals,
          currentGoal: currentState.currentGoal?.id == event.goal.id
              ? event.goal
              : currentState.currentGoal,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          editingError: '更新目标失败: $e',
        ));
      }
    }
  }

  Future<void> _onDeleteGoalWithCleanup(
      DeleteGoalWithCleanup event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      try {
        // 如果需要删除子目标
        if (event.deleteSubGoals && event.goal.subGoals.isNotEmpty) {
          for (final subGoal in event.goal.subGoals) {
            await repository.deleteGoal(subGoal.id!);
          }
        }

        // 删除主目标
        await repository.deleteGoal(event.goal.id!);

        // 更新目标列表
        final updatedGoals = currentState.goals
            .where((goal) => goal.id != event.goal.id)
            .toList();

        final updatedAllGoals = currentState.allGoals
            .where((goal) => goal.id != event.goal.id)
            .toList();

        // 更新当前目标
        Goal? newCurrentGoal = currentState.currentGoal;
        if (event.updateCurrent &&
            currentState.currentGoal?.id == event.goal.id) {
          newCurrentGoal = updatedGoals.isNotEmpty ? updatedGoals.first : null;
        }

        emit(currentState.copyWith(
          goals: updatedGoals,
          allGoals: updatedAllGoals,
          currentGoal: newCurrentGoal,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          editingError: '删除目标失败: $e',
        ));
      }
    }
  }

  /// 批次3阶段5：批量更新目标
  /// 【emit策略】：完整reload策略（刻意保留）
  /// 【保留reload的原因】：
  /// 1. 批量操作复杂性：可能涉及多个目标的复杂关系变更
  /// 2. 数据一致性保障：reload确保所有相关数据都是最新状态
  /// 3. 简化错误处理：避免部分成功/部分失败的复杂状态管理
  /// 4. 性能权衡：批量操作频率低，一致性比性能更重要
  Future<void> _onBatchUpdateGoals(
      BatchUpdateGoals event, Emitter<GoalState> emit) async {
    if (state is GoalsLoaded) {
      final currentState = state as GoalsLoaded;
      try {
        // 批量更新目标
        for (final goal in event.goals) {
          await repository.updateGoal(goal);
        }

        // 重新加载目标列表以确保数据一致性
        final goals = await repository.getGoals();
        final allGoals = await repository.getGoalTree();

        emit(currentState.copyWith(
          goals: goals,
          allGoals: allGoals,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          editingError: '批量更新目标失败: $e',
        ));
      }
    }
  }

  /// 智能批量emit - 根据状态类型和优先级选择最佳更新策略
  void _smartEmit(GoalState newState, Emitter<GoalState> emit,
      {UIUpdatePriority priority = UIUpdatePriority.normal}) {
    _totalEmits++;

    // 错误状态和加载状态立即发射
    if (newState is GoalError || newState is GoalLoading) {
      emit(newState);
      return;
    }

    // 根据状态类型选择更新策略
    if (newState is GoalsLoaded) {
      if (disableBatching) {
        emit(newState);
        return;
      }
      final updateType = _determineUpdateType(newState);
      final updatePriority = _determineUpdatePriority(newState, priority);
      _batchedEmits++;
      _uiBatchUpdater.addUpdate(
        _createUIUpdateItem(newState, updateType, updatePriority, emit),
      );
    } else {
      // 其他状态直接发射
      emit(newState);
    }
  }

  /// 确定UI更新类型
  UIUpdateType _determineUpdateType(GoalsLoaded state) {
    final currentState = this.state;
    if (currentState is! GoalsLoaded) {
      return UIUpdateType.goalListUpdate;
    }

    // 比较状态变化类型
    if (currentState.goals.length != state.goals.length ||
        currentState.allGoals.length != state.allGoals.length) {
      return UIUpdateType.goalListUpdate;
    }

    if (currentState.currentGoal?.id != state.currentGoal?.id) {
      return UIUpdateType.goalItemUpdate;
    }

    if (currentState.viewMode != state.viewMode ||
        currentState.showCountdown != state.showCountdown ||
        currentState.showTime != state.showTime ||
        currentState.showDescription != state.showDescription ||
        currentState.showTitle != state.showTitle) {
      return UIUpdateType.navigationUpdate;
    }

    return UIUpdateType.goalItemUpdate;
  }

  /// 确定UI更新优先级
  UIUpdatePriority _determineUpdatePriority(
      GoalsLoaded state, UIUpdatePriority defaultPriority) {
    final currentState = this.state;
    if (currentState is! GoalsLoaded) {
      return UIUpdatePriority.high; // 初始加载高优先级
    }

    // 用户交互相关的更新使用立即优先级
    if (currentState.currentGoal?.id != state.currentGoal?.id) {
      return UIUpdatePriority.immediate;
    }

    // 编辑状态变化使用高优先级
    if (currentState.isEditingTitle != state.isEditingTitle ||
        currentState.isEditingDescription != state.isEditingDescription ||
        currentState.isEditingDate != state.isEditingDate ||
        currentState.isEditingImage != state.isEditingImage) {
      return UIUpdatePriority.high;
    }

    return defaultPriority;
  }

  /// 创建UI更新项
  UIUpdateItem _createUIUpdateItem(GoalsLoaded state, UIUpdateType type,
      UIUpdatePriority priority, Emitter<GoalState> emit) {
    switch (type) {
      case UIUpdateType.goalListUpdate:
        return UIUpdateItem.goalListUpdate(state.allGoals, () {
          if (!emit.isDone) emit(state);
        });

      case UIUpdateType.goalItemUpdate:
        if (state.currentGoal != null) {
          return UIUpdateItem.goalItemUpdate(state.currentGoal!, () {
            if (!emit.isDone) emit(state);
          });
        }
        return UIUpdateItem.goalListUpdate(state.allGoals, () {
          if (!emit.isDone) emit(state);
        });

      case UIUpdateType.statisticsUpdate:
        return UIUpdateItem.statisticsUpdate({
          'goalCount': state.goals.length,
          'allGoalCount': state.allGoals.length,
          'completedCount': state.allGoals
              .where((g) => g.status == GoalStatus.completed)
              .length,
        }, () {
          if (!emit.isDone) emit(state);
        });

      default:
        return UIUpdateItem(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          type: type,
          priority: priority,
          data: {'state': state},
          updateCallback: () {
            if (!emit.isDone) emit(state);
          },
          affectedWidgets: {'goal_page', 'goal_tree'},
        );
    }
  }

  /// 获取批量更新统计
  Map<String, dynamic> getBatchUpdateStats() {
    final stats = _uiBatchUpdater.getStats();
    return {
      'totalEmits': _totalEmits,
      'batchedEmits': _batchedEmits,
      'directEmits': _totalEmits - _batchedEmits,
      'batchEfficiency': _totalEmits > 0 ? _batchedEmits / _totalEmits : 0.0,
      'uiStats': {
        'totalUpdates': stats.totalUpdates,
        'batchedUpdates': stats.batchedUpdates,
        'skippedUpdates': stats.skippedUpdates,
        'batchRate': stats.batchRate,
        'skipRate': stats.skipRate,
        'averageProcessingTime': stats.averageProcessingTime.inMilliseconds,
        'efficiencyLevel': stats.efficiencyLevel,
      },
    };
  }

  @override
  Future<void> close() {
    // 清理UI批量更新器
    _uiBatchUpdater.dispose();
    return super.close();
  }
}
