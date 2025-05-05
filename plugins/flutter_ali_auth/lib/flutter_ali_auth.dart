import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// 授权页面样式
enum AuthUIStyle {
  /// 全屏
  fullScreen,

  /// 底部弹窗
  bottomSheet,

  /// 弹窗
  alert,
}

/// 授权UI配置
class AuthConfig {
  /// iOS SDK配置
  final String iosSdk;

  /// Android SDK配置
  final String androidSdk;

  /// 是否启用日志
  final bool enableLog;

  /// 授权页面UI风格
  final AuthUIStyle authUIStyle;

  AuthConfig({
    required this.iosSdk,
    required this.androidSdk,
    this.enableLog = false,
    this.authUIStyle = AuthUIStyle.fullScreen,
  });

  Map<String, dynamic> toJson() {
    return {
      'iosSdk': iosSdk,
      'androidSdk': androidSdk,
      'enableLog': enableLog,
      'authUIStyle': authUIStyle.toString().split('.').last,
    };
  }
}

/// 阿里云一键登录客户端
class AliAuthClient {
  static const MethodChannel _channel = MethodChannel('flutter_ali_auth');

  /// 当前SDK版本号
  static String get sdkVersion => "1.1.0";

  /// 初始化SDK
  static Future<void> initSdk({required AuthConfig authConfig}) async {
    try {
      await _channel.invokeMethod('initSdk', authConfig.toJson());
    } catch (e) {
      print('Error initializing SDK: $e');
      rethrow;
    }
  }

  /// 预取号
  static Future<Map<String, dynamic>> getPhoneInfo({int? timeout}) async {
    try {
      final result = await _channel
          .invokeMethod('getPhoneInfo', {'timeout': timeout ?? 5});
      return result is Map
          ? Map<String, dynamic>.from(result)
          : {'resultCode': '600002', 'msg': '预取号失败'};
    } catch (e) {
      print('Error getting phone info: $e');
      rethrow;
    }
  }

  /// 注册事件处理
  static void handleEvent({required Function(dynamic) onEvent}) {
    _channel.setMethodCallHandler((call) async {
      print('Flutter端收到方法调用: ${call.method}');
      print('Flutter端收到参数: ${call.arguments}');

      if (call.method == 'onEvent' || call.method == 'loginResult') {
        print('Flutter端处理${call.method}事件: ${call.arguments}');
        onEvent(call.arguments);
      }
      return null;
    });
  }

  /// 移除事件处理器
  static Future<void> removeHandler() async {
    _channel.setMethodCallHandler(null);
  }

  /// 开始一键登录
  static Future<void> login({int? timeout}) async {
    try {
      await _channel.invokeMethod('login', {'timeout': timeout ?? 5});
    } catch (e) {
      print('Error during login: $e');
      rethrow;
    }
  }

  /// 隐藏登录加载
  static Future<void> hideLoginLoading() async {
    try {
      await _channel.invokeMethod('hideLoginLoading');
    } catch (e) {
      print('Error hiding login loading: $e');
      rethrow;
    }
  }

  /// 退出登录页面
  static Future<void> quitLoginPage() async {
    try {
      await _channel.invokeMethod('quitLoginPage');
    } catch (e) {
      print('Error quitting login page: $e');
      rethrow;
    }
  }
}
