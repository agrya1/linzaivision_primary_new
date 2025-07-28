import 'package:flutter/material.dart';

/// 路由中间件基类
/// 
/// 所有路由中间件都应该继承此类
abstract class RouteMiddleware {
  /// 在路由跳转前调用
  /// 
  /// 返回true表示允许跳转，返回false表示拦截跳转
  bool beforeEnter(RouteSettings settings);
  
  /// 在路由跳转后调用
  void afterEnter(Route route, RouteSettings settings);
}

/// 路由日志中间件
/// 
/// 记录用户在应用内的导航路径
class RouteLoggerMiddleware extends RouteMiddleware {
  final bool _enableLogging;
  
  RouteLoggerMiddleware({bool enableLogging = true}) : _enableLogging = enableLogging;
  
  @override
  bool beforeEnter(RouteSettings settings) {
    if (_enableLogging) {
      debugPrint('路由跳转: ${settings.name} - 参数: ${settings.arguments}');
    }
    return true; // 总是允许跳转
  }
  
  @override
  void afterEnter(Route route, RouteSettings settings) {
    if (_enableLogging) {
      debugPrint('路由已进入: ${settings.name}');
    }
    
    // 这里可以添加更多逻辑，如记录用户行为到分析系统
    _recordUserNavigation(settings);
  }
  
  /// 记录用户导航行为
  /// 
  /// 可以将导航数据发送到分析系统或本地存储
  void _recordUserNavigation(RouteSettings settings) {
    // TODO: 实现导航数据记录
    // 例如：记录页面访问时间、来源页面、停留时间等
    
    // 示例：记录到控制台
    final timestamp = DateTime.now().toString();
    debugPrint('[$timestamp] 用户访问: ${settings.name}');
  }
} 