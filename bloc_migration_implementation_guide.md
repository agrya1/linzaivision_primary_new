# BLoC迁移技术实施指南

## 第一阶段实施：视图切换和目标选择迁移

### 步骤1：扩展GoalState

首先需要扩展现有的GoalState，添加UI相关的状态字段：

```dart
// lib/bloc/goal/goal_state.dart
class GoalsLoaded extends GoalState {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  
  // 新增UI状态字段
  final int viewMode; // 0-全屏，1-时间轴，2-网格，3-目标树，4-探索
  final bool isEditingTitle;
  final bool isEditingDescription;
  final bool showCountdown;
  final bool showTime;
  final bool showDescription;
  final bool showTitle;
  
  const GoalsLoaded({
    required this.goals,
    required this.allGoals,
    this.currentGoal,
    this.viewMode = 0,
    this.isEditingTitle = false,
    this.isEditingDescription = false,
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
    viewMode,
    isEditingTitle,
    isEditingDescription,
    showCountdown,
    showTime,
    showDescription,
    showTitle,
  ];

  GoalsLoaded copyWith({
    List<Goal>? goals,
    List<Goal>? allGoals,
    Goal? currentGoal,
    int? viewMode,
    bool? isEditingTitle,
    bool? isEditingDescription,
    bool? showCountdown,
    bool? showTime,
    bool? showDescription,
    bool? showTitle,
  }) {
    return GoalsLoaded(
      goals: goals ?? this.goals,
      allGoals: allGoals ?? this.allGoals,
      currentGoal: currentGoal ?? this.currentGoal,
      viewMode: viewMode ?? this.viewMode,
      isEditingTitle: isEditingTitle ?? this.isEditingTitle,
      isEditingDescription: isEditingDescription ?? this.isEditingDescription,
      showCountdown: showCountdown ?? this.showCountdown,
      showTime: showTime ?? this.showTime,
      showDescription: showDescription ?? this.showDescription,
      showTitle: showTitle ?? this.showTitle,
    );
  }
}
```

### 步骤2：添加新的GoalEvent

```dart
// lib/bloc/goal/goal_event.dart - 添加以下事件

// 视图切换事件
class ToggleViewMode extends GoalEvent {
  final int viewMode;
  
  const ToggleViewMode(this.viewMode);
  
  @override
  List<Object?> get props => [viewMode];
}

// 目标选择事件
class SelectGoal extends GoalEvent {
  final Goal goal;
  
  const SelectGoal(this.goal);
  
  @override
  List<Object?> get props => [goal];
}

// 编辑状态事件
class StartEditingTitle extends GoalEvent {
  const StartEditingTitle();
}

class SaveTitle extends GoalEvent {
  final String title;
  
  const SaveTitle(this.title);
  
  @override
  List<Object?> get props => [title];
}

class CancelEditing extends GoalEvent {
  const CancelEditing();
}

// 显示选项事件
class ToggleCountdownDisplay extends GoalEvent {
  final bool showCountdown;
  
  const ToggleCountdownDisplay(this.showCountdown);
  
  @override
  List<Object?> get props => [showCountdown];
}

class ToggleTimeDisplay extends GoalEvent {
  final bool showTime;
  
  const ToggleTimeDisplay(this.showTime);
  
  @override
  List<Object?> get props => [showTime];
}

class ToggleDescriptionDisplay extends GoalEvent {
  final bool showDescription;
  
  const ToggleDescriptionDisplay(this.showDescription);
  
  @override
  List<Object?> get props => [showDescription];
}

class ToggleTitleDisplay extends GoalEvent {
  final bool showTitle;
  
  const ToggleTitleDisplay(this.showTitle);
  
  @override
  List<Object?> get props => [showTitle];
}
```

### 步骤3：扩展GoalBloc事件处理

