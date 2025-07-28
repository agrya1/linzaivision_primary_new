import 'package:flutter/material.dart';
import 'route_middleware.dart';

/// 路由参数中间件
/// 
/// 用于优化页面传参机制，支持类型安全的参数传递和参数验证
class RouteParamsMiddleware extends RouteMiddleware {
  /// 路由参数验证器映射表
  final Map<String, ParamValidator> _validators;
  
  /// 参数转换器映射表
  final Map<String, ParamConverter> _converters;
  
  RouteParamsMiddleware({
    Map<String, ParamValidator>? validators,
    Map<String, ParamConverter>? converters,
  }) : 
    _validators = validators ?? {},
    _converters = converters ?? {};
  
  /// 添加参数验证器
  void addValidator(String routeName, ParamValidator validator) {
    _validators[routeName] = validator;
  }
  
  /// 添加参数转换器
  void addConverter(String routeName, ParamConverter converter) {
    _converters[routeName] = converter;
  }
  
  @override
  bool beforeEnter(RouteSettings settings) {
    if (settings.name == null) return true;
    
    // 检查是否有对应的验证器
    final validator = _validators[settings.name];
    if (validator != null && settings.arguments != null) {
      // 执行参数验证
      final validationResult = validator(settings.arguments);
      if (!validationResult.isValid) {
        // 参数验证失败，输出错误信息
        debugPrint('路由参数验证失败: ${settings.name} - ${validationResult.errorMessage}');
        return false;
      }
    }
    
    return true;
  }
  
  @override
  void afterEnter(Route route, RouteSettings settings) {
    if (settings.name == null) return;
    
    // 检查是否有对应的转换器
    final converter = _converters[settings.name];
    if (converter != null && settings.arguments != null) {
      // 执行参数转换
      try {
        final convertedParams = converter(settings.arguments);
        
        // 如果是MaterialPageRoute，尝试更新路由参数
        if (route is MaterialPageRoute) {
          final updatedSettings = RouteSettings(
            name: settings.name,
            arguments: convertedParams,
          );
          
          // 使用反射或其他方式更新路由参数
          // 注意：这里只是示例，实际上MaterialPageRoute的settings是final的，不能直接修改
          // 需要使用自定义路由类来支持参数转换
          debugPrint('参数已转换: ${settings.name} - $convertedParams');
        }
      } catch (e) {
        debugPrint('参数转换失败: ${settings.name} - $e');
      }
    }
  }
}

/// 参数验证器
/// 
/// 用于验证路由参数是否符合要求
typedef ParamValidator = ValidationResult Function(dynamic params);

/// 参数转换器
/// 
/// 用于将路由参数转换为目标类型
typedef ParamConverter = dynamic Function(dynamic params);

/// 验证结果
class ValidationResult {
  /// 是否验证通过
  final bool isValid;
  
  /// 错误消息
  final String? errorMessage;
  
  ValidationResult({required this.isValid, this.errorMessage});
  
  /// 创建验证通过的结果
  factory ValidationResult.valid() {
    return ValidationResult(isValid: true);
  }
  
  /// 创建验证失败的结果
  factory ValidationResult.invalid(String errorMessage) {
    return ValidationResult(isValid: false, errorMessage: errorMessage);
  }
} 