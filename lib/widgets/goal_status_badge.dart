import 'package:flutter/material.dart';
import '../mixins/component_state_mixin.dart';
import '../models/goal.dart';
import '../utils/component_state_manager.dart';
import '../widgets/component_state_provider.dart';

/// 目标状态徽章组件
///
/// 使用新的组件状态传递机制的试点组件
/// 展示如何简化状态访问和事件处理
class GoalStatusBadge extends StatefulWidget {
  final Goal? goal;
  final bool useNewStateManagement;
  final VoidCallback? onTap;

  const GoalStatusBadge({
    Key? key,
    this.goal,
    this.useNewStateManagement = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<GoalStatusBadge> createState() => _GoalStatusBadgeState();
}

class _GoalStatusBadgeState extends State<GoalStatusBadge>
    with ComponentStateMixin {
  Goal? _localGoal;

  @override
  void initState() {
    super.initState();
    _localGoal = widget.goal;

    // 如果启用新状态管理，监听当前目标变化
    if (widget.useNewStateManagement && hasStateManager) {
      listenToCurrentGoal(_onCurrentGoalChanged);
    }
  }

  void _onCurrentGoalChanged() {
    if (mounted) {
      setState(() {
        // 使用新状态管理机制获取当前目标
        _localGoal = currentGoal;
      });
    }
  }

  Goal? get displayGoal {
    if (widget.useNewStateManagement && hasStateManager) {
      // 使用新状态管理机制
      return currentGoal ?? widget.goal;
    } else {
      // 使用传统方式
      return widget.goal;
    }
  }

  Color _getStatusColor(GoalStatus status) {
    switch (status) {
      case GoalStatus.pending:
        return Colors.orange;
      case GoalStatus.completed:
        return Colors.green;
      case GoalStatus.abandoned:
        return Colors.red;
    }
  }

  String _getStatusText(GoalStatus status) {
    switch (status) {
      case GoalStatus.pending:
        return '待开始';
      case GoalStatus.completed:
        return '已完成';
      case GoalStatus.abandoned:
        return '已废弃';
    }
  }

  IconData _getStatusIcon(GoalStatus status) {
    switch (status) {
      case GoalStatus.pending:
        return Icons.schedule;
      case GoalStatus.completed:
        return Icons.check_circle;
      case GoalStatus.abandoned:
        return Icons.cancel;
    }
  }

  void _onBadgeTap() {
    final goal = displayGoal;
    if (goal == null) return;

    if (widget.useNewStateManagement && hasStateManager) {
      // 使用新状态管理机制切换状态
      final newStatus = goal.status == GoalStatus.completed
          ? GoalStatus.pending
          : GoalStatus.completed;

      final updatedGoal = goal.copyWith(status: newStatus);
      updateGoal(updatedGoal);

      // 如果这是当前目标，更新当前目标状态
      if (currentGoal?.id == goal.id) {
        currentGoal = updatedGoal;
      }
    } else {
      // 传统方式处理
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = displayGoal;

    if (goal == null) {
      return const SizedBox.shrink();
    }

    final status = goal.status;
    final color = _getStatusColor(status);
    final text = _getStatusText(status);
    final icon = _getStatusIcon(status);

    return GestureDetector(
      onTap: _onBadgeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.useNewStateManagement && hasStateManager) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.auto_awesome,
                size: 12,
                color: color.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 目标状态统计组件
///
/// 展示如何使用ComponentStateBuilder监听多个状态
class GoalStatusStats extends StatelessWidget {
  final bool useNewStateManagement;

  const GoalStatusStats({
    Key? key,
    this.useNewStateManagement = false,
  }) : super(key: key);

  Map<GoalStatus, int> _calculateStats(List<Goal> goals) {
    final stats = <GoalStatus, int>{};
    for (final status in GoalStatus.values) {
      stats[status] = 0;
    }

    for (final goal in goals) {
      stats[goal.status] = (stats[goal.status] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    if (!useNewStateManagement) {
      return const Text('需要启用新状态管理');
    }

    return ComponentStateBuilder(
      listenToKeys: const [ComponentStateKeys.allGoals],
      rebuildOnAnyChange: false,
      builder: (context, stateManager) {
        final allGoals =
            stateManager.getState<List<Goal>>(ComponentStateKeys.allGoals) ??
                [];
        final stats = _calculateStats(allGoals);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '目标统计',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...stats.entries.map((entry) {
                  final status = entry.key;
                  final count = entry.value;

                  if (count == 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        GoalStatusBadge(
                          goal: Goal(
                            title: '',
                            description: '',
                            imagePath: '',
                            status: status,
                            createdTime: DateTime.now(),
                          ),
                          useNewStateManagement: false,
                        ),
                        const SizedBox(width: 8),
                        Text('$count 个'),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                Text(
                  '总计: ${allGoals.length} 个目标',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 当前目标信息组件
///
/// 展示如何使用ComponentStateConsumer监听特定状态
class CurrentGoalInfo extends StatelessWidget {
  const CurrentGoalInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ComponentStateConsumer<Goal>(
      stateKey: ComponentStateKeys.currentGoal,
      builder: (context, currentGoal) {
        if (currentGoal == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('未选择目标'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '当前目标',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GoalStatusBadge(
                      goal: currentGoal,
                      useNewStateManagement: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentGoal.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (currentGoal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    currentGoal.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '创建时间: ${_formatDate(currentGoal.createdTime)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      listener: (context, currentGoal) {
        // 当目标变化时显示提示
        if (currentGoal != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('切换到目标: ${currentGoal.title}'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