```dart
// lib/bloc/goal/goal_bloc.dart - 在构造函数中添加事件处理器

GoalBloc({required this.repository}) : super(GoalInitial()) {
  // 现有事件处理器
  on<LoadGoals>(_onLoadGoals);
  on<AddGoal>(_onAddGoal);
  on<UpdateGoal>(_onUpdateGoal);
  on<DeleteGoal>(_onDeleteGoal);
  
  // 新增事件处理器
  on<ToggleViewMode>(_onToggleViewMode);
  on<SelectGoal>(_onSelectGoal);
  on<StartEditingTitle>(_onStartEditingTitle);
  on<SaveTitle>(_onSaveTitle);
  on<CancelEditing>(_onCancelEditing);
  on<ToggleCountdownDisplay>(_onToggleCountdownDisplay);
  on<ToggleTimeDisplay>(_onToggleTimeDisplay);
  on<ToggleDescriptionDisplay>(_onToggleDescriptionDisplay);
  on<ToggleTitleDisplay>(_onToggleTitleDisplay);
}

// 实现事件处理方法
Future<void> _onToggleViewMode(ToggleViewMode event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    emit(currentState.copyWith(viewMode: event.viewMode));
  }
}

Future<void> _onSelectGoal(SelectGoal event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    emit(currentState.copyWith(currentGoal: event.goal));
  }
}

Future<void> _onStartEditingTitle(StartEditingTitle event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    emit(currentState.copyWith(isEditingTitle: true));
  }
}

Future<void> _onSaveTitle(SaveTitle event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    
    if (currentState.currentGoal != null) {
      try {
        // 更新目标标题
        final updatedGoal = currentState.currentGoal!.copyWith(title: event.title);
        await repository.updateGoal(updatedGoal);
        
        // 更新状态
        final updatedGoals = currentState.goals.map((goal) {
          return goal.id == updatedGoal.id ? updatedGoal : goal;
        }).toList();
        
        emit(currentState.copyWith(
          goals: updatedGoals,
          currentGoal: updatedGoal,
          isEditingTitle: false,
        ));
      } catch (e) {
        emit(GoalError('保存标题失败: $e'));
      }
    }
  }
}

Future<void> _onCancelEditing(CancelEditing event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    emit(currentState.copyWith(
      isEditingTitle: false,
      isEditingDescription: false,
    ));
  }
}

Future<void> _onToggleCountdownDisplay(ToggleCountdownDisplay event, Emitter<GoalState> emit) async {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;
    emit(currentState.copyWith(showCountdown: event.showCountdown));
  }
}

// 类似地实现其他显示选项的事件处理器...
```

### 步骤4：重构GoalPage的build方法

```dart
// lib/pages/goal_page.dart - 重构build方法

@override
Widget build(BuildContext context) {
  return BlocBuilder<GoalBloc, GoalState>(
    builder: (context, state) {
      if (state is GoalLoading) {
        return _buildLoadingView();
      } else if (state is GoalError) {
        return _buildErrorView(state.message);
      } else if (state is GoalsLoaded) {
        return _buildMainContent(state);
      }
      
      return _buildInitialView();
    },
  );
}

Widget _buildMainContent(GoalsLoaded state) {
  return Scaffold(
    appBar: _buildAppBar(state),
    body: _buildCurrentView(state),
    floatingActionButton: _buildFloatingActionButton(state),
    drawer: _buildDrawer(state),
  );
}

Widget _buildCurrentView(GoalsLoaded state) {
  switch (state.viewMode) {
    case 0:
      return FullScreenView(
        goals: state.goals,
        currentGoal: state.currentGoal,
        onGoalChanged: (goal) {
          context.read<GoalBloc>().add(SelectGoal(goal));
        },
        showCountdown: state.showCountdown,
        showTime: state.showTime,
        showDescription: state.showDescription,
        showTitle: state.showTitle,
        isEditingTitle: state.isEditingTitle,
        onTitleEdit: () {
          context.read<GoalBloc>().add(const StartEditingTitle());
        },
        onTitleSave: (title) {
          context.read<GoalBloc>().add(SaveTitle(title));
        },
        onTitleCancel: () {
          context.read<GoalBloc>().add(const CancelEditing());
        },
      );
    case 1:
      return TimelineView(
        goals: state.goals,
        currentGoal: state.currentGoal,
        onGoalSelect: (goal) {
          context.read<GoalBloc>().add(SelectGoal(goal));
        },
        showCountdown: state.showCountdown,
        showTime: state.showTime,
        showDescription: state.showDescription,
        showTitle: state.showTitle,
      );
    case 2:
      return GridView(
        goals: state.goals,
        currentGoal: state.currentGoal,
        onGoalChanged: (goal) {
          context.read<GoalBloc>().add(SelectGoal(goal));
        },
        showCountdown: state.showCountdown,
        showTime: state.showTime,
        showDescription: state.showDescription,
        showTitle: state.showTitle,
      );
    case 3:
      return GoalTreeView(
        allGoals: state.allGoals,
        currentGoal: state.currentGoal,
        onGoalChanged: (goal) {
          context.read<GoalBloc>().add(SelectGoal(goal));
        },
        showCountdown: state.showCountdown,
        showTime: state.showTime,
        showDescription: state.showDescription,
        showTitle: state.showTitle,
      );
    case 4:
      return ExploreView(
        onCardUsed: (card) {
          context.read<GoalBloc>().add(SelectGoal(card));
          context.read<GoalBloc>().add(const ToggleViewMode(0));
        },
      );
    default:
      return const Center(
        child: Text('未知视图模式'),
      );
  }
}
```

