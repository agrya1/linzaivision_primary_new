import 'package:flutter/material.dart';
import 'route_middleware.dart';

/// 路由观察者
/// 
/// 用于监听路由变化并触发中间件
class AppRouteObserver extends NavigatorObserver {
  final List<RouteMiddleware> _middlewares;
  
  AppRouteObserver(this._middlewares);
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    
    // 执行所有中间件的afterEnter方法
    for (final middleware in _middlewares) {
      middleware.afterEnter(route, route.settings);
    }
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    
    if (newRoute != null) {
      // 执行所有中间件的afterEnter方法
      for (final middleware in _middlewares) {
        middleware.afterEnter(newRoute, newRoute.settings);
      }
    }
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    if (previousRoute != null) {
      // 当路由弹出时，执行所有中间件的afterEnter方法，因为我们回到了之前的路由
      for (final middleware in _middlewares) {
        middleware.afterEnter(previousRoute, previousRoute.settings);
      }
    }
  }
} 