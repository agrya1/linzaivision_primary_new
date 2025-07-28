# 临在意识应用组件参数表

本文档详细记录了临在意识应用中各个视图组件的参数需求，为渐进式重构提供参考。

## 1. FullScreenView 组件

### 必需参数
- `currentGoal: Goal?` - 当前选中的目标
- `goals: List<Goal>` - 目标列表
- `isEditingTitle: bool` - 是否正在编辑标题
- `titleController: TextEditingController` - 标题编辑控制器
- `onTitleEdit: VoidCallback` - 标题编辑回调
- `onTitleSave: VoidCallback` - 标题保存回调
- `onDescriptionEdit: VoidCallback` - 描述编辑回调
- `onImagePick: VoidCallback` - 图片选择回调
- `onGoalSelect: Function(Goal)` - 目标选择回调
- `onAddGoal: VoidCallback` - 添加目标回调
- `showTime: bool` - 是否显示时间
- `showDescription: bool` - 是否显示描述
- `showTitle: bool` - 是否显示标题
- `onToggleTitle: VoidCallback` - 切换标题显示回调
- `onAddSubGoal: VoidCallback` - 添加子目标回调

### 可选参数
- `onSaveDescription: Function(Goal, String)?` - 保存描述回调
- `onStatusChange: Function(Goal, bool)?` - 状态更改回调
- `onUpdateDate: Future<bool> Function(Goal, DateTime?)?` - 更新日期回调
- `onToggleDeadline: Function(Goal)?` - 切换截止日期回调
- `onSetCustomCountdown: Function(Goal, int?)?` - 设置自定义倒计时回调
- `hasCustomCountdown: bool` - 是否有自定义倒计时

## 2. TimelineView 组件

### 必需参数
- `goals: List<Goal>` - 目标列表
- `onGoalSelect: Function(Goal)` - 目标选择回调
- `onAddGoal: VoidCallback` - 添加目标回调

### 可选参数
- `onStatusChange: Function(Goal, bool)?` - 状态更改回调
- `onSaveNewGoal: Function(String title, String description, String? imagePath, DateTime? targetDate)?` - 保存新目标回调
- `onUpdateGoalDate: Future<bool> Function(Goal, DateTime?)?` - 更新目标日期回调
- `isSubgoal: bool` - 是否为子目标视图

## 3. GoalGridView 组件

### 必需参数
- `goals: List<Goal>` - 目标列表
- `onGoalSelect: Function(Goal)` - 目标选择回调
- `onAddGoal: VoidCallback` - 添加目标回调

### 可选参数
- `onShowOperationMenu: Function(BuildContext, Goal)?` - 显示操作菜单回调

## 4. GoalTreeView 组件

### 必需参数
- `goals: List<Goal>` - 目标列表
- `onSearchTap: Function()` - 搜索点击回调
- `onSyncTap: Function()` - 同步点击回调
- `membershipStatus: int` - 会员状态
- `onDeleteGoal: GoalDeleteCallback` - 删除目标回调
- `onUpdateGoalStatus: GoalStatusUpdateCallback` - 更新目标状态回调
- `onSettingsTap: VoidCallback` - 设置点击回调
- `onLoginTap: VoidCallback` - 登录点击回调

### 可选参数
- `onGoalSelect: Function(Goal)?` - 目标选择回调
- `isLoggedIn: bool` - 是否已登录
- `userAvatar: String?` - 用户头像URL
- `onLogout: VoidCallback?` - 退出登录回调
- `onExploreTab: VoidCallback?` - 探索页面点击回调

## 5. ExploreView 组件

### 必需参数
- `onSelectCard: Function(Goal)` - 卡片选择回调

## 6. GoalPage 组件

### 主要状态变量
- `goals: List<Goal>` - 当前视图的目标列表
- `allGoals: List<Goal>` - 所有目标的树结构
- `currentView: int` - 当前视图模式（0-全屏，1-时间轴，2-网格，3-树视图，4-探索）
- `currentGoal: Goal?` - 当前选中的目标
- `_isLoading: bool` - 是否正在加载
- `_error: String?` - 错误信息
- `_isEditingTitle: bool` - 是否正在编辑标题
- `_titleController: TextEditingController` - 标题编辑控制器
- `_membershipStatus: int` - 会员状态
- `_showCountdown: bool` - 是否显示倒计时
- `_showTime: bool` - 是否显示时间
- `_showDescription: bool` - 是否显示描述
- `_showTitle: bool` - 是否显示标题

### 主要方法
- `_loadGoals()` - 加载目标数据
- `_saveInitialGoals()` - 保存初始目标数据
- `_refreshGoalTree()` - 刷新目标树
- `_updateGoalTitle()` - 更新目标标题
- `_updateGoalDescription()` - 更新目标描述
- `_updateGoalImage()` - 更新目标图片
- `_addGoal()` - 添加新目标
- `_deleteGoal()` - 删除目标
- `_updateGoalStatus()` - 更新目标状态
- `_updateGoalDate()` - 更新目标日期
- `_addSubGoal()` - 添加子目标
- `_navigateToSubGoals()` - 导航到子目标页面

## 渐进式重构注意事项

1. **保持接口一致性**：在重构过程中，必须确保所有组件的接口保持一致，不能改变参数名称、类型或语义。

2. **参数对应关系**：在使用BLoC状态管理时，需要将原有的回调函数映射到对应的BLoC事件，确保功能等价。

3. **状态映射**：将原有的状态变量映射到BLoC状态中，确保UI渲染结果一致。

4. **渐进式替换**：先保留原有实现，添加新实现并进行并行验证，确认无误后再替换。

5. **组件依赖关系**：注意组件之间的依赖关系，避免循环依赖或不必要的耦合。 