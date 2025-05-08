import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';

/// 定义删除回调
typedef GoalDeleteCallback = void Function(Goal goal);

/// 定义状态更新回调
typedef GoalStatusUpdateCallback = void Function(
    Goal goal, GoalStatus newStatus);

class GoalTreeView extends StatefulWidget {
  final List<Goal> goals;
  final Function() onSearchTap;
  final Function() onSyncTap;
  final int membershipStatus;
  final GoalDeleteCallback onDeleteGoal;
  final GoalStatusUpdateCallback onUpdateGoalStatus;
  final Function(Goal)? onGoalSelect;
  final bool isLoggedIn; // 是否已登录
  final String? userAvatar; // 用户头像URL
  final VoidCallback onSettingsTap; // 设置页面点击回调
  final VoidCallback onLoginTap; // 登录页面点击回调
  final VoidCallback? onLogout; // 退出登录回调

  const GoalTreeView({
    super.key,
    required this.goals,
    required this.onSearchTap,
    required this.onSyncTap,
    required this.membershipStatus,
    required this.onDeleteGoal,
    required this.onUpdateGoalStatus,
    this.onGoalSelect,
    this.isLoggedIn = false,
    this.userAvatar,
    required this.onSettingsTap,
    required this.onLoginTap,
    this.onLogout,
  });

  @override
  State<GoalTreeView> createState() => _GoalTreeViewState();
}

class _GoalTreeViewState extends State<GoalTreeView> {
  // 使用 Map 来存储每个 Goal 的展开状态，key 为 goal.id
  final Map<int?, bool> _expansionState = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 抽屉头部 - 添加透明度
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.9),
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    '心愿池',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 搜索栏
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onSearchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '搜索心愿',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 目标列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              _buildGoalTree(widget.goals, 0),
            ],
          ),
        ),
        // 用户信息与设置区域
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey[200]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 用户头像 - 添加点击效果
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(21), // 与头像半径一致
                  onTap: widget.isLoggedIn
                      ? widget.onSettingsTap
                      : widget.onLoginTap,
                  child: Stack(
                    children: [
                      // 头像
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          image: widget.isLoggedIn && widget.userAvatar != null
                              ? DecorationImage(
                                  image: NetworkImage(widget.userAvatar!),
                                  fit: BoxFit.cover,
                                )
                              : const DecorationImage(
                                  image: AssetImage(
                                      'assets/images/default_avatar.png'),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // VIP标志
                      if (widget.isLoggedIn && widget.membershipStatus >= 2)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.amber[700],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 用户状态文本 - 添加点击效果
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.isLoggedIn
                        ? widget.onSettingsTap
                        : widget.onLoginTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isLoggedIn ? '已登录' : '未登录',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.normal,
                                    ),
                          ),
                          if (widget.isLoggedIn)
                            Text(
                              widget.membershipStatus >= 2 ? 'Pro 会员' : '普通用户',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 退出登录按钮（仅在登录状态显示）
              if (widget.isLoggedIn && widget.onLogout != null)
                TextButton(
                  onPressed: widget.onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      const Text('退出'),
                    ],
                  ),
                ),
              // 未登录状态下的设置图标
              if (!widget.isLoggedIn)
                IconButton(
                  onPressed: widget.onSettingsTap,
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                  tooltip: '设置',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalTree(List<Goal> goals, int level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: goals.map((goal) {
        bool hasSubGoals = goal.subGoals.isNotEmpty;
        // 获取当前节点的展开状态，默认为 false (不展开)
        bool isExpanded = _expansionState[goal.id] ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用 Slidable 包裹
            Slidable(
              key: ValueKey(goal.id), // 保证 key 唯一
              // 右滑时出现的操作面板
              endActionPane: ActionPane(
                motion: const StretchMotion(), // 滑动动画
                extentRatio: 0.6, // 操作面板宽度占节点宽度的比例
                children: [
                  // 完成按钮
                  SlidableAction(
                    onPressed: (context) {
                      widget.onUpdateGoalStatus(goal, GoalStatus.completed);
                    },
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.check_circle_outline,
                    label: '完成',
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  // 中止按钮
                  SlidableAction(
                    onPressed: (context) {
                      widget.onUpdateGoalStatus(goal, GoalStatus.abandoned);
                    },
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    icon: Icons.cancel_outlined,
                    label: '中止',
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  // 删除按钮
                  SlidableAction(
                    onPressed: (context) {
                      // 可以加一个确认弹窗
                      showDialog(
                        context: context,
                        builder: (BuildContext ctx) {
                          return AlertDialog(
                            title: const Text('确认删除'),
                            content: Text('确定要删除目标 "${goal.title}" 及其所有子目标吗？'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('取消'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                },
                              ),
                              TextButton(
                                child: const Text('删除',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  widget.onDeleteGoal(goal);
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline,
                    label: '删除',
                    padding: EdgeInsets.zero,
                    // 设置右侧圆角以匹配抽屉边缘
                    borderRadius: level == 0
                        ? const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12))
                        : BorderRadius.zero,
                  ),
                ],
              ),
              // 实际显示内容
              child: InkWell(
                onTap: () {
                  if (widget.onGoalSelect != null) {
                    widget.onGoalSelect!(goal);
                  }
                },
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16.0 + (24.0 * level), // 增加缩进
                    right: 8.0,
                    top: 12.0,
                    bottom: 12.0,
                  ),
                  child: Row(
                    children: [
                      // 移除 Checkbox
                      // 目标标题
                      Expanded(
                        child: Text(
                          goal.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: goal.status == GoalStatus.abandoned
                                    ? Colors.grey[500]
                                    : goal.status == GoalStatus.completed
                                        ? Colors.grey
                                        : Colors.black,
                                decoration: goal.status == GoalStatus.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.grey, // 删除线颜色
                              ),
                          overflow: TextOverflow.ellipsis, // 防止文本溢出
                        ),
                      ),
                      // 展开/收起图标 - 移除背景
                      if (hasSubGoals)
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                              color: Colors.grey[800],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _expansionState[goal.id] = !isExpanded;
                              });
                            },
                          ),
                        )
                      else // 没有子目标时占位，保持对齐
                        const SizedBox(width: 32), // 与按钮宽度一致
                    ],
                  ),
                ),
              ),
            ),
            // 递归构建子树 (如果当前节点是展开状态)
            if (isExpanded && hasSubGoals)
              Padding(
                padding: const EdgeInsets.only(
                    left: 0), // 子树的缩进在 _buildGoalTree 内部处理
                child: _buildGoalTree(goal.subGoals, level + 1),
              ),
            // 移除分隔线
          ],
        );
      }).toList(),
    );
  }
}
