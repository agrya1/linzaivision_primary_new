import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../../models/goal_ui_extension.dart';

class StatusBadge extends StatelessWidget {
  final Goal goal;
  final double? iconSize;
  final double? fontSize;

  const StatusBadge({
    super.key,
    required this.goal,
    this.iconSize,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            goal.getStatusIcon(),
            color: goal.getStatusColor(),
            size: iconSize ?? 16,
          ),
          const SizedBox(width: 8),
          Text(
            goal.getStatusText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
