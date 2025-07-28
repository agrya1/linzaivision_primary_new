# UI BLoC化实施进度报告

## 已完成工作

### 1. 页面级BLoC增强

#### 1.1 GoalBloc增强
已完成GoalBloc的增强，添加了以下功能：

**新增事件**：
- `SelectGoal`：选择目标
- `ToggleViewMode`：切换视图模式
- `ToggleCountdownDisplay`：切换倒计时显示
- `ToggleTimeDisplay`：切换时间显示
- `ToggleDescriptionDisplay`：切换描述显示
- `ToggleTitleDisplay`：切换标题显示
- `StartEditingTitle`：开始编辑标题
- `SaveTitle`：保存标题
- `StartEditingDescription`：开始编辑描述
- `SaveDescription`：保存描述
- `UpdateGoalDate`：更新目标日期
- `SetCustomCountdown`：设置自定义倒计时
- `ToggleGoalStatus`：切换目标状态

**扩展状态**：
- `GoalsLoaded`：添加了UI相关的状态字段，如`viewMode`、`isEditingTitle`等
- 添加了`copyWith`方法，便于状态更新

#### 1.2 ExploreBloc增强
已完成ExploreBloc的增强，添加了以下功能：

**新增事件**：
- `SelectCard`：选择卡片
- `StartUsingCard`：开始使用卡片
- `ChangeCategory`：切换分类

**扩展状态**：
- `ExploreLoaded`：添加了`activeCategory`、`selectedCard`等字段
- `CardBeingEdited`：添加了`editedText`字段
- 添加了`copyWith`方法，便于状态更新

### 2. 跨页面工作流BLoC

#### 2.1 UseCardBloc
已实现UseCardBloc，用于管理跨页面的卡片使用流程：

**事件**：
- `StartUseCard`：开始使用卡片
- `EditCardText`：编辑卡片文本
- `SelectInsertLocation`：选择插入位置
- `ConfirmCardUse`：确认使用卡片
- `CancelCardUse`：取消使用卡片

**状态**：
- `EditingCardText`：编辑卡片文本状态
- `SelectingInsertLocation`：选择插入位置状态
- `CardUseCompleted`：卡片使用完成状态

### 3. BLoC适配器实现

#### 3.1 GoalPageBlocAdapter
已在GoalPage中集成GoalPageBlocAdapter，实现影子模式：

**主要功能**：
- 初始化适配器，默认为影子模式（不执行BLoC操作）
- 在`_loadGoals`方法中并行执行BLoC操作
- 在`_addNewGoal`、`_updateGoal`、`_deleteGoal`等方法中添加影子模式支持
- 添加`_addNewGoalWithBloc`、`_updateGoalWithBloc`等测试方法
- 在`dispose`方法中输出性能统计信息

#### 3.2 ExplorePageBlocAdapter
已创建并集成ExplorePageBlocAdapter，实现影子模式：

**主要功能**：
- 初始化适配器，默认为影子模式
- 在`initState`中添加卡片加载的影子模式支持
- 在`_toggleViewMode`方法中添加视图模式切换的影子模式支持
- 在`_onCardTap`方法中添加卡片选择的影子模式支持
- 在`dispose`方法中输出性能统计信息

## 下一步计划

### 1. GoalPage改造
计划改造GoalPage，使其使用增强后的GoalBloc：
- 使用BlocBuilder替换setState
- 将直接数据库操作替换为BLoC事件
- 保留GoalPageBlocAdapter作为过渡方案

### 2. ExplorePage改造
计划改造ExplorePage，使其使用增强后的ExploreBloc和UseCardBloc：
- 使用BlocBuilder替换setState
- 实现卡片选择和使用功能
- 集成UseCardBloc处理跨页面工作流

### 3. 组件适配
计划适配现有UI组件，使其接收必要的数据和回调：
- 修改FullScreenView，接收GoalBloc的状态和事件回调
- 修改TimelineView，接收GoalBloc的状态和事件回调
- 修改GoalGridView，接收GoalBloc的状态和事件回调

### 4. 测试和优化
- 测试BLoC架构的性能表现
- 优化事件处理，减少不必要的状态更新
- 编写单元测试和集成测试

## 实施策略

1. **渐进式改造**：
   - 先改造核心页面，再逐步扩展到其他页面
   - 保留向后兼容性，确保现有功能不受影响
   - 使用适配器模式过渡，逐步替换现有代码

2. **组件设计原则**：
   - 组件接收必要的数据和回调，不持有状态
   - 使用BlocBuilder在页面级别响应状态变化
   - 避免组件级BLoC，保持架构简洁 