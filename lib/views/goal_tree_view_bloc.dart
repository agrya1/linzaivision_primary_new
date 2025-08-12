/// BLoC化的GoalTreeView组件
///
/// 使用BLoC事件通信机制替代复杂的回调链
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/component/component_communication_bloc.dart';
import '../bloc/component/component_communication_events.dart';

/// BLoC化的GoalTreeView组件
class GoalTreeViewBloc extends StatefulWidget {
  final List<Goal> goals;
  final int membershipStatus;
  final bool isLoggedIn;
  final String? userAvatar;
  final String? userNickname;

  const GoalTreeViewBloc({
    super.key,
    required this.goals,
    required this.membershipStatus,
    this.isLoggedIn = false,
    this.userAvatar,
    this.userNickname,
  });

  @override
  State<GoalTreeViewBloc> createState() => _GoalTreeViewBlocState();
}

class _GoalTreeViewBlocState extends State<GoalTreeViewBloc> {
  // 使用 Map 来存储每个 Goal 的展开状态，key 为 goal.id
  final Map<int?, bool> _expansionState = {};

  @override
  void initState() {
    super.initState();
    // 初始化时设置所有有子目标的条目默认展开
    _initExpansionState();
  }

  @override
  void didUpdateWidget(GoalTreeViewBloc oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当goals发生变化时，重新初始化展开状态
    if (oldWidget.goals != widget.goals) {
      _initExpansionState();
    }
  }

  // 初始化展开状态，有子目标的条目默认展开
  void _initExpansionState() {
    for (var goal in widget.goals) {
      _setInitialExpansion(goal);
    }
  }

