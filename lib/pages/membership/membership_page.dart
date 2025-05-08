import 'dart:ui'; // 导入ImageFilter
import 'package:flutter/material.dart';

/// 会员购买页面
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  int _selectedPlan = 0; // 0: 月度, 1: 年度

  // 模拟价格数据
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 0,
      'duration': '1个月',
      'originalPrice': '16.90/月',
      'currentPrice': '9.90/月',
    },
    {
      'id': 1,
      'duration': '1年',
      'originalPrice': '188.90/年',
      'currentPrice': '108.90/年',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 让body延伸到AppBar后面
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar透明
        elevation: 0, // 去掉阴影
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. 背景图片
          Positioned.fill(
            child: Image.asset(
              'assets/images/VIP.png', // 确保使用正斜杠
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 如果图片加载失败，显示纯色背景
                print("Error loading VIP background image: $error");
                return Container(color: Colors.black);
              },
            ),
          ),
          // 2. 玻璃模糊遮罩
          Positioned.fill(
            child: ClipRect(
              // 使用ClipRect防止模糊效果溢出
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  // 添加一层半透明黑色，增强玻璃感和文字对比度
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
          ),
          // 3. 主要内容区域
          SafeArea(
            // 避免内容被状态栏或刘海遮挡
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: kToolbarHeight), // AppBar的高度补偿
                  // 标题
                  _buildTitleSection(),
                  const SizedBox(height: 40),
                  // 会员权益
                  _buildBenefitsSection(),
                  const SizedBox(height: 50),
                  // 价格选择
                  _buildPricingSection(),
                  const SizedBox(height: 40),
                  // 购买按钮
                  _buildCtaButton(context),
                  const SizedBox(height: 20),
                  // 推荐文本
                  _buildRecommendationText(),
                  const SizedBox(height: 40), // 底部留白
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建标题区域
  Widget _buildTitleSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRO会员',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '解锁全部高级功能',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // 构建会员权益区域
  Widget _buildBenefitsSection() {
    return Column(
      children: [
        _buildBenefitItem(Icons.check_circle, '无限制项目数量'),
        _buildBenefitItem(Icons.cloud_queue, '云端数据同步'),
        _buildBenefitItem(Icons.devices, '多设备数据互通'),
        _buildBenefitItem(Icons.backup, '数据定期备份'),
        _buildBenefitItem(Icons.palette, '专属愿景图片'),
        _buildBenefitItem(Icons.new_releases, '优先体验新功能'),
      ],
    );
  }

  // 构建单个权益项
  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 构建价格选择区域
  Widget _buildPricingSection() {
    return Column(
      children: _plans.map((plan) {
        final bool isSelected = plan['id'] == _selectedPlan;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlan = plan['id'];
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? null
                  : Border.all(color: Colors.white54, width: 1),
            ),
            child: Row(
              children: [
                // Radio Button
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // 时长
                Text(
                  plan['duration'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
                const Spacer(),
                // 原价
                if (plan['originalPrice'] != null)
                  Text(
                    '¥${plan['originalPrice']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.grey[500] : Colors.white70,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                const SizedBox(width: 8),
                // 现价
                Text(
                  '¥${plan['currentPrice']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 构建购买按钮
  Widget _buildCtaButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // TODO: 实现购买逻辑，传递 _selectedPlan
          print('Selected plan ID: $_selectedPlan');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: const Text(
          '立即开通',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 构建推荐文本
  Widget _buildRecommendationText() {
    return const Center(
      child: Text(
        '超过69%的用户选择此方案', // 或根据实际选择动态变化
        style: TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
