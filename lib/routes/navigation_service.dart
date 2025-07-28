import 'package:flutter/material.dart';

/// 导航服务
/// 
/// 提供全局导航功能，可以在任何地方进行导航操作
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  
  /// 全局导航键
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// 获取单例实例
  factory NavigationService() {
    return _instance;
  }
  
  NavigationService._internal();
  
  /// 获取当前上下文
  BuildContext? get currentContext => navigatorKey.currentContext;
  
  /// 获取当前路由名称
  String? get currentRoute {
    String? routeName;
    navigatorKey.currentState?.popUntil((route) {
      routeName = route.settings.name;
      return true;
    });
    return routeName;
  }
  
  /// 导航到指定路由
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }
  
  /// 替换当前路由
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
      routeName,
      arguments: arguments,
    );
  }
  
  /// 导航到指定路由，并清除之前的路由
  Future<T?> navigateToAndRemoveUntil<T>(String routeName, {Object? arguments, String? untilRouteName}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
      routeName,
      untilRouteName == null
          ? (Route<dynamic> route) => false
          : ModalRoute.withName(untilRouteName),
      arguments: arguments,
    );
  }
  
  /// 返回上一页
  void goBack<T>({T? result}) {
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop<T>(result);
    }
  }
  
  /// 返回到指定路由
  void goBackToRoute(String routeName) {
    navigatorKey.currentState!.popUntil(ModalRoute.withName(routeName));
  }
} 