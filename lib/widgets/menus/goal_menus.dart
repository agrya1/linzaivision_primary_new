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

  /// 切换倒计时显示状态的回调函数
  final VoidCallback onToggleCountdown;

  /// 当前倒计时的显示状态
  final bool showCountdown;

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

  /// 设置自定义倒计时的回调函数
  final VoidCallback onToggleCustomCountdown;

  /// 当前是否有自定义倒计时
  final bool hasCustomCountdown;

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
    required this.onToggleCountdown,
    required this.showCountdown,
    required this.onToggleTime,
    required this.showTime,
    required this.onToggleDescription,
    required this.showDescription,
    required this.onToggleTitle,
    required this.showTitle,
    required this.onToggleDeadline,
    required this.onAddSubGoal,
    required this.onToggleCustomCountdown,
    required this.hasCustomCountdown,
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
      itemBuilder: (context) => [
        // 全屏视图下的选项
        if (currentGoal != null) ...[
          // 新增截止日期设置/删除选项
          PopupMenuItem(
            child: ListTile(
              leading: Icon(currentGoal!.targetDate != null
                  ? Icons.event_busy
                  : Icons.event),
              title:
                  Text(currentGoal!.targetDate != null ? '删除截止日期' : '设置截止日期'),
              onTap: () {
                Navigator.pop(context);
                onToggleDeadline();
              },
            ),
          ),

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

          // 新增子条目选项
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新增子条目'),
              onTap: () {
                Navigator.pop(context);
                onAddSubGoal();
              },
            ),
          ),

          // 添加倒计时显示开关，区分有无截止日期的情况
          PopupMenuItem(
            child: ListTile(
              leading: Icon(showCountdown ? Icons.timer_off : Icons.timer),
              title: Text(currentGoal!.targetDate != null
                  ? (showCountdown ? '隐藏倒计时' : '显示倒计时')
                  : (hasCustomCountdown ? '关闭倒计时' : '设置倒计时')),
              onTap: () {
                Navigator.pop(context);
                if (currentGoal!.targetDate != null) {
                  onToggleCountdown();
                } else {
                  onToggleCustomCountdown();
                }
              },
            ),
          ),

          // 添加时间显示开关，仅当有截止日期时显示
          if (currentGoal?.targetDate != null)
            PopupMenuItem(
              child: ListTile(
                leading: Icon(showTime
                    ? Icons.access_time_filled
                    : Icons.access_time_outlined),
                title: Text(showTime ? '隐藏截止日期' : '显示截止日期'),
                onTap: () {
                  Navigator.pop(context);
                  onToggleTime();
                },
              ),
            ),

          // 添加文本显示开关
          PopupMenuItem(
            child: ListTile(
              leading: Icon(showTitle ? Icons.title : Icons.title_outlined),
              title: Text(showTitle ? '隐藏文本' : '显示文本'),
              onTap: () {
                Navigator.pop(context);
                onToggleTitle();
              },
            ),
          ),

          // 添加描述显示开关
          PopupMenuItem(
            child: ListTile(
              leading: Icon(showDescription ? Icons.info_outline : Icons.info),
              title: Text(showDescription ? '关闭描述' : '显示描述'),
              onTap: () {
                Navigator.pop(context);
                onToggleDescription();
              },
            ),
          ),

          // 视频控制选项，仅当有视频时显示
          if (currentGoal?.hasVideo == true && onToggleVideoSound != null)
            PopupMenuItem(
              child: ListTile(
                leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off),
                title: Text(isMuted ? '打开声音' : '关闭声音'),
                onTap: () {
                  Navigator.pop(context);
                  onToggleVideoSound!();
                },
              ),
            ),

          if (currentGoal?.hasVideo == true && onToggleVideoPlay != null)
            PopupMenuItem(
              child: ListTile(
                leading: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                title: Text(isPlaying ? '暂停播放' : '继续播放'),
                onTap: () {
                  Navigator.pop(context);
                  onToggleVideoPlay!();
                },
              ),
            ),
        ],
      ],
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
