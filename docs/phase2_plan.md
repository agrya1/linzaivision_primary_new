# 阶段二详细规划：写路径BLoC化（优化版）

## 🎯 总体目标

让所有"写操作"（增/改/删/设置日期/状态切换/显示选项/视图模式）通过 BLoC 事件落地，DB 仅在 Repository 中被调用。UI 不直接触碰 DB。

## 📋 实施策略（基于原始方案优化）

### 核心原则
1. **按风险分批次**：先简单后复杂，从无DB操作到有DB操作
2. **渐进式切换**：每批次完成后运行回归测试，异常时feature toggle回退
3. **UI/DB分离**：UI层不直接调用DatabaseHelper，统一通过BLoC事件
4. **数据一致性**：BLoC完成DB操作后emit新状态，UI随之重绘

### 批次划分逻辑（风险递增）
- **批次1**：显示选项/视图切换（无数据存储/弱数据一致性要求）
- **批次2**：目标选择/编辑态（无DB变更或弱变更）
- **批次3**：日期/状态/目标编辑（增删改）（涉及DB操作）

### 风险控制
- **功能开关**：每个批次都有独立的开关控制
- **兜底机制**：BLoC失败时自动回退到传统模式
- **批次回退**：每批次异常时可回退到上一批次状态
- **单测覆盖**：每个事件补充单测（mock repository）+ 最少量UI集成测试

## 🗂️ 批次化任务分解（基于原始方案优化）

### 批次1：UI状态写操作BLoC化
**目标**：将显示选项切换、视图模式切换等UI状态写操作从setState迁移到BLoC事件
**特点**：无数据库操作，弱数据一致性要求，风险最低
**预估工作量**：2-3小时
**风险等级**：🟢 低

#### 1.1 显示选项切换完全BLoC化
**当前状态**：阶段1已实现BLoC渲染，但写操作仍有setState兜底
**目标**：移除所有showTitle/showDescription/showTime的setState更新

**具体工作**：
- 移除 `_toggleShowTitle`、`_toggleShowDescription`、`_toggleShowTime` 中的setState
- 统一改为发送 `ToggleTitleDisplay`、`ToggleDescriptionDisplay`、`ToggleTimeDisplay` 事件
- 移除本地状态变量 `_showTitle`、`_showDescription`、`_showTime`
- 确保所有UI组件完全依赖BLoC状态

**验证标准**：
- ✅ 显示选项切换立即生效
- ✅ 无setState调用，纯BLoC驱动
- ✅ 状态持久化正常
- ✅ 性能无下降

#### 1.2 视图模式切换完全BLoC化
**当前状态**：视图切换仍使用setState更新currentView
**目标**：移除currentView的setState更新，统一改为BLoC事件

**具体工作**：
- 移除 `_onChangeView` 中的setState调用
- 统一改为发送 `ToggleViewMode` 事件
- 移除本地状态变量 `currentView`
- 确保视图切换完全依赖BLoC状态的viewMode

**验证标准**：
- ✅ 视图切换响应及时
- ✅ 视图状态在页面重建后保持
- ✅ 三个视图（全屏/时间轴/网格）切换正常

#### 1.3 UI状态批次验证
**具体工作**：
- 全面测试批次1的所有功能
- 性能基准测试
- 错误场景测试
- 用户体验验证

### 批次2：编辑状态BLoC化
**目标**：将目标选择、编辑模式切换等编辑状态从setState迁移到BLoC事件
**特点**：涉及少量或无数据库变更，中等风险
**预估工作量**：3-4小时
**风险等级**：🟡 中

#### 2.1 目标选择状态BLoC化
**当前状态**：currentGoal通过setState更新
**目标**：将目标选择逻辑迁移到BLoC事件

**具体工作**：
- 设计 `SelectGoal` 事件
- 移除 `currentGoal` 的setState更新
- 确保目标选择状态在BLoC中管理
- 处理目标切换的导航逻辑

#### 2.2 编辑模式状态BLoC化
**具体工作**：
- 设计 `EnterEditMode`、`ExitEditMode` 事件
- 将标题编辑、描述编辑的模式切换迁移到BLoC
- 处理编辑状态的UI反馈
- 确保编辑模式的状态一致性

#### 2.3 编辑状态批次验证
**具体工作**：
- 验证目标选择和编辑模式功能
- 确保编辑体验无下降
- 测试编辑状态的持久化

