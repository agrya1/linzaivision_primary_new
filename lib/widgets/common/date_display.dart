import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateDisplay extends StatelessWidget {
  final DateTime date;
  final bool showRemainingDays;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;

  const DateDisplay({
    super.key,
    required this.date,
    this.showRemainingDays = true,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final month = DateFormat.MMM('en_US').format(date);
    final day = DateFormat('dd').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.w500,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: fontSize ?? 20,
              fontWeight: fontWeight ?? FontWeight.bold,
              fontFamily: fontFamily,
            ),
          ),
          if (showRemainingDays)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _getRemainingDays(),
                style: TextStyle(
                  color: textColor?.withOpacity(0.7) ??
                      Colors.white.withOpacity(0.7),
                  fontSize: (fontSize ?? 12) - 2,
                  fontWeight: fontWeight ?? FontWeight.normal,
                  fontFamily: fontFamily,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getRemainingDays() {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return '今天';
    } else if (difference < 0) {
      return '${-difference}天前';
    } else {
      return '还剩$difference天';
    }
  }
}
