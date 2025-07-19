import 'package:flutter/material.dart';

/// 统一错误处理工具类
class ErrorHandler {
  /// 运行带错误处理的操作
  static Future<T> runWithErrorHandling<T>(
    Future<T> Function() operation,
    void Function(String message) onError,
  ) async {
    try {
      return await operation();
    } catch (e) {
      final errorMessage = _formatErrorMessage(e);
      onError(errorMessage);
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
  }) {
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
    String message,
  ) {
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