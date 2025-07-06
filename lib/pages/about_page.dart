import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // 打开链接的方法
  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw '无法打开链接: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '关于应用',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // Logo区域
            Hero(
              tag: 'app_logo',
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 应用名称
            const Text(
              '临在愿景',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 8),

            // 版本信息
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 48),

            // 应用简介
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '临在意识是一款帮助用户进行意识显化的意识观测应用。通过多种展示方式和交互设计，帮助用户更好地管理和显化自己地意识。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.grey[700],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 联系我们模块
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '联系我们',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 联系方式列表
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    title: '电子邮件',
                    subtitle: 'yurentech@qq.com',
                    onTap: () => _launchUrl('mailto:yurentech@qq.com'),
                  ),

                  const Divider(height: 24),

                  _buildContactItem(
                    icon: Icons.public,
                    title: '官方网站',
                    subtitle: 'list.linzai.asia',
                    onTap: () => _launchUrl('https://list.linzai.asia'),
                  ),

                  const Divider(height: 24),

                  _buildContactItem(
                    icon: Icons.chat_outlined,
                    title: '微信公众号',
                    subtitle: '临在之境',
                    onTap: () {
                      // 显示二维码对话框
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('关注我们的微信公众号'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Text('二维码位置'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('临在科技',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('关闭'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),

                  //微信客服
                  _buildContactItem(
                    icon: Icons.wechat,
                    title: '客服微信号',
                    subtitle: 'yurensupport',
                    onTap: () => _launchUrl('https://list.linzai.asia'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // 版权信息
            Text(
              '© 2025 Linzai Vision',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 8),

            // 开发者信息
            Text(
              'Developed with linzai team',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 构建联系方式项
  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
