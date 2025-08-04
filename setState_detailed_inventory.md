# GoalPage setState调用详细清单

## 分类一：可迁移到GoalBloc的状态管理 (67个)

### 1.1 视图模式切换 (8个)

| 行号 | 代码内容 | 迁移目标 | 优先级 |
|------|----------|----------|--------|
| 135 | `setState(() { currentView = 1; })` | ToggleViewMode事件 | 🔥 高 |
| 1212 | `setState(() { currentView = (currentView + 1) % 3; })` | ToggleViewMode事件 | 🔥 高 |
| 1658 | `setState(() { currentGoal = goal; currentView = 0; })` | SelectGoal + ToggleViewMode | 🔥 高 |
| 1702 | `setState(() { currentGoal = goal; currentView = 0; })` | SelectGoal + ToggleViewMode | 🔥 高 |
| 3005 | `setState(() { currentView = 0; currentGoal = card; })` | ToggleViewMode + SelectGoal | 🔥 高 |
| 3779 | `setState(() { currentGoal = selectedGoal; currentView = 0; })` | SelectGoal + ToggleViewMode | 🔥 高 |
| 3907 | `setState(() { currentGoal = goal; goals = siblingGoals; })` | SelectGoal + LoadGoals | 🔥 高 |
| 1030 | `setState(() { currentView = state.viewMode; })` | BLoC状态同步(将消除) | 🔥 高 |

### 1.2 目标选择和切换 (12个)

| 行号 | 代码内容 | 迁移目标 | 优先级 |
|------|----------|----------|--------|
| 1238 | `setState(() { currentGoal = goal; })` | SelectGoal事件 | 🔥 高 |
| 908 | `setState(() { currentGoal = state.currentGoal; })` | BLoC状态同步(将消除) | 🔥 高 |
| 3032 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3071 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3165 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3181 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3214 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3231 | `setState(() { if (currentGoal?.id == goal.id) currentGoal = updatedGoal; })` | UpdateGoal事件 | 🔥 高 |
| 3511 | `setState(() { final index = goals.indexWhere((g) => g.id == goal.id); })` | UpdateGoal事件 | 🔥 高 |
| 3720 | `setState(() { currentGoal = updatedGoal; _isLoading = false; })` | UpdateGoal事件 | 🔥 高 |
| 3838 | `setState(() { currentGoal = state.currentGoal; goals = state.goals; })` | BLoC状态同步(将消除) | 🔥 高 |
| 990 | `setState(() { currentGoal = updatedGoal; })` | BLoC状态同步(将消除) | 🔥 高 |

### 1.3 编辑状态管理 (15个)

| 行号 | 代码内容 | 迁移目标 | 优先级 |
|------|----------|----------|--------|
| 1287 | `setState(() { _isEditingTitle = true; })` | StartEditingTitle事件 | 🔥 高 |
| 1293 | `setState(() { _isEditingTitle = true; })` | StartEditingTitle事件 | 🔥 高 |
| 1319 | `setState(() { _isEditingTitle = false; })` | SaveTitle事件 | 🔥 高 |
| 1334 | `setState(() { _isEditingTitle = false; })` | SaveTitle事件 | 🔥 高 |
| 1340 | `setState(() { _isEditingTitle = false; })` | CancelEditing事件 | 🔥 高 |
| 890 | `setState(() { _isEditingTitle = state.isEditingTitle; })` | BLoC状态同步(将消除) | 🔥 高 |
| 1231 | `setState(() { _showDescription = !_showDescription; })` | ToggleDescriptionDisplay | 🟡 中 |
| 2477 | `setState(() { goal.status = GoalStatus.pending; })` | ToggleGoalStatus事件 | 🔥 高 |
| 2489 | `setState(() { goal.status = GoalStatus.completed; })` | ToggleGoalStatus事件 | 🔥 高 |
| 2501 | `setState(() { goal.status = GoalStatus.abandoned; })` | ToggleGoalStatus事件 | 🔥 高 |
| 2286 | `setState(() { tempSelectedDate = date; })` | Dialog内部状态(保留) | 🟢 低 |
| 2097 | `setDialogState(() { imagePath = selectedImagePath; })` | Dialog内部状态(保留) | 🟢 低 |

### 1.4 显示选项控制 (16个)

| 行号 | 代码内容 | 迁移目标 | 优先级 |
|------|----------|----------|--------|
| 1128 | `setState(() { _showTitle = !_showTitle; })` | ToggleTitleDisplay事件 | 🟡 中 |
| 1249 | `setState(() { _showTitle = !_showTitle; })` | ToggleTitleDisplay事件 | 🟡 中 |
| 2570 | `setState(() { _showCountdown = !_showCountdown; })` | ToggleCountdownDisplay事件 | 🟡 中 |
| 2797 | `setState(() { _showTime = !_showTime; })` | ToggleTimeDisplay事件 | 🟡 中 |
| 2803 | `setState(() { _showDescription = !_showDescription; })` | ToggleDescriptionDisplay事件 | 🟡 中 |
| 3291 | `setState(() { _showCountdown = !_showCountdown; })` | ToggleCountdownDisplay事件 | 🟡 中 |
| 3307 | `setState(() { _showCountdown = days != null; })` | SetCustomCountdown事件 | 🟡 中 |
| 3544 | `setState(() { _showCountdown = days != null; })` | SetCustomCountdown事件 | 🟡 中 |
| 1005 | `setState(() { _showCountdown = state.showCountdown; })` | BLoC状态同步(将消除) | 🟡 中 |
| 1011 | `setState(() { _showTime = state.showTime; })` | BLoC状态同步(将消除) | 🟡 中 |
| 1017 | `setState(() { _showDescription = state.showDescription; })` | BLoC状态同步(将消除) | 🟡 中 |
| 1023 | `setState(() { _showTitle = state.showTitle; })` | BLoC状态同步(将消除) | 🟡 中 |

