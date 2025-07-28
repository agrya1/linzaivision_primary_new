# UI组件BLoC化实施计划（简化版）

## 当前架构分析

### 数据流路径
目前的应用采用了混合架构：
1. **传统模式**：UI组件直接调用DatabaseHelper进行CRUD操作
2. **BLoC影子模式**：通过GoalPageBlocAdapter同时执行BLoC操作，但不依赖其结果

### 主要UI组件
1. **FullScreenView**：显示目标详情，支持编辑标题、描述、状态等
2. **TimelineView**：时间轴视图，显示目标列表
3. **GoalGridView**：网格视图，显示目标卡片
4. **GoalTreeView**：导航抽屉中的目标树结构
5. **ExploreView**：探索页面，显示推荐目标

### 已实现的BLoC
1. **GoalBloc**：处理目标CRUD操作
2. **ExploreBloc**：处理探索页面数据
3. **SearchBloc**：处理搜索功能
4. **AuthBloc**：处理认证状态
5. **SettingsBloc**：处理应用设置
6. **ProfileBloc**：处理用户资料

## 简化的BLoC化实施策略

### 1. 页面级BLoC增强

#### 1.1 GoalBloc增强
扩展现有GoalBloc，增加更多状态和事件以支持UI交互：

```dart
// 新增事件
class ToggleViewMode extends GoalEvent {
  final int viewMode; // 0-全屏，1-时间轴，2-网格
  const ToggleViewMode(this.viewMode);
}

class ToggleCountdownDisplay extends GoalEvent {
  final bool showCountdown;
  const ToggleCountdownDisplay(this.showCountdown);
}

class ToggleDescriptionDisplay extends GoalEvent {
  final bool showDescription;
  const ToggleDescriptionDisplay(this.showDescription);
}

class StartEditingTitle extends GoalEvent {}
class SaveTitle extends GoalEvent {
  final String title;
  const SaveTitle(this.title);
}

// 扩展状态
class GoalsLoaded extends GoalState {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  final int viewMode;
  final bool isEditingTitle;
  final bool isEditingDescription;
  final bool showCountdown;
  final bool showTime;
  final bool showDescription;
  
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
  });
  
  // 添加copyWith方法以便于状态更新
  GoalsLoaded copyWith({...}) {
    return GoalsLoaded(...);
  }
}
```

#### 1.2 ExploreBloc增强
扩展ExploreBloc以支持卡片选择和编辑：

```dart
// 新增事件
class SelectCard extends ExploreEvent {
  final ExploreCard card;
  const SelectCard(this.card);
}

class StartUsingCard extends ExploreEvent {
  final ExploreCard card;
  const StartUsingCard(this.card);
}

// 扩展状态
class ExploreLoaded extends ExploreState {
  final List<ExploreCard> cards;
  final ViewMode viewMode;
  final String activeCategory;
  final ExploreCard? selectedCard;
  final bool isEditing;
  
  const ExploreLoaded({
    required this.cards,
    this.viewMode = ViewMode.grid,
    this.activeCategory = '推荐',
    this.selectedCard,
    this.isEditing = false,
  });
}
```

### 2. 跨页面工作流BLoC

新增UseCardBloc处理"立即使用"流程：

```dart
// 事件
abstract class UseCardEvent extends Equatable {}

class StartUseCard extends UseCardEvent {
  final ExploreCard card;
  const StartUseCard(this.card);
}

class EditCardText extends UseCardEvent {
  final String text;
  const EditCardText(this.text);
}

class SelectInsertLocation extends UseCardEvent {
  final Goal targetGoal;
  const SelectInsertLocation(this.targetGoal);
}

class ConfirmCardUse extends UseCardEvent {}
class CancelCardUse extends UseCardEvent {}

// 状态
abstract class UseCardState extends Equatable {}

class UseCardInitial extends UseCardState {}
class EditingCardText extends UseCardState {
  final ExploreCard card;
  final String text;
  
  const EditingCardText({
    required this.card,
    this.text = '',
  });
}

class SelectingInsertLocation extends UseCardState {
  final ExploreCard card;
  final String editedText;
  
  const SelectingInsertLocation({
    required this.card,
    required this.editedText,
  });
}

class CardUseCompleted extends UseCardState {}
```

### 3. 组件改造策略

不再为UI组件创建专门的BLoC，而是：

1. **组件接收必要的数据和回调**：
   ```dart
   class GoalStatusWidget extends StatelessWidget {
     final Goal goal;
     final bool showCountdown;
     final VoidCallback? onToggleCountdown;
     
     const GoalStatusWidget({
       required this.goal,
       this.showCountdown = false,
       this.onToggleCountdown,
     });
     
     @override
     Widget build(BuildContext context) {
       // UI构建逻辑...
     }
   }
   ```

2. **在页面级使用BlocBuilder**：
   ```dart
   BlocBuilder<GoalBloc, GoalState>(
     builder: (context, state) {
       if (state is GoalsLoaded) {
         return GoalStatusWidget(
           goal: state.currentGoal!,
           showCountdown: state.showCountdown,
           onToggleCountdown: () => context.read<GoalBloc>().add(
             ToggleCountdownDisplay(!state.showCountdown)
           ),
         );
       }
       return Container();
     },
   )
   ```

### 4. 实施顺序

1. **第一阶段**：增强GoalBloc
   - 扩展GoalBloc事件和状态
   - 实现新增的事件处理方法
   - 更新GoalRepository以支持新功能

2. **第二阶段**：改造GoalPage
   - 使用BlocBuilder替换setState
   - 将直接数据库操作替换为BLoC事件
   - 保留GoalPageBlocAdapter作为过渡方案

3. **第三阶段**：增强ExploreBloc和实现UseCardBloc
   - 扩展ExploreBloc以支持卡片选择和编辑
   - 实现UseCardBloc处理跨页面工作流
   - 改造ExplorePage使用BLoC

4. **第四阶段**：优化和测试
   - 分析BLoC架构的性能表现
   - 优化事件处理，减少不必要的状态更新
   - 编写单元测试和集成测试

## 优势

1. **简化设计**：避免为每个组件创建专门的BLoC
2. **状态集中管理**：页面级BLoC管理所有相关状态
3. **可测试性**：业务逻辑与UI分离，便于测试
4. **渐进式迁移**：可以逐步替换现有代码，降低风险

## 注意事项

1. **状态设计**：确保状态类设计合理，避免过度复杂
2. **性能考虑**：避免频繁状态更新导致的过度重建
3. **向后兼容**：保持与现有代码的兼容性
4. **测试覆盖**：为BLoC编写完整的单元测试 