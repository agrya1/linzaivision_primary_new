import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../models/user.dart';
import '../../utils/performance_utils.dart';

/// AuthPage BLoC适配器
/// 
/// 这个类作为现有登录页面和新的BLoC架构之间的桥梁，实现渐进式重构。
/// 它不会直接替换现有功能，而是并行运行，逐步验证并最终替换。
class AuthPageBlocAdapter {
  final BuildContext context;
  
  // 日志级别，用于控制日志输出详细程度
  // 0: 不输出日志, 1: 只输出关键日志, 2: 输出详细日志, 3: 输出调试日志
  final int logLevel;
  
  // 执行模式，控制是否真正执行操作或只是记录日志
  // false: 只记录日志不执行, true: 执行操作
  final bool executeMode;
  
  // 性能监控开关
  final bool enablePerformanceMonitoring;
  
  // 构造函数
  AuthPageBlocAdapter(this.context, {
    this.logLevel = 2,
    this.executeMode = false,
    this.enablePerformanceMonitoring = true,
  });
  
  /// 使用验证码登录
  /// 
  /// 参数:
  /// - phone: 手机号
  /// - code: 验证码
  /// - onSuccess: 登录成功回调
  /// - onError: 登录失败回调
  Future<bool> loginWithCode({
    required String phone,
    required String code,
    Function(User user)? onSuccess,
    Function(String error)? onError,
  }) async {
    _log(1, '【影子模式】验证码登录: phone=$phone');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return false;
    }
    
    try {
      // 开始性能监控
      final operationId = 'loginWithCode_${phone.hashCode}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取AuthBloc实例
      final authBloc = BlocProvider.of<AuthBloc>(context);
      
      // 创建一个Completer，用于异步等待登录结果
      final completer = Completer<bool>();
      
      // 声明监听器变量
      late final StreamSubscription<AuthState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = authBloc.stream.listen((state) {
        if (state is AuthAuthenticated) {
          _log(1, '【影子模式】登录成功: ${state.user.username}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call(state.user);
          if (!completer.isCompleted) {
            completer.complete(true);
          }
          subscription.cancel();
        } else if (state is AuthError) {
          _log(1, '【影子模式】登录失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          subscription.cancel();
        }
      });
      
      // 发送登录事件
      authBloc.add(LoginEvent(phone, code));
      _log(2, '【影子模式】已发送LoginEvent事件');
      
      // 等待登录结果
      return await completer.future;
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('登录失败: $e');
      return false;
    }
  }
  
  /// 登出
  /// 
  /// 参数:
  /// - onSuccess: 登出成功回调
  /// - onError: 登出失败回调
  Future<bool> logout({
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) async {
    _log(1, '【影子模式】登出');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return false;
    }
    
    try {
      // 开始性能监控
      final operationId = 'logout';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取AuthBloc实例
      final authBloc = BlocProvider.of<AuthBloc>(context);
      
      // 创建一个Completer，用于异步等待登出结果
      final completer = Completer<bool>();
      
      // 声明监听器变量
      late final StreamSubscription<AuthState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = authBloc.stream.listen((state) {
        if (state is AuthUnauthenticated) {
          _log(1, '【影子模式】登出成功');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
          subscription.cancel();
        } else if (state is AuthError) {
          _log(1, '【影子模式】登出失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          subscription.cancel();
        }
      });
      
      // 发送登出事件
      authBloc.add(LogoutEvent());
      _log(2, '【影子模式】已发送LogoutEvent事件');
      
      // 等待登出结果
      return await completer.future;
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('登出失败: $e');
      return false;
    }
  }
  
  /// 检查登录状态
  /// 
  /// 参数:
  /// - onAuthenticated: 已登录回调
  /// - onUnauthenticated: 未登录回调
  /// - onError: 检查失败回调
  void checkAuthStatus({
    Function(User user)? onAuthenticated,
    VoidCallback? onUnauthenticated,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】检查登录状态');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'checkAuthStatus';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取AuthBloc实例
      final authBloc = BlocProvider.of<AuthBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<AuthState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = authBloc.stream.listen((state) {
        if (state is AuthAuthenticated) {
          _log(1, '【影子模式】已登录: ${state.user.username}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onAuthenticated?.call(state.user);
          subscription.cancel();
        } else if (state is AuthUnauthenticated) {
          _log(1, '【影子模式】未登录');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onUnauthenticated?.call();
          subscription.cancel();
        } else if (state is AuthError) {
          _log(1, '【影子模式】检查登录状态失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送检查登录状态事件
      authBloc.add(CheckAuthStatusEvent());
      _log(2, '【影子模式】已发送CheckAuthStatusEvent事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('检查登录状态失败: $e');
    }
  }
  
  /// 获取性能统计数据
  /// 
  /// 返回各操作的性能统计信息
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    final result = <String, Map<String, dynamic>>{};
    
    // 获取所有操作的统计信息
    final operations = [
      'loginWithCode',
      'logout',
      'checkAuthStatus',
    ];
    
    for (final operation in operations) {
      result[operation] = PerformanceUtils.getOperationStats(operation);
    }
    
    return result;
  }
  
  /// 输出性能统计信息
  void printPerformanceStats() {
    if (!enablePerformanceMonitoring) {
      _log(1, '【影子模式】性能监控未启用');
      return;
    }
    
    PerformanceUtils.printAllStats();
  }
  
  /// 记录日志
  /// 
  /// 参数:
  /// - level: 日志级别
  /// - message: 日志消息
  void _log(int level, String message) {
    if (level <= logLevel) {
      debugPrint(message);
    }
  }
} 