### 步骤5：移除本地状态变量

```dart
// lib/pages/goal_page.dart - 移除以下本地状态变量

class GoalPageState extends State<GoalPage> {
  // 保留必要的变量
  late List<Goal> goals; // 临时保留，后续也会迁移
  List<Goal> allGoals = []; // 临时保留，后续也会迁移
  
  // 移除以下变量，改为从BLoC状态获取
  // int currentView = 0; // 移除
  // Goal? currentGoal; // 移除
  // bool _isEditingTitle = false; // 移除
  // bool _showCountdown = false; // 移除
  // bool _showTime = true; // 移除
  // bool _showDescription = true; // 移除
  // bool _showTitle = true; // 移除
  
  // 保留的变量
  bool _isLoading = true; // 后续迁移
  String? _error; // 后续迁移
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _titleController = TextEditingController();
  int _membershipStatus = 0; // 后续迁移到AuthBloc
  
  // ... 其他代码
}
```

### 步骤6：更新事件触发点

```dart
// 将原来的setState调用替换为BLoC事件

// 原来的代码：
// setState(() {
//   currentView = (currentView + 1) % 3;
// });

// 新的代码：
void _onChangeView() {
  final currentState = context.read<GoalBloc>().state;
  if (currentState is GoalsLoaded) {
    final nextView = (currentState.viewMode + 1) % 3;
    context.read<GoalBloc>().add(ToggleViewMode(nextView));
  }
}

// 原来的代码：
// setState(() {
//   currentGoal = goal;
// });

// 新的代码：
void _onGoalSelect(Goal goal) {
  context.read<GoalBloc>().add(SelectGoal(goal));
}

// 原来的代码：
// setState(() {
//   _showCountdown = !_showCountdown;
// });

// 新的代码：
void _toggleCountdown() {
  final currentState = context.read<GoalBloc>().state;
  if (currentState is GoalsLoaded) {
    context.read<GoalBloc>().add(ToggleCountdownDisplay(!currentState.showCountdown));
  }
}
```

## 验证和测试

### 功能验证清单
1. **视图切换**
   - [ ] 点击视图切换按钮正常工作
   - [ ] 视图状态正确保存
   - [ ] 子目标页面强制显示时间轴视图

2. **目标选择**
   - [ ] 点击目标能正确选中
   - [ ] 选中状态正确显示
   - [ ] 选中目标数据正确传递

3. **编辑功能**
   - [ ] 点击标题进入编辑模式
   - [ ] 保存标题正确更新数据
   - [ ] 取消编辑恢复原状态

4. **显示选项**
   - [ ] 倒计时显示开关正常
   - [ ] 时间显示开关正常
   - [ ] 描述显示开关正常
   - [ ] 标题显示开关正常

### 性能验证
1. **响应时间**: UI操作响应时间应 < 100ms
2. **内存使用**: 无明显内存泄漏
3. **重建次数**: 使用Flutter Inspector检查不必要的重建

### 回退策略
1. 保留功能开关，可随时切换回原有实现
2. 使用Git分支管理，确保可以快速回退
3. 分阶段发布，先在开发环境验证

## 下一步计划

完成第一阶段后，继续执行：
1. 第二阶段：编辑状态和数据更新迁移
2. 第三阶段：显示选项和偏好设置迁移  
3. 第四阶段：清理和优化

每个阶段都要进行充分的测试和验证，确保功能完整性和性能指标达标。
