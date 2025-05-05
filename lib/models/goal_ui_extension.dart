import 'package:flutter/material.dart';
import 'goal.dart';

/// Goal 模型的 UI 扩展
extension GoalUI on Goal {
  /// 获取状态对应的图标
  IconData getStatusIcon() {
    switch (status) {
      case GoalStatus.pending:
        return Icons.pending_actions;
      case GoalStatus.completed:
        return Icons.check_circle;
      case GoalStatus.abandoned:
        return Icons.cancel;
    }
  }

  /// 获取状态对应的文本
  String getStatusText() {
    switch (status) {
      case GoalStatus.pending:
        return '待完成';
      case GoalStatus.completed:
        return '已完成';
      case GoalStatus.abandoned:
        return '已废弃';
    }
  }

  /// 获取状态对应的颜色
  Color getStatusColor() {
    switch (status) {
      case GoalStatus.pending:
        return Colors.blue;
      case GoalStatus.completed:
        return Colors.green;
      case GoalStatus.abandoned:
        return Colors.grey;
    }
  }

  /// 获取剩余天数文本
  String getRemainingDaysText() {
    if (targetDate == null) return '';
    final difference = targetDate!.difference(DateTime.now());
    final days = difference.inDays;
    if (days < 0) {
      return '已超期 ${days.abs()} 天';
    } else if (days == 0) {
      return '今天到期';
    } else {
      return '剩余 $days 天';
    }
  }

  /// 获取剩余天数对应的颜色
  Color getRemainingDaysColor() {
    if (targetDate == null) return Colors.grey;
    return targetDate!.isBefore(DateTime.now()) ? Colors.red : Colors.white;
  }
}
