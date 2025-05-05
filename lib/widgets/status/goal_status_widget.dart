import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/goal.dart';
import 'package:intl/intl.dart';

class GoalStatusWidget extends StatefulWidget {
  final Goal goal;
  final bool showCountdown;

  const GoalStatusWidget({
    super.key,
    required this.goal,
    this.showCountdown = false,
  });

  @override
  State<GoalStatusWidget> createState() => _GoalStatusWidgetState();
}

class _GoalStatusWidgetState extends State<GoalStatusWidget> {
  Timer? _timer;
  late Duration _remainingTime;
  bool _isOverdue = false;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();

    // 设置定时器，每秒更新倒计时
    if (widget.showCountdown && widget.goal.targetDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateRemainingTime();
      });
    }
  }

  @override
  void didUpdateWidget(GoalStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果showCountdown状态变化，更新定时器
    if (widget.showCountdown != oldWidget.showCountdown ||
        widget.goal.targetDate != oldWidget.goal.targetDate) {
      _updateRemainingTime();

      // 取消旧定时器
      _timer?.cancel();

      // 如果需要显示倒计时，创建新定时器
      if (widget.showCountdown && widget.goal.targetDate != null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _updateRemainingTime();
        });
      }
    }
  }

  @override
  void dispose() {
    // 组件销毁时取消定时器
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    if (widget.goal.targetDate == null) {
      _remainingTime = Duration.zero;
      return;
    }

    final now = DateTime.now();
    if (widget.goal.targetDate!.isBefore(now)) {
      // 如果目标日期已过，计算超期时间
      _remainingTime = now.difference(widget.goal.targetDate!);
      _isOverdue = true;
    } else {
      // 计算剩余时间
      _remainingTime = widget.goal.targetDate!.difference(now);
      _isOverdue = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 状态显示
        if (widget.goal.status != GoalStatus.pending)
          SizedBox(
            width: 200,
            height: 200,
            child: widget.goal.status == GoalStatus.completed
                ? Image.asset(
                    'assets/icons/chenggong.png',
                  )
                : Image.asset(
                    'assets/icons/feiqi.png',
                  ),
          ),

        // 可视化倒计时显示
        if (widget.goal.targetDate != null &&
            widget.goal.status == GoalStatus.pending &&
            widget.showCountdown)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 前缀文字
                Text(
                  _isOverdue ? '已超期' : '剩余',
                  style: TextStyle(
                    color: _isOverdue ? Colors.red : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                // 倒计时数字显示
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeBlock(_remainingTime.inDays, 'DAYS'),
                    const SizedBox(width: 10),
                    _buildTimeBlock(_getRemainingHours(), 'HOURS'),
                    const SizedBox(width: 10),
                    _buildTimeBlock(_getRemainingMinutes(), 'MINUTES'),
                    const SizedBox(width: 10),
                    _buildTimeBlock(_getRemainingSeconds(), 'SECONDS'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 构建时间块
  Widget _buildTimeBlock(int value, String label) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w300,
            fontFamily: 'Abhaya Libre ExtraBold',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 获取剩余小时（0-23）
  int _getRemainingHours() {
    return _remainingTime.inHours % 24;
  }

  // 获取剩余分钟（0-59）
  int _getRemainingMinutes() {
    return _remainingTime.inMinutes % 60;
  }

  // 获取剩余秒数（0-59）
  int _getRemainingSeconds() {
    return _remainingTime.inSeconds % 60;
  }
}
