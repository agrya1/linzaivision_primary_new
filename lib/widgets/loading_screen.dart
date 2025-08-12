import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loading/loading_bloc.dart';
import '../bloc/loading/loading_state.dart';
import '../bloc/loading/loading_event.dart';

/// 统一的加载屏幕组件
class LoadingScreen extends StatelessWidget {
  final LoadingBlocState loadingState;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final bool showDetailedProgress;
  final bool showTaskList;
  final String? customMessage;
  
  const LoadingScreen({
    Key? key,
    required this.loadingState,
    this.onRetry,
    this.onCancel,
    this.showDetailedProgress = false,
    this.showTaskList = false,
    this.customMessage,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 应用Logo或图标
              _buildLogo(context),
              
              const SizedBox(height: 32),
              
              // 主要加载指示器
              _buildMainLoadingIndicator(context),
              
              const SizedBox(height: 24),
              
              // 加载消息
              _buildLoadingMessage(context),
              
              const SizedBox(height: 16),
              
              // 进度百分比
              _buildProgressPercentage(context),
              
              if (showDetailedProgress) ...[
                const SizedBox(height: 24),
                _buildDetailedProgress(context),
              ],
              
              if (showTaskList) ...[
                const SizedBox(height: 24),
                _buildTaskList(context),
              ],
              
              // 错误处理和操作按钮
              if (loadingState.failedTasks.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildErrorSection(context),
              ],
              
              const SizedBox(height: 24),
              
              // 取消按钮（如果允许）
              if (onCancel != null)
                _buildCancelButton(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogo(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.psychology,
        size: 40,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildMainLoadingIndicator(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).dividerColor,
              ),
            ),
          ),
          // 进度圆环
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: loadingState.overallProgress,
              strokeWidth: 4,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(context, loadingState.overallProgress),
              ),
            ),
          ),
          // 中心图标
          Icon(
            _getProgressIcon(),
            size: 24,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingMessage(BuildContext context) {
    final message = customMessage ?? 
                   loadingState.currentMessage ?? 
                   _getDefaultMessage();
    
    return Text(
      message,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
  
  Widget _buildProgressPercentage(BuildContext context) {
    final percentage = (loadingState.overallProgress * 100).toInt();
    
    return Text(
      '$percentage%',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Widget _buildDetailedProgress(BuildContext context) {
    final stats = loadingState.loadingStats;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '详细进度',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildProgressRow(context, '已完成', stats['success'] ?? 0, Colors.green),
          _buildProgressRow(context, '进行中', stats['inProgress'] ?? 0, Colors.blue),
          _buildProgressRow(context, '等待中', stats['idle'] ?? 0, Colors.grey),
          _buildProgressRow(context, '失败', stats['error'] ?? 0, Colors.red),
        ],
      ),
    );
  }
  
  Widget _buildProgressRow(BuildContext context, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskList(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '任务列表',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...loadingState.taskStates.entries.map((entry) {
              return _buildTaskItem(context, entry.key, entry.value);
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTaskItem(BuildContext context, String taskId, LoadingState state) {
    IconData icon;
    Color color;
    String status;
    
    if (state is LoadingSuccess) {
      icon = Icons.check_circle;
      color = Colors.green;
      status = '已完成';
    } else if (state is LoadingInProgress) {
      icon = Icons.hourglass_empty;
      color = Colors.blue;
      status = '进行中';
    } else if (state is LoadingError) {
      icon = Icons.error;
      color = Colors.red;
      status = '失败';
    } else if (state is LoadingCancelled) {
      icon = Icons.cancel;
      color = Colors.orange;
      status = '已取消';
    } else {
      icon = Icons.schedule;
      color = Colors.grey;
      status = '等待中';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              taskId,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '部分任务执行失败',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  context.read<LoadingBloc>().add(const RetryAllFailedTasks());
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试失败任务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              if (onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重新开始'),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCancelButton(BuildContext context) {
    return TextButton.icon(
      onPressed: onCancel,
      icon: const Icon(Icons.close, size: 16),
      label: const Text('取消'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }
  
  Color _getProgressColor(BuildContext context, double progress) {
    if (progress < 0.3) {
      return Colors.orange;
    } else if (progress < 0.7) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }
  
  IconData _getProgressIcon() {
    final progress = loadingState.overallProgress;
    
    if (loadingState.failedTasks.isNotEmpty) {
      return Icons.warning;
    } else if (progress >= 1.0) {
      return Icons.check;
    } else if (loadingState.hasCriticalTasksLoading) {
      return Icons.priority_high;
    } else {
      return Icons.hourglass_empty;
    }
  }
  
  String _getDefaultMessage() {
    if (loadingState.failedTasks.isNotEmpty) {
      return '部分任务执行失败';
    } else if (loadingState.overallProgress >= 1.0) {
      return '加载完成';
    } else if (loadingState.hasCriticalTasksLoading) {
      return '正在加载关键数据...';
    } else {
      return '正在加载应用数据...';
    }
  }
}
