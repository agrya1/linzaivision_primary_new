import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

/// 统一错误处理工具类
class ErrorHandler {
  // 错误计数器
  static final Map<String, int> _errorCounts = {};
  
  // 错误日志
  static final List<ErrorLog> _errorLogs = [];
  
  // 最大日志数量
  static const int _maxLogCount = 100;
  
  /// 运行带错误处理的操作
  static Future<T> runWithErrorHandling<T>(
    Future<T> Function() operation,
    void Function(String message) onError, {
    String? operationName,
  }) async {
    try {
      return await operation();
    } catch (e) {
      final errorMessage = _formatErrorMessage(e);
      onError(errorMessage);
      
      // 记录错误
      _logError(operationName ?? 'unknown', errorMessage, e);
      
      rethrow;
    }
  }
  
  /// 格式化错误信息
  static String _formatErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    } else if (error is Exception) {
      return error.toString();
    } else {
      return '操作失败: $error';
    }
  }
  
  /// 显示错误对话框
  static void showErrorDialog(
    BuildContext context,
    String message, {
    String title = '错误',
    String? operationName,
  }) {
    // 记录错误
    if (operationName != null) {
      _logError(operationName, message, null);
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示错误提示
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    String? operationName,
  }) {
    // 记录错误
    if (operationName != null) {
      _logError(operationName, message, null);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// 显示成功提示
  static void showSuccessSnackBar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// 处理网络错误
  static String handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return '网络连接失败，请检查网络设置';
    } else if (error.toString().contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    } else {
      return '网络错误: $error';
    }
  }
  
  /// 处理数据库错误
  static String handleDatabaseError(dynamic error) {
    if (error.toString().contains('SQLiteException')) {
      return '数据库操作失败，请重试';
    } else if (error.toString().contains('ConstraintException')) {
      return '数据约束冲突，请检查输入';
    } else {
      return '数据库错误: $error';
    }
  }
  
  /// 处理文件操作错误
  static String handleFileError(dynamic error) {
    if (error.toString().contains('FileSystemException')) {
      return '文件操作失败，请检查权限';
    } else if (error.toString().contains('PermissionException')) {
      return '权限不足，请授予必要权限';
    } else {
      return '文件错误: $error';
    }
  }
  
  /// 记录错误
  static void _logError(String operation, String message, dynamic error) {
    // 增加错误计数
    _errorCounts[operation] = (_errorCounts[operation] ?? 0) + 1;
    
    // 添加错误日志
    _errorLogs.add(ErrorLog(
      operation: operation,
      message: message,
      error: error,
      timestamp: DateTime.now(),
    ));
    
    // 限制日志数量
    if (_errorLogs.length > _maxLogCount) {
      _errorLogs.removeAt(0);
    }
    
    // 输出到控制台
    debugPrint('【错误】$operation: $message');
    if (error != null) {
      debugPrint('详情: $error');
    }
  }
  
  /// 获取错误统计
  static Map<String, int> getErrorCounts() {
    return Map.from(_errorCounts);
  }
  
  /// 获取错误日志
  static List<ErrorLog> getErrorLogs() {
    return List.from(_errorLogs);
  }
  
  /// 清除错误统计
  static void clearErrorCounts() {
    _errorCounts.clear();
  }
  
  /// 清除错误日志
  static void clearErrorLogs() {
    _errorLogs.clear();
  }
  
  /// 导出错误日志
  static Future<String> exportErrorLogs() async {
    try {
      final now = DateTime.now();
      final filename = 'error_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.txt';
      final directory = Directory('logs');
      
      // 创建日志目录
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // 创建日志文件
      final file = File('${directory.path}/$filename');
      final sink = file.openWrite();
      
      // 写入日志内容
      sink.writeln('错误日志导出时间: $now');
      sink.writeln('总错误数: ${_errorLogs.length}');
      sink.writeln('');
      
      for (final log in _errorLogs) {
        sink.writeln('时间: ${log.timestamp}');
        sink.writeln('操作: ${log.operation}');
        sink.writeln('消息: ${log.message}');
        if (log.error != null) {
          sink.writeln('详情: ${log.error}');
        }
        sink.writeln('-------------------');
      }
      
      await sink.close();
      
      return file.path;
    } catch (e) {
      debugPrint('导出错误日志失败: $e');
      return '';
    }
  }
  
  /// 显示错误统计对话框
  static void showErrorStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误统计'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总错误数: ${_errorLogs.length}'),
              const SizedBox(height: 16),
              const Text('错误类型统计:'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: _errorCounts.entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key),
                                Text('${entry.value}次'),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final path = await exportErrorLogs();
              if (path.isNotEmpty && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('错误日志已导出到: $path')),
                );
              }
            },
            child: const Text('导出日志'),
          ),
          TextButton(
            onPressed: () {
              clearErrorLogs();
              clearErrorCounts();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('错误统计已清除')),
              );
            },
            child: const Text('清除统计'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 错误日志类
class ErrorLog {
  final String operation;
  final String message;
  final dynamic error;
  final DateTime timestamp;
  
  ErrorLog({
    required this.operation,
    required this.message,
    this.error,
    required this.timestamp,
  });
}

/// 错误边界组件
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!);
      }
      return _defaultErrorWidget();
    }
    
    return widget.child;
  }
  
  Widget _defaultErrorWidget() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              '发生错误',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
} 