import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TeamAppsPage extends StatelessWidget {
  const TeamAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '团队其它应用',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AppCard(
            appName: '林再智能助手',
            description: '您的智能AI助手，支持文字对话、图像生成和语音交互',
            iconData: Icons.chat,
            iconColor: Colors.blue,
            appUrl: 'https://www.linzai.asia/ai-assistant',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '林再文档',
            description: '智能文档编辑与管理，支持AI辅助写作和团队协作',
            iconData: Icons.description,
            iconColor: Colors.green,
            appUrl: 'https://www.linzai.asia/docs',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '林再日历',
            description: '智能日程管理工具，帮助您高效规划时间',
            iconData: Icons.calendar_today,
            iconColor: Colors.orange,
            appUrl: 'https://www.linzai.asia/calendar',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '林再健康',
            description: '个人健康管理平台，提供健康监测和生活建议',
            iconData: Icons.favorite,
            iconColor: Colors.red,
            appUrl: 'https://www.linzai.asia/health',
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final String appName;
  final String description;
  final IconData iconData;
  final Color iconColor;
  final String appUrl;

  const _AppCard({
    required this.appName,
    required this.description,
    required this.iconData,
    required this.iconColor,
    required this.appUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _launchAppUrl(appUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchAppUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}
