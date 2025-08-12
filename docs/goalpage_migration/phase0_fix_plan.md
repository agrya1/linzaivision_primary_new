# GoalPage 阶段0修复实施文档

本文件为阶段0（先修复、再迁移）的实施说明，涵盖变更点、预期结果、验证方法与回滚步骤。已获批准后开始执行，变更均限制在小范围、可回滚。

---

## 1. 目标与范围
- 修复 GoalPage 在混合架构（UI 本地状态 + BLoC 影子同步）下的五类核心功能失效：
  1) 目标编辑（增/改/删）
  2) 日期设置
  3) 显示选项控制（标题/描述/时间/倒计时）
  4) 视图切换（全屏/时间线/网格）
  5) 目标状态管理（完成/进行中/暂停）
- 范围：仅限 lib/pages/goal_page.dart（UI 层）与 lib/utils/bloc_feature_toggles.dart（开关），不变更 GoalBloc/Repository 行为。

---

## 2. 根因与策略
- 根因：UI 直接写 DB 后再次触发 BLoC 写事件（双写），以及本地状态与 BLoC 状态双源不同步；存在重复监听导致副作用。
- 策略：阶段0以“UI→DB 为主、BLoC 只做同步”为准则，避免双写；操作成功后统一使用 LoadGoals/RefreshGoalTree/SelectGoal 同步 BLoC 状态；保留显示/视图 setState 的即时反馈；移除重复监听。

---

## 3. 具体代码变更点

### 3.1 新增 Feature Toggle（写路径保护开关）
文件：lib/utils/bloc_feature_toggles.dart
- 新增字段 + Getter：
  - `_writeThroughBloc`（默认 false）
  - `bool get writeThroughBloc => _writeThroughBloc;`
- setFeatureEnabled 支持 `writeThroughBloc`，持久化键：`bloc_feature_writeThroughBloc`
- loadSettings 时读取 `bloc_feature_writeThroughBloc`
- 目的：阶段0默认关闭 BLoC 写，避免 UI→DB 后的二次写入；后续阶段可开启。

### 3.2 目标新增：避免 UI+Bloc 双写
文件：lib/pages/goal_page.dart
- 位置：`_addNewGoal(Goal goal)`
- 修改：
  - if (writeThroughBloc) 走原 `AddGoalWithDetails`；否则仅触发 `LoadGoals`、`RefreshGoalTree`、`SelectGoal(goal)` 用于只读同步。

### 3.3 目标更新：避免 UI+Bloc 双写
- 位置：`_updateGoal(Goal goal)`（UI 已调用 `_dbHelper.updateGoal`）
- 修改：
  - if (writeThroughBloc) 走 `UpdateGoalWithValidation`；否则触发 `LoadGoals`、`RefreshGoalTree`，如当前目标为该目标则 `SelectGoal(goal)`。

### 3.4 目标删除：避免 UI+Bloc 双写
- 位置：`_deleteGoal(Goal goal)` 与 `_showDeleteGoalDialog(Goal goal)` 的 onConfirm 分支
- 修改：
  - if (writeThroughBloc) 走 `DeleteGoalWithCleanup`；否则触发 `LoadGoals`、`RefreshGoalTree` 并在列表非空时 `SelectGoal(goals.first)`。

### 3.5 移除重复监听器
- 位置：`_buildWithBlocListener` 中重复注册的 `BlocListener<ComponentCommunicationBloc, ComponentCommunicationState>`
- 处理：删除重复监听，保留一个，避免重复副作用。

说明：
- 日期设置场景：
  - Timeline/对话框路径若走 `_updateGoal(updatedGoal)`（UI 写 DB），则已通过 3.3 的修改避免二次写；
  - 仅通过 `UpdateGoal(updatedGoal)` 的路径（无 UI DB 写）保持不变，避免引入回归。
- 显示选项/视图切换：继续保留 setState 即时反馈，同时发送 `ToggleXXXDisplay/ToggleViewMode`，阶段0不改渲染架构，仅保证功能。

---

## 4. 预期结果
- 五类核心功能在混合模式下恢复：
  - 增删改与日期变更不再发生重复写或状态不一致；
  - 显示选项与视图切换即时且一致；
  - currentGoal、goals、allGoals 在操作后与 BLoC 同步一致。

---

## 5. 验证方法

### 5.1 自动化测试（新增建议）
- 新增：`test/integration/goal_page_phase0_fix_test.dart`
- 覆盖要点：
  1) 添加目标：DB 有新目标；`LoadGoals` 同步后 BLoC state 包含；`currentGoal` 指向新目标；
  2) 更新标题/描述/日期：DB 更新；`LoadGoals` 后 BLoC 同步；UI 显示一致；
  3) 删除目标：DB 删除；`LoadGoals` 后 BLoC 同步；若删当前则自动选择第一个或空；
  4) 显示选项：切换后 UI 立即变化；BLoC 状态字段一致；
  5) 视图切换：三视图切换正确，BLoC 的 `viewMode` 改变。

### 5.2 手工测试（脚本补充 manual_functionality_test.md）
- 为上述 5 类功能补充步骤、期望 UI、切视图/返回后仍一致的检查项。

---

## 6. 回滚步骤
- 关闭 `writeThroughBloc`（默认即 false）；
- 若阶段0变更引起异常，revert 对应 commit（仅涉及上述少量点位）；
- 不改动 BLoC/Repository，回滚成本低。

---

## 7. 风险与缓解
- 刷新顺序导致的短暂不一致：统一序列 `LoadGoals → RefreshGoalTree → SelectGoal`；
- 遗漏 SelectGoal：对更新/删除路径补充；
- 副作用重复：已移除重复 BlocListener。

---

## 8. 执行与交付
- 执行顺序：先代码微改 → 运行自动化测试 → 手工脚本回归 → 输出验证报告；
- 通过后进入阶段1（只读改造：BLoC 驱动渲染）。

