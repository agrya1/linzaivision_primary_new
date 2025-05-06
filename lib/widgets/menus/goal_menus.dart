import 'package:flutter/material.dart';
import '../../models/goal.dart';

/// 主操作菜单
class GoalOperationMenu extends StatelessWidget {
  final Goal? currentGoal;
  final VoidCallback onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onToggleCountdown;
  final bool showCountdown;

  const GoalOperationMenu({
    super.key,
    required this.currentGoal,
    required this.onStatusChange,
    required this.onDelete,
    required this.onShare,
    required this.onToggleCountdown,
    required this.showCountdown,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      icon: Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      itemBuilder: (context) => [
        // 全屏视图下的选项
        if (currentGoal != null) ...[
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.update),
              title: const Text('更改状态'),
              onTap: () {
                Navigator.pop(context);
                onStatusChange();
              },
            ),
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('删除目标'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ),
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
            ),
          ),
          // 添加倒计时显示开关
          if (currentGoal?.targetDate != null)
            PopupMenuItem(
              child: ListTile(
                leading: Icon(showCountdown ? Icons.timer_off : Icons.timer),
                title: Text(showCountdown ? '关闭倒计时' : '显示倒计时'),
                onTap: () {
                  Navigator.pop(context);
                  onToggleCountdown();
                },
              ),
            ),
        ],
      ],
    );
  }
}

/// 网格项操作菜单
class GoalGridItemMenu extends StatelessWidget {
  final Goal goal;
  final VoidCallback onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const GoalGridItemMenu({
    super.key,
    required this.goal,
    required this.onStatusChange,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.update),
            title: const Text('更改状态'),
            onTap: () {
              Navigator.pop(context);
              onStatusChange();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除目标'),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享'),
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),
        ),
      ],
    );
  }
}

class GoalOperationMenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool enabled;

  const GoalOperationMenuItem({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
