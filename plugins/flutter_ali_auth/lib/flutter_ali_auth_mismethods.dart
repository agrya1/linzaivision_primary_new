// 这个文件用来记录AliAuthClient类中的错误方法
// 该方法应该被移动到AuthService类中

/*
/// 获取登录手机号的掩码形式
Future<String?> getMaskedPhone() async {
  try {
    debugPrint('开始调用预取号功能...');

    // 调用阿里云SDK的预取号功能
    try {
      debugPrint('调用AliAuthClient.getPhoneInfo...');
      final phoneInfoResult = await AliAuthClient.getPhoneInfo(timeout: 5);
      debugPrint('预取号结果: $phoneInfoResult');

      if (phoneInfoResult['resultCode'] == '600000') {
        // 预取号成功
        final maskedPhone = phoneInfoResult['phone'] as String?;
        debugPrint('成功获取掩码号码: $maskedPhone');
        return maskedPhone;
      } else {
        // 预取号失败
        debugPrint('预取号失败: ${phoneInfoResult['msg']}');

        // 尝试从本地存储获取
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone_number') ?? '';
        if (phone.isNotEmpty && phone.length > 7) {
          final masked =
              '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
          debugPrint('从本地存储获取的掩码号码: $masked');
          return masked;
        }

        // 如果都失败，返回模拟数据
        final mockPhone = '133****5678';
        debugPrint('使用模拟的掩码手机号: $mockPhone');
        return mockPhone;
      }
    } catch (sdkError) {
      // 预取号SDK调用出错
      debugPrint('预取号SDK调用异常: $sdkError');

      // 使用模拟数据
      final mockPhone = '134****9876';
      debugPrint('使用模拟的掩码手机号: $mockPhone');
      return mockPhone;
    }
  } catch (e) {
    debugPrint('获取手机号码失败: $e');
    return null;
  }
}
*/
