import 'package:flutter/material.dart';
import '../../models/goal.dart';

/// 主操作菜单
/// 用于全屏视图中显示的弹出式操作菜单
/// 包含对目标的基本操作以及界面显示控制
class GoalOperationMenu extends StatelessWidget {
  /// 当前选中的目标对象
  final Goal? currentGoal;

  /// 更改目标状态的回调函数
  final VoidCallback onStatusChange;

  /// 删除目标的回调函数
  final VoidCallback onDelete;

  /// 分享目标的回调函数
  final VoidCallback onShare;

  // 倒计时功能已移除，等架构稳定后重新实现

  /// 切换时间显示状态的回调函数
  final VoidCallback onToggleTime;

  /// 当前时间的显示状态
  final bool showTime;

  /// 切换描述显示状态的回调函数
  final VoidCallback onToggleDescription;

  /// 当前描述的显示状态
  final bool showDescription;

  /// 切换文本标题显示状态的回调函数
  final VoidCallback onToggleTitle;

  /// 当前文本标题的显示状态
  final bool showTitle;

  /// 切换截止日期设置的回调函数
  final VoidCallback onToggleDeadline;

  /// 添加子条目的回调函数
  final VoidCallback onAddSubGoal;

  /// 查看子目标的回调函数
  final VoidCallback onViewSubGoals;

  // 倒计时功能已移除，等架构稳定后重新实现

  /// 切换视频声音的回调函数
  final VoidCallback? onToggleVideoSound;

  /// 当前视频是否静音
  final bool isMuted;

  /// 切换视频播放状态的回调函数
  final VoidCallback? onToggleVideoPlay;

  /// 当前视频是否正在播放
  final bool isPlaying;

  /// 构造函数
  /// 要求提供目标对象及各种操作的回调函数
  const GoalOperationMenu({
    super.key,
    required this.currentGoal,
    required this.onStatusChange,
    required this.onDelete,
    required this.onShare,
    // 倒计时功能已移除
    required this.onToggleTime,
    required this.showTime,
    required this.onToggleDescription,
    required this.showDescription,
    required this.onToggleTitle,
    required this.showTitle,
    required this.onToggleDeadline,
    required this.onAddSubGoal,
    // 倒计时功能已移除
    required this.onViewSubGoals,
    this.onToggleVideoSound,
    this.isMuted = false,
    this.onToggleVideoPlay,
    this.isPlaying = true,
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
      color: Colors.white,
      itemBuilder: (context) => [
        // 状态变更选项
        PopupMenuItem<String>(
          value: 'status',
          child: GoalOperationMenuItem(
            icon: Icons.check_circle_outline,
            text: '状态变更',
            onTap: () {
              Navigator.pop(context);
              onStatusChange();
            },
          ),
        ),
        // 删除选项
        PopupMenuItem<String>(
          value: 'delete',
          child: GoalOperationMenuItem(
            icon: Icons.delete_outline,
            text: '删除',
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
        // 分享选项
        PopupMenuItem<String>(
          value: 'share',
          child: GoalOperationMenuItem(
            icon: Icons.share,
            text: '分享',
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),
        ),
        // 添加子目标选项
        PopupMenuItem<String>(
          value: 'add_sub_goal',
          child: GoalOperationMenuItem(
            icon: Icons.add_circle_outline,
            text: '添加子目标',
            onTap: () {
              Navigator.pop(context);
              onAddSubGoal();
            },
          ),
        ),
        // 查看子目标选项（仅当有子目标时显示）
        if (currentGoal != null && currentGoal!.subGoals.isNotEmpty)
          PopupMenuItem<String>(
            value: 'view_sub_goals',
            child: GoalOperationMenuItem(
              icon: Icons.list,
              text: '查看子目标 (${currentGoal!.subGoals.length})',
              onTap: () {
                Navigator.pop(context);
                onViewSubGoals();
              },
            ),
          ),
        // 截止日期选项
        PopupMenuItem<String>(
          value: 'deadline',
          child: GoalOperationMenuItem(
            icon: Icons.calendar_today,
            text: '设置截止日期',
            onTap: () {
              Navigator.pop(context);
              onToggleDeadline();
            },
          ),
        ),
        // 倒计时功能已移除，等架构稳定后重新实现
        // 时间显示选项（仅当有截止日期时显示）
        if (currentGoal?.targetDate != null)
          PopupMenuItem<String>(
            value: 'time',
            child: GoalOperationMenuItem(
              icon: showTime
                  ? Icons.access_time_filled
                  : Icons.access_time_outlined,
              text: showTime ? '隐藏截止日期' : '显示截止日期',
              onTap: () {
                Navigator.pop(context);
                onToggleTime();
              },
            ),
          ),
        // 标题显示选项
        PopupMenuItem<String>(
          value: 'title',
          child: GoalOperationMenuItem(
            icon: showTitle ? Icons.title : Icons.title_outlined,
            text: showTitle ? '隐藏文本' : '显示文本',
            onTap: () {
              Navigator.pop(context);
              onToggleTitle();
            },
          ),
        ),
        // 描述显示选项
        PopupMenuItem<String>(
          value: 'description',
          child: GoalOperationMenuItem(
            icon: showDescription ? Icons.info_outline : Icons.info,
            text: showDescription ? '关闭描述' : '显示描述',
            onTap: () {
              Navigator.pop(context);
              onToggleDescription();
            },
          ),
        ),
        // 视频声音控制（仅当有视频时显示）
        if (currentGoal?.hasVideo == true && onToggleVideoSound != null)
          PopupMenuItem<String>(
            value: 'video_sound',
            child: GoalOperationMenuItem(
              icon: isMuted ? Icons.volume_up : Icons.volume_off,
              text: isMuted ? '打开声音' : '关闭声音',
              onTap: () {
                Navigator.pop(context);
                onToggleVideoSound!();
              },
            ),
          ),
        // 视频播放控制（仅当有视频时显示）
        if (currentGoal?.hasVideo == true && onToggleVideoPlay != null)
          PopupMenuItem<String>(
            value: 'video_play',
            child: GoalOperationMenuItem(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              text: isPlaying ? '暂停播放' : '继续播放',
              onTap: () {
                Navigator.pop(context);
                onToggleVideoPlay!();
              },
            ),
          ),
      ],
      onSelected: (String value) {
        // 这里可以处理菜单项选择事件
        // 但我们已经在每个菜单项的onTap中处理了
      },
    );
  }
}

/// 网格项操作菜单
/// 用于网格视图中各个卡片的操作菜单
/// 提供对目标的基本操作
class GoalGridItemMenu extends StatelessWidget {
  /// 当前目标对象
  final Goal goal;

  /// 更改目标状态的回调函数
  final VoidCallback onStatusChange;

  /// 删除目标的回调函数
  final VoidCallback onDelete;

  /// 分享目标的回调函数
  final VoidCallback onShare;

  /// 构造函数
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
        // 更改状态选项
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
        // 删除选项
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除'),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
        // 分享选项
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

/// 通用的目标操作菜单项
/// 提供一个标准化的菜单项组件，用于创建一致风格的菜单项
class GoalOperationMenuItem extends StatelessWidget {
  /// 菜单项图标
  final IconData icon;

  /// 菜单项文本
  final String text;

  /// 点击回调函数
  final VoidCallback onTap;

  /// 是否启用此菜单项
  final bool enabled;

  /// 构造函数
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