  // 递归设置初始展开状态
  void _setInitialExpansion(Goal goal) {
    if (goal.subGoals.isNotEmpty) {
      // 有子目标的条目默认展开
      _expansionState[goal.id] = true;

      // 递归处理子目标
      for (var subGoal in goal.subGoals) {
        _setInitialExpansion(subGoal);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 监听组件通信状态
        BlocListener<ComponentCommunicationBloc, ComponentCommunicationState>(
          listener: (context, state) {
            if (state is DialogRequested) {
              _handleDialogRequest(context, state);
            } else if (state is MessageRequested) {
              _showMessage(context, state);
            } else if (state is NavigationRequested) {
              _handleNavigation(context, state);
            }
          },
        ),
      ],
      child: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, goalState) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 顶部搜索和同步区域
                  _buildTopSection(context),

                  // 目标列表
                  Expanded(
                    child: BlocBuilder<GoalBloc, GoalState>(
                      buildWhen: (prev, curr) {
                        if (prev is GoalsLoaded && curr is GoalsLoaded) {
                          return prev.allGoals.length != curr.allGoals.length ||
                              prev.currentGoal?.id != curr.currentGoal?.id;
                        }
                        return prev.runtimeType != curr.runtimeType;
                      },
                      builder: (context, state) {
                        final roots = (state is GoalsLoaded)
                            ? state.allGoals.where((g) => g.parentId == null).toList()
                            : widget.goals;
                        return ListView(
                          padding: const EdgeInsets.only(top: 4),
                          children: [
                            _buildExploreEntry(context),
                            _buildGoalTree(roots, 0),
                          ],
                        );
                      },
                    ),
                  ),

                  // 用户信息与设置区域
                  _buildBottomSection(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 临在意识图标（左上角）
          InkWell(
            onTap: () {
              // 根据设置中的首页设置回到首页
              context
                  .read<ComponentCommunicationBloc>()
                  .add(const NavigateToPage('/'));
            },
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 48,
              height: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreEntry(BuildContext context) {
    return ListTile(
      leading: null,
      title: const Text(
        '意识探索',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
      ),
      onTap: () {
        context
            .read<ComponentCommunicationBloc>()
            .add(const NavigateToExplore());
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
    );
  }

  Widget _buildGoalTree(List<Goal> goals, int level) {
    return Column(
      children: goals.map((goal) => _buildGoalItem(goal, level)).toList(),
    );
  }

  Widget _buildGoalItem(Goal goal, int level) {
    final isExpanded = _expansionState[goal.id] ?? false;
    final hasSubGoals = goal.subGoals.isNotEmpty;

    return Column(
      children: [
        // 主目标项
        Slidable(
          key: ValueKey(goal.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              // 编辑操作
              SlidableAction(
                onPressed: (context) {
                  _editGoal(goal);
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: '编辑',
                padding: EdgeInsets.zero,
              ),
              // 删除操作
              SlidableAction(
                onPressed: (context) {
                  _deleteGoal(goal);
                },
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: '删除',
                padding: EdgeInsets.zero,
                borderRadius: level == 0
                    ? const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12))
                    : BorderRadius.zero,
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              _selectGoal(goal);
            },
            child: Container(
              padding: EdgeInsets.only(
                left: 16.0 + (24.0 * level),
                right: 8.0,
                top: 12.0,
                bottom: 12.0,
              ),
              child: Row(
                children: [
                  // 目标标题（根据层级调整样式）
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: level == 0 ? 16 : 14, // 父级16px，子级14px
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 展开/收起按钮（移到右边）
                  if (hasSubGoals)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _expansionState[goal.id] = !isExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 子目标（如果展开）
        if (hasSubGoals && isExpanded) _buildGoalTree(goal.subGoals, level + 1),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
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
      child: widget.isLoggedIn
          ? _buildLoggedInUserSection(context)
          : _buildLoginSection(context),
    );
  }

  // 已登录用户区域：点击头像昵称直接进入设置
  Widget _buildLoggedInUserSection(BuildContext context) {
    return InkWell(
      onTap: () {
        // 点击头像昵称直接进入设置页面
        context
            .read<ComponentCommunicationBloc>()
            .add(const NavigateToSettings());
      },
      child: Row(
        children: [
          // 用户头像（已登录使用default_avatar.png）
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.transparent,
            backgroundImage:
                const AssetImage('assets/images/default_avatar.png'),
          ),

          const SizedBox(width: 12),

          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userNickname ?? '用户',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.membershipStatus > 0 ? '会员用户' : '普通用户',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 未登录用户区域：只显示登录入口
  Widget _buildLoginSection(BuildContext context) {
    return InkWell(
      onTap: () {
        // 点击进入登录页面
        context.read<ComponentCommunicationBloc>().add(const NavigateToLogin());
      },
      child: Row(
        children: [
          // 登录图标（未登录使用default_avatar_al.png）
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.transparent,
            backgroundImage:
                const AssetImage('assets/images/default_avatar_al.png'),
          ),

          const SizedBox(width: 12),

          // 登录提示
          Expanded(
            child: Text(
              '点击登录',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),

          // 登录箭头
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  // 已移除：不再使用状态颜色指示器

  void _selectGoal(Goal goal) {
    // 关闭抽屉
    context
        .read<ComponentCommunicationBloc>()
        .add(const DrawerCloseRequested());

    // 选择目标并切回全屏视图
    final bloc = context.read<GoalBloc>();
    bloc.add(SelectGoal(goal));
    bloc.add(const ToggleViewMode(0));
  }

  void _editGoal(Goal goal) {
    // 显示编辑目标对话框
    context.read<ComponentCommunicationBloc>().add(ShowGoalOperationMenu(goal));
  }

  void _deleteGoal(Goal goal) {
    // 显示确认删除对话框
    context.read<ComponentCommunicationBloc>().add(ShowConfirmationDialog(
          title: '确认删除',
          message: '确定要删除目标"${goal.title}"吗？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          confirmEventId: 'delete_goal_${goal.id}',
        ));
  }

  void _handleDialogRequest(BuildContext context, DialogRequested state) {
    switch (state.type) {
      // 已移除：搜索功能
      case 'sync':
        _showSyncDialog(context);
        break;
      case 'confirmation':
        _showConfirmationDialog(context, state.data);
        break;
      case 'goal_operation_menu':
        _showGoalOperationMenu(context, state.data['goal'] as Goal);
        break;
    }
  }

  // 已移除：搜索功能相关方法

  void _showSyncDialog(BuildContext context) {
    // 这里应该实现同步功能
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('同步数据'),
        content: const Text('同步功能待实现'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(
      BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] as String),
        content: Text(data['message'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(data['cancelText'] as String),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleConfirmAction(data['confirmEventId'] as String);
            },
            child: Text(data['confirmText'] as String),
          ),
        ],
      ),
    );
  }

  void _showGoalOperationMenu(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑目标'),
              onTap: () {
                Navigator.pop(context);
                // 触发编辑事件
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('标记完成'),
              onTap: () {
                Navigator.pop(context);
                _updateGoalStatus(goal, GoalStatus.completed);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('废弃目标'),
              onTap: () {
                Navigator.pop(context);
                _updateGoalStatus(goal, GoalStatus.abandoned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除目标', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteGoal(goal);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateGoalStatus(Goal goal, GoalStatus newStatus) {
    final updatedGoal = goal.copyWith(status: newStatus);
    context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
  }

  void _handleConfirmAction(String confirmEventId) {
    if (confirmEventId.startsWith('delete_goal_')) {
      final goalId =
          int.tryParse(confirmEventId.replaceFirst('delete_goal_', ''));
      if (goalId != null) {
        context.read<GoalBloc>().add(DeleteGoal(goalId));
      }
    }
  }

  void _showMessage(BuildContext context, MessageRequested state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: state.type == 'error' ? Colors.red : Colors.green,
        duration: state.duration ?? const Duration(seconds: 3),
      ),
    );
  }

  void _handleNavigation(BuildContext context, NavigationRequested state) {
    switch (state.routeName) {
      case 'drawer_close':
        Navigator.pop(context);
        break;
      case '/':
        // 回到首页
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        break;
      case '/explore':
        Navigator.pop(context);
        Navigator.pushNamed(context, '/explore');
        break;
      case '/settings':
        Navigator.pop(context);
        Navigator.pushNamed(context, '/settings');
        break;
      case '/login':
        Navigator.pop(context);
        Navigator.pushNamed(context, '/login');
        break;
      default:
        Navigator.pushNamed(context, state.routeName,
            arguments: state.arguments);
        break;
    }
  }
}
