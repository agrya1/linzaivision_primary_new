import 'package:flutter/material.dart';
import 'package:linzaivision_primary/pages/membership/membership_page.dart';

class MembershipPromptDialog {
  /// 显示会员特权提示弹窗
  static Future<void> show(BuildContext context, {String? message}) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 10),
            Text('会员专属功能'),
          ],
        ),
        content: Text(message ?? '此功能仅限会员使用，开通会员即可使用全部功能以及更多特权。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
            child: const Text('暂不开通'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MembershipPage()),
              );
            },
            child: const Text('立即开通'),
          ),
        ],
      ),
    );
  }

  /// 显示会员图片选择提示
  static Future<void> showImagePrompt(BuildContext context) async {
    return show(context, message: '此图片仅限会员使用，开通会员即可使用全部图片以及更多特权功能。');
  }

  /// 显示会员数量限制提示
  static Future<void> showLimitPrompt(BuildContext context) async {
    return show(context, message: '普通用户最多创建3个项目，开通会员可创建无限数量的项目。');
  }
}