### 批次3：数据库写操作BLoC化
**目标**：将所有涉及数据库的写操作迁移到BLoC事件
**特点**：涉及DB操作，最高风险，需要最严格的测试
**预估工作量**：8-12小时
**风险等级**：🔴 高

#### 3.1 目标CRUD操作迁移
**具体工作**：
- 设计 `AddGoal`、`UpdateGoal`、`DeleteGoal` 事件
- 实现事件处理器：Repository调用 + 状态更新
- 移除UI层直接调用DatabaseHelper的路径
- 实现乐观更新和错误回滚机制

**关键事件**：
```dart
class AddGoalWithDetails extends GoalEvent {
  final Goal goal;
  final String? parentId;
  final bool optimistic;
}

class UpdateGoalWithValidation extends GoalEvent {
  final String goalId;
  final Map<String, dynamic> updates;
  final bool optimistic;
}

class DeleteGoalWithCleanup extends GoalEvent {
  final String goalId;
  final bool cascadeDelete;
}
```

#### 3.2 状态变更操作迁移
**具体工作**：
- 设计 `ToggleGoalStatus` 事件
- 处理完成/未完成状态的数据库更新
- 实现状态变更的副作用处理（完成时间记录等）
- 支持批量状态变更

#### 3.3 日期时间操作迁移
**具体工作**：
- 设计 `UpdateGoalDate`、`SetGoalDeadline` 事件
- 处理日期相关的数据库更新
- 实现倒计时配置的持久化
- 处理时区和日期格式问题

#### 3.4 图片更新操作迁移
**具体工作**：
- 设计 `UpdateGoalImage` 事件
- 处理异步文件操作和数据库更新
- 实现图片上传进度和错误处理
- 优化图片缓存和内存管理

#### 3.5 数据库写操作批次验证
**具体工作**：
- 全面的CRUD操作测试
- 数据一致性验证
- 并发操作测试
- 性能和内存测试

## 📊 批次化工作量估算（优化版）

| 批次 | 任务内容 | 预估时间 | 风险等级 | 数据库操作 |
|------|---------|---------|---------|------------|
| **批次1** | UI状态写操作 | 2-3小时 | 🟢 低 | 无 |
| **批次2** | 编辑状态管理 | 3-4小时 | 🟡 中 | 少量 |
| **批次3** | 数据库写操作 | 8-12小时 | 🔴 高 | 大量 |
| **总计** | | **13-19小时** | | |

## 🚀 实施顺序（按风险递增）

### 第一阶段：批次1（最安全）
1. **1.1 显示选项切换完全BLoC化**（1小时）
2. **1.2 视图模式切换完全BLoC化**（1小时）
3. **1.3 UI状态批次验证**（30分钟）

### 第二阶段：批次2（中等风险）
1. **2.1 目标选择状态BLoC化**（1.5小时）
2. **2.2 编辑模式状态BLoC化**（1.5小时）
3. **2.3 编辑状态批次验证**（1小时）

### 第三阶段：批次3（最高风险）
1. **3.1 目标CRUD操作迁移**（4-5小时）
2. **3.2 状态变更操作迁移**（2小时）
3. **3.3 日期时间操作迁移**（2小时）
4. **3.4 图片更新操作迁移**（2-3小时）
5. **3.5 数据库写操作批次验证**（2小时）

## 🔧 技术实施细节

### 批次1：UI状态事件设计
```dart
// 批次1：纯UI状态事件（无DB操作）
class ToggleTitleDisplay extends GoalEvent {
  final bool showTitle;
  const ToggleTitleDisplay(this.showTitle);
}

class ToggleViewMode extends GoalEvent {
  final int viewMode;
  const ToggleViewMode(this.viewMode);
}
```

### 批次2：编辑状态事件设计
```dart
// 批次2：编辑状态事件（轻量DB操作）
class SelectGoal extends GoalEvent {
  final String goalId;
  const SelectGoal(this.goalId);
}

class EnterEditMode extends GoalEvent {
  final String goalId;
  final EditType editType; // title, description, etc.
  const EnterEditMode(this.goalId, this.editType);
}
```

