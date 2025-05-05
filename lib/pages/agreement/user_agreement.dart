import 'package:flutter/material.dart';

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户协议'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '用户协议',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('''
欢迎使用LinzaiVision！

1. 协议的范围
本协议是您与LinzaiVision（以下简称"我们"）之间关于您使用我们的产品和服务所订立的协议。

2. 账号注册与使用
2.1 您承诺提供真实、准确、完整的注册信息。
2.2 您应妥善保管账号和密码，对账号下的所有行为负责。

3. 用户行为规范
3.1 遵守法律法规
3.2 尊重知识产权
3.3 维护网络秩序

4. 服务内容
4.1 我们提供的服务内容包括但不限于：图像处理、视觉识别等。
4.2 我们保留随时修改或中断服务的权利。

5. 隐私保护
我们重视用户隐私保护，具体详见《隐私政策》。

6. 知识产权
6.1 我们的产品、技术、软件、商标等知识产权归我们所有。
6.2 未经允许，不得擅自使用。

7. 免责声明
7.1 我们不对因网络、设备等问题导致的服务中断负责。
7.2 对于非我们原因造成的损失，我们不承担责任。

8. 协议修改
我们保留修改本协议的权利，修改后的协议将在网站上公布。

9. 法律适用
本协议适用中华人民共和国法律。

最后更新日期：2024年3月18日
            '''),
          ],
        ),
      ),
    );
  }
}
