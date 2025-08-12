import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_init/app_init_bloc.dart';
import '../bloc/app_init/app_init_state.dart';
import '../bloc/app_init/app_init_event.dart';
import 'progress_indicators/unified_progress_indicator.dart';

/// 应用初始化界面
/// 显示应用启动时的初始化进度和状态
class AppInitScreen extends StatelessWidget {
  const AppInitScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: BlocConsumer<AppInitBloc, AppInitState>(
        listener: (context, state) {
          if (state is AppInitSuccess) {
            // 初始化成功，导航到主界面
            _navigateToMainApp(context);
          } else if (state is AppInitFailure && !state.isRetryable) {
            // 不可重试的错误，显示错误对话框
            _showFatalErrorDialog(context, state);
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 应用Logo
                  _buildAppLogo(),

                  const SizedBox(height: 48),

                  // 状态内容
                  _buildStateContent(context, state),

                  const SizedBox(height: 32),

                  // 操作按钮
                  _buildActionButtons(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建应用Logo
  Widget _buildAppLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.visibility,
        size: 60,
        color: Colors.blue,
      ),
    );
  }

  /// 构建状态内容
  Widget _buildStateContent(BuildContext context, AppInitState state) {
    if (state is AppInitInitial) {
      return _buildInitialContent();
    } else if (state is AppInitInProgress) {
      return _buildProgressContent(state);
    } else if (state is AppInitSuccess) {
      return _buildSuccessContent(state);
    } else if (state is AppInitFailure) {
      return _buildFailureContent(state);
    } else if (state is AppInitRetrying) {
      return _buildRetryingContent(state);
    } else {
      return _buildInitialContent();
    }
  }

  /// 构建初始内容
  Widget _buildInitialContent() {
    return const Column(
      children: [
        Text(
          'LinzaiVision',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '临在意识',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 32),
        UnifiedProgressIndicator(
          type: ProgressIndicatorType.circular,
          size: ProgressIndicatorSize.medium,
          showPercentage: false,
          primaryColor: Colors.white,
        ),
        SizedBox(height: 16),
        Text(
          '正在启动应用...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// 构建进度内容
  Widget _buildProgressContent(AppInitInProgress state) {
    return Column(
      children: [
        Text(
          'LinzaiVision',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          state.phaseDescription,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 32),

        // 统一进度指示器
        UnifiedProgressIndicator(
          type: ProgressIndicatorType.circular,
          size: ProgressIndicatorSize.large,
          showPercentage: true,
          showTaskCount: false,
          message: state.currentMessage,
          primaryColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
        ),

        const SizedBox(height: 8),

        // 当前任务
        Text(
          state.currentMessage,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // 任务统计
        _buildTaskStats(state),
      ],
    );
  }

  /// 构建任务统计
  Widget _buildTaskStats(AppInitInProgress state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
            '已完成', state.completedTasks.length.toString(), Colors.green),
        _buildStatItem('进行中', (state.phaseData['activeTasks'] ?? 0).toString(),
            Colors.blue),
        _buildStatItem('失败', state.failedTasks.length.toString(), Colors.red),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// 构建成功内容
  Widget _buildSuccessContent(AppInitSuccess state) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        const Text(
          '初始化完成',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '耗时: ${state.totalDuration.inSeconds}秒',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '完成任务: ${state.completedTasks.length}个',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// 构建失败内容
  Widget _buildFailureContent(AppInitFailure state) {
    return Column(
      children: [
        Icon(
          Icons.error,
          size: 80,
          color: Colors.red[300],
        ),
        const SizedBox(height: 16),
        const Text(
          '初始化失败',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.userFriendlyMessage,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '错误详情: ${state.error}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 构建重试内容
  Widget _buildRetryingContent(AppInitRetrying state) {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
        const SizedBox(height: 16),
        const Text(
          '正在重试...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '第 ${state.retryCount} 次重试',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        if (state.remainingDelay.inSeconds > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${state.remainingDelay.inSeconds}秒后重试',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context, AppInitState state) {
    if (state is AppInitFailure && state.isRetryable) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => _retryInitialization(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('重试'),
          ),
          TextButton(
            onPressed: () => _skipToMainApp(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('跳过'),
          ),
        ],
      );
    } else if (state is AppInitInProgress) {
      return TextButton(
        onPressed: () => _cancelInitialization(context),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
        ),
        child: const Text('取消'),
      );
    }

    return const SizedBox.shrink();
  }

  /// 重试初始化
  void _retryInitialization(BuildContext context) {
    context.read<AppInitBloc>().add(const RetryInitialization());
  }

  /// 取消初始化
  void _cancelInitialization(BuildContext context) {
    context.read<AppInitBloc>().add(const CancelInitialization(
          reason: '用户取消',
        ));
  }

  /// 跳过到主应用
  void _skipToMainApp(BuildContext context) {
    _navigateToMainApp(context);
  }

  /// 导航到主应用
  void _navigateToMainApp(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/main');
  }

  /// 显示致命错误对话框
  void _showFatalErrorDialog(BuildContext context, AppInitFailure state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('严重错误'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.userFriendlyMessage),
            const SizedBox(height: 16),
            const Text('建议操作:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...state.recoveryActions.map((action) => Text('• $action')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