### 批次3：数据库写操作事件设计
```dart
// 批次3：数据库写操作事件（重量级）
abstract class DatabaseWriteEvent extends GoalEvent {
  final bool optimistic;
  const DatabaseWriteEvent({this.optimistic = true});
}

class AddGoalWithDetails extends DatabaseWriteEvent {
  final Goal goal;
  final String? parentId;
  const AddGoalWithDetails(this.goal, {this.parentId, super.optimistic});
}

class UpdateGoalWithValidation extends DatabaseWriteEvent {
  final String goalId;
  final Map<String, dynamic> updates;
  const UpdateGoalWithValidation(this.goalId, this.updates, {super.optimistic});
}

class DeleteGoalWithCleanup extends DatabaseWriteEvent {
  final String goalId;
  final bool cascadeDelete;
  const DeleteGoalWithCleanup(this.goalId, {this.cascadeDelete = true, super.optimistic});
}
```

### 开关配置策略（分批启用）
```dart
// 批次1开关
displayOptionsBlocDriven = true   // 已启用
viewSwitching = true              // 已启用
uiStateWriteThrough = true        // 新增：UI状态写操作BLoC化

// 批次2开关
editStateBlocDriven = true        // 新增：编辑状态BLoC化
goalSelectionBlocDriven = true    // 新增：目标选择BLoC化

// 批次3开关
writeThroughBloc = true           // 数据库写操作BLoC化
goalAdding = true                 // 目标添加BLoC化
goalDeleting = true               // 目标删除BLoC化
statusChanging = true             // 状态变更BLoC化
titleEditing = true               // 标题编辑BLoC化
descriptionEditing = true         // 描述编辑BLoC化
imageUpdating = true              // 图片更新BLoC化
dateUpdating = true               // 日期更新BLoC化
```

## 🛡️ 批次化质量保证

### 批次1验证清单（UI状态）
- [ ] 显示选项切换无setState调用
- [ ] 视图模式切换响应及时
- [ ] UI状态持久化正常
- [ ] 性能无下降

### 批次2验证清单（编辑状态）
- [ ] 目标选择状态一致
- [ ] 编辑模式切换正常
- [ ] 编辑体验无下降
- [ ] 状态在页面重建后保持

### 批次3验证清单（数据库操作）
- [ ] CRUD操作数据一致性
- [ ] 乐观更新和错误回滚
- [ ] 并发操作处理正确
- [ ] 性能和内存表现良好

### 批次回滚策略
每个批次都有独立的回滚能力：
1. **批次1异常**：关闭 `uiStateWriteThrough`，回退到阶段1状态
2. **批次2异常**：关闭 `editStateBlocDriven`，保持批次1成果
3. **批次3异常**：关闭 `writeThroughBloc`，保持批次1+2成果

## 🧪 测试策略（分批次）

### 批次1测试（UI状态）
- **单元测试**：UI状态事件处理逻辑
- **UI测试**：显示选项和视图切换的用户交互
- **性能测试**：UI响应速度基准

### 批次2测试（编辑状态）
- **单元测试**：编辑状态转换逻辑
- **集成测试**：编辑模式的完整流程
- **用户体验测试**：编辑交互的流畅性

### 批次3测试（数据库操作）
- **单元测试**：每个数据库事件的处理（mock repository）
- **集成测试**：端到端的CRUD操作流程
- **数据一致性测试**：并发操作和错误恢复
- **性能测试**：大量数据下的响应速度

## 📈 阶段二成功标准

### 架构目标
1. **UI/DB完全分离**：UI层不直接调用DatabaseHelper
2. **统一事件驱动**：所有写操作都通过BLoC事件
3. **Repository模式**：DB操作仅在Repository中进行
4. **状态权威化**：BLoC成为唯一的状态真相源

### 功能目标
- 所有用户操作响应及时（< 100ms）
- 数据一致性100%保证
- 错误处理完善，用户体验无下降
- 系统稳定性进一步提升

### 技术目标
- setState调用减少90%以上
- 代码复杂度降低，可测试性提升
- 内存使用优化，性能提升
- 架构清晰，易于维护和扩展

## 🚀 立即下一步建议

基于原始方案的智慧和当前阶段一的成功，建议：

### 优先开始批次1（最安全的起点）
**1.1 显示选项切换完全BLoC化**
- 移除 `_toggleShowTitle` 等方法中的setState
- 这是最低风险的写操作迁移
- 成功后可以验证批次化方案的可行性

### 准备工作
1. 添加 `uiStateWriteThrough` 开关到BlocFeatureToggles
2. 准备批次1的测试用例
3. 设计UI状态事件的详细规范

这个优化方案结合了：
- **原始方案的批次智慧**：按风险递增，先简单后复杂
- **我的技术分析**：详细的事件设计和验证标准
- **实际经验教训**：避免破坏现有架构，小步快跑
