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
            appName: '临在清单',
            description: '用色彩管理生活，重建意识秩序',
            logoAsset: 'assets/images/applogo/linzailist_logo.png',
            appUrl: 'https://list.linzai.asia',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '临在笔记',
            description: '基于色彩心理学的极简笔记',
            logoAsset: 'assets/images/applogo/linzainote_logo.png',
            appUrl: 'https://note.linzai.asia',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '临在心语',
            description: '深度沟通，人与人的心灵关系',
            logoAsset: 'assets/images/applogo/linzaiecho_logo.png',
            appUrl: 'https://www.linzai.asia/calendar',
          ),
          SizedBox(height: 16),
          _AppCard(
            appName: '临在官网',
            description: '意识觉醒的数字空间',
            logoAsset: 'assets/images/applogo/linzai_logo.png',
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
  final String logoAsset;
  final String appUrl;

  const _AppCard({
    required this.appName,
    required this.description,
    required this.logoAsset,
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
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    logoAsset,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
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
