import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '隐私政策',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('''
LinzaiVision隐私政策

最后更新日期：2024年3月18日

我们深知个人信息对您的重要性，我们将按照法律法规要求，采取相应的保护措施，保护您的个人信息安全。因此，我们制定本隐私政策并提醒您：

1. 我们如何收集和使用您的个人信息
1.1 手机号码：用于账号登录和身份验证
1.2 设备信息：用于提供基础服务和安全保护
1.3 相机权限：用于图像处理功能

2. 信息的存储
2.1 信息存储的地点：中国境内
2.2 存储期限：服务期间及法律法规要求的期限

3. 信息的保护
3.1 数据加密传输
3.2 访问权限控制
3.3 安全审计

4. 信息的使用
4.1 改进我们的服务
4.2 向您推送相关服务信息
4.3 预防或阻止非法的活动

5. 信息共享
我们不会向第三方出售您的个人信息。仅在以下情况下，我们才会共享您的个人信息：
5.1 获得您的明确同意
5.2 法律法规要求
5.3 保护我们的合法权益

6. 您的权利
6.1 访问、更正您的个人信息
6.2 删除您的个人信息
6.3 撤回同意
6.4 注销账号

7. 未成年人保护
我们非常重视对未成年人个人信息的保护，若您是未满18周岁的未成年人，请在监护人指导下使用我们的服务。

8. 本政策的更新
我们可能适时修改本隐私政策，请您定期查看。对于重大变更，我们会通过显著方式通知您。

9. 如何联系我们
如果您对本隐私政策有任何疑问或建议，可以通过以下方式与我们联系：
电子邮件：privacy@linzai.asia

10. 特别提示
当您使用我们的一键登录服务时，我们会使用阿里云提供的认证服务，相关信息的处理将遵循阿里云的隐私政策。
            '''),
          ],
        ),
      ),
    );
  }
}