### 1.5 目标数据更新 (16个)

| 行号 | 代码内容 | 迁移目标 | 优先级 |
|------|----------|----------|--------|
| 555 | `setState(() { goals.insert(0, goal); currentGoal = goal; })` | AddGoal事件 | 🔥 高 |
| 621 | `setState(() { final index = goals.indexWhere((g) => g.id == goal.id); })` | UpdateGoal事件 | 🔥 高 |
| 661 | `setState(() { goals.remove(goal); })` | DeleteGoal事件 | 🔥 高 |
| 3397 | `setState(() { goals.insert(0, addedGoal); currentGoal = addedGoal; })` | AddGoal事件 | 🔥 高 |
| 3462 | `setState(() { goals.remove(goal); })` | DeleteGoal事件 | 🔥 高 |
| 4045 | `setState(() { goals.removeWhere((g) => g.id == goal.id); })` | DeleteGoal事件 | 🔥 高 |
| 292 | `setState(() { goals = [示例数据]; })` | LoadGoals事件 | 🔥 高 |
| 335 | `setState(() { goals = reloadedGoals; })` | LoadGoals事件 | 🔥 高 |
| 345 | `setState(() { goals = loadedGoals; })` | LoadGoals事件 | 🔥 高 |
| 459 | `setState(() { if (widget.parentGoal == null) goals = topLevelGoals; })` | LoadGoals事件 | 🔥 高 |
| 497 | `setState(() { allGoals = blocAllGoals; })` | BLoC状态同步(将消除) | 🔥 高 |
| 864 | `setState(() { allGoals = state.allGoals; })` | BLoC状态同步(将消除) | 🔥 高 |
| 3579 | `setState(() { allGoals = state.allGoals; })` | BLoC状态同步(将消除) | 🔥 高 |
| 4218 | `setState(() { if (widget.parentGoal == null) goals = topLevelGoals; })` | LoadGoals事件 | 🔥 高 |
| 4258 | `setState(() { allGoals = blocAllGoals; })` | BLoC状态同步(将消除) | 🔥 高 |

## 分类二：需要保留的本地UI状态 (18个)

### 2.1 加载状态指示器 (8个)

| 行号 | 代码内容 | 处理方案 | 优先级 |
|------|----------|----------|--------|
| 279 | `setState(() { _isLoading = true; _error = null; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 447 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 3372 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 3438 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 3564 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 3671 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 3805 | `setState(() { _isLoading = true; _error = null; })` | 可迁移到BLoC LoadingState | 🟡 中 |
| 4026 | `setState(() { _isLoading = true; })` | 可迁移到BLoC LoadingState | 🟡 中 |

### 2.2 错误状态显示 (6个)

| 行号 | 代码内容 | 处理方案 | 优先级 |
|------|----------|----------|--------|
| 365 | `setState(() { _error = '加载数据失败: $e'; _isLoading = false; })` | 可迁移到BLoC ErrorState | 🟡 中 |
| 523 | `setState(() { _error = '加载数据失败: $e'; _isLoading = false; })` | 可迁移到BLoC ErrorState | 🟡 中 |
| 3610 | `setState(() { _error = '刷新目标树失败'; _isLoading = false; })` | 可迁移到BLoC ErrorState | 🟡 中 |
| 3632 | `setState(() { _error = '刷新目标树超时'; _isLoading = false; })` | 可迁移到BLoC ErrorState | 🟡 中 |
| 3651 | `setState(() { _error = '刷新目标树出错'; _isLoading = false; })` | 可迁移到BLoC ErrorState | 🟡 中 |
| 3935 | `setState(() { _isLoading = false; _error = '未找到目标'; })` | 可迁移到BLoC ErrorState | 🟡 中 |

### 2.3 会员状态更新 (2个)

| 行号 | 代码内容 | 处理方案 | 优先级 |
|------|----------|----------|--------|
| 264 | `setState(() { _membershipStatus = memberLevel; })` | 迁移到AuthBloc/ProfileBloc | 🟡 中 |
| 269 | `setState(() { _membershipStatus = 0; })` | 迁移到AuthBloc/ProfileBloc | 🟡 中 |

### 2.4 强制UI刷新 (2个)

| 行号 | 代码内容 | 处理方案 | 优先级 |
|------|----------|----------|--------|
| 2417 | `setState(() {});` | 迁移到BLoC后消除 | 🔥 高 |
| 2911 | `setState(() {});` | 迁移到BLoC后消除 | 🔥 高 |

## 迁移执行顺序建议

### 第一批 (立即执行) - 20个setState
1. 视图模式切换 (8个)
2. 目标选择基础功能 (6个)  
3. 强制UI刷新 (2个)
4. 部分BLoC状态同步 (4个)

### 第二批 (第二周) - 31个setState  
1. 编辑状态管理 (15个)
2. 目标数据更新 (16个)

### 第三批 (第三周) - 16个setState
1. 显示选项控制 (16个)

### 第四批 (第四周) - 26个setState
1. 加载和错误状态 (14个)
2. 会员状态 (2个)
3. 剩余BLoC状态同步 (10个)

## 验证检查清单

### 功能验证
- [ ] 视图切换正常
- [ ] 目标选择响应及时
- [ ] 编辑功能完整
- [ ] 数据保存正确
- [ ] 显示选项生效
- [ ] 错误处理正常

### 性能验证  
- [ ] UI响应时间 < 100ms
- [ ] 内存使用稳定
- [ ] 无不必要的重建
- [ ] 动画流畅

### 架构验证
- [ ] 单向数据流
- [ ] 状态管理集中
- [ ] 无setState残留
- [ ] BLoC事件完整
