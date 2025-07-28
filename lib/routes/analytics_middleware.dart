import 'package:flutter/material.dart';
import 'route_middleware.dart';
import 'route_analytics.dart';

/// 分析中间件
/// 
/// 用于收集用户导航行为数据
class AnalyticsMiddleware extends RouteMiddleware {
  final RouteAnalytics _analytics;
  
  AnalyticsMiddleware(this._analytics);
  
  @override
  bool beforeEnter(RouteSettings settings) {
    // 总是允许路由跳转
    return true;
  }
  
  @override
  void afterEnter(Route route, RouteSettings settings) {
    // 记录页面访问
    if (settings.name != null) {
      Map<String, dynamic>? parameters;
      if (settings.arguments != null) {
        // 尝试将参数转换为Map
        if (settings.arguments is Map<String, dynamic>) {
          parameters = settings.arguments as Map<String, dynamic>;
        } else {
          // 如果不是Map，则创建一个包含单个值的Map
          parameters = {'value': settings.arguments};
        }
      }
      
      _analytics.recordPageVisit(settings.name!, parameters: parameters);
    }
  }
} 