import 'package:flutter/material.dart';

/// 类型安全的路由
/// 
/// 支持类型安全的参数传递
class TypedRoute<T> {
  /// 路由名称
  final String name;
  
  /// 路由参数构造器
  final T Function() createDefaultArgs;
  
  /// 构造函数
  const TypedRoute({
    required this.name,
    required this.createDefaultArgs,
  });
  
  /// 创建路由设置
  RouteSettings createSettings({T? arguments}) {
    return RouteSettings(
      name: name,
      arguments: arguments ?? createDefaultArgs(),
    );
  }
  
  /// 导航到此路由
  Future<R?> push<R>(BuildContext context, {T? arguments}) {
    return Navigator.of(context).pushNamed<R>(
      name,
      arguments: arguments ?? createDefaultArgs(),
    );
  }
  
  /// 替换当前路由
  Future<R?> pushReplacement<R>(BuildContext context, {T? arguments}) {
    return Navigator.of(context).pushReplacementNamed<R, dynamic>(
      name,
      arguments: arguments ?? createDefaultArgs(),
    );
  }
  
  /// 导航到此路由，并清除之前的路由
  Future<R?> pushAndRemoveUntil<R>(BuildContext context, {T? arguments, RoutePredicate? predicate}) {
    return Navigator.of(context).pushNamedAndRemoveUntil<R>(
      name,
      predicate ?? (route) => false,
      arguments: arguments ?? createDefaultArgs(),
    );
  }
}

/// 无参数的路由
class NoArgsRoute {
  /// 路由名称
  final String name;
  
  /// 构造函数
  const NoArgsRoute({required this.name});
  
  /// 创建路由设置
  RouteSettings createSettings() {
    return RouteSettings(name: name);
  }
  
  /// 导航到此路由
  Future<R?> push<R>(BuildContext context) {
    return Navigator.of(context).pushNamed<R>(name);
  }
  
  /// 替换当前路由
  Future<R?> pushReplacement<R>(BuildContext context) {
    return Navigator.of(context).pushReplacementNamed<R, dynamic>(name);
  }
  
  /// 导航到此路由，并清除之前的路由
  Future<R?> pushAndRemoveUntil<R>(BuildContext context, {RoutePredicate? predicate}) {
    return Navigator.of(context).pushNamedAndRemoveUntil<R>(
      name,
      predicate ?? (route) => false,
    );
  }
}

/// 类型安全的路由参数获取扩展
extension TypedRouteArgs on BuildContext {
  /// 获取类型安全的路由参数
  T? getRouteArgs<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    if (args is T) {
      return args;
    }
    return null;
  }
  
  /// 获取类型安全的路由参数，如果类型不匹配则抛出异常
  T getTypedRouteArgs<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    if (args is T) {
      return args;
    }
    throw ArgumentError('路由参数类型不匹配，期望 $T，实际为 ${args?.runtimeType}');
  }
} 