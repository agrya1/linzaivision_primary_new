import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/loading/loading_bloc.dart';
import '../../bloc/loading/loading_state.dart';
import '../../bloc/loading/loading_event.dart';
import 'unified_progress_indicator.dart';

/// 智能加载反馈类型
enum LoadingFeedbackType {
  overlay, // 覆盖层
  inline, // 内联显示
  snackbar, // 底部提示
  dialog, // 对话框
  bottomSheet, // 底部弹窗
}

/// 反馈触发条件
class FeedbackTrigger {
  final Duration? minDuration; // 最小显示时长
  final Duration? maxDuration; // 最大显示时长
  final double? progressThreshold; // 进度阈值
  final int? taskCountThreshold; // 任务数量阈值
  final LoadingPriority? priorityThreshold; // 优先级阈值
  final bool showOnError; // 错误时显示
  final bool showOnSuccess; // 成功时显示

  const FeedbackTrigger({
    this.minDuration,
    this.maxDuration,
    this.progressThreshold,
    this.taskCountThreshold,
    this.priorityThreshold,
    this.showOnError = true,
    this.showOnSuccess = false,
  });
}

/// 智能加载反馈组件
/// 根据加载状态和用户行为智能选择反馈方式
class SmartLoadingFeedback extends StatefulWidget {
  final Widget child;
  final LoadingFeedbackType type;
  final FeedbackTrigger trigger;
  final bool autoHide;
  final Duration autoHideDuration;
  final String? customMessage;
  final Widget? customIndicator;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const SmartLoadingFeedback({
    Key? key,
    required this.child,
    this.type = LoadingFeedbackType.overlay,
    this.trigger = const FeedbackTrigger(),
    this.autoHide = true,
    this.autoHideDuration = const Duration(seconds: 3),
    this.customMessage,
    this.customIndicator,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<SmartLoadingFeedback> createState() => _SmartLoadingFeedbackState();
}

class _SmartLoadingFeedbackState extends State<SmartLoadingFeedback>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isVisible = false;
  DateTime? _showStartTime;
  DateTime? _loadingStartTime;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoadingBloc, LoadingBlocState>(
      listener: (context, state) {
        _handleStateChange(state);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isVisible) _buildFeedbackWidget(context),
        ],
      ),
    );
  }

  void _handleStateChange(LoadingBlocState state) {
    final shouldShow = _shouldShowFeedback(state);

    if (shouldShow && !_isVisible) {
      _showFeedback();
    } else if (!shouldShow && _isVisible) {
      _hideFeedback();
    }

    // 记录加载开始时间
    if (state.isLoading && _loadingStartTime == null) {
      _loadingStartTime = DateTime.now();
    } else if (!state.isLoading) {
      _loadingStartTime = null;
    }
  }

  bool _shouldShowFeedback(LoadingBlocState state) {
    // 检查基本条件
    if (!state.isLoading && state.failedTasks.isEmpty) {
      return false;
    }

    // 检查最小持续时间
    if (widget.trigger.minDuration != null && _loadingStartTime != null) {
      final elapsed = DateTime.now().difference(_loadingStartTime!);
      if (elapsed < widget.trigger.minDuration!) {
        return false;
      }
    }

    // 检查进度阈值
    if (widget.trigger.progressThreshold != null) {
      if (state.overallProgress < widget.trigger.progressThreshold!) {
        return false;
      }
    }

    // 检查任务数量阈值
    if (widget.trigger.taskCountThreshold != null) {
      if (state.activeTasks.length < widget.trigger.taskCountThreshold!) {
        return false;
      }
    }

    // 检查优先级阈值
    if (widget.trigger.priorityThreshold != null &&
        state.currentPriority != null) {
      final currentPriorityIndex =
          LoadingPriority.values.indexOf(state.currentPriority!);
      final thresholdIndex =
          LoadingPriority.values.indexOf(widget.trigger.priorityThreshold!);
      if (currentPriorityIndex > thresholdIndex) {
        return false;
      }
    }

    // 检查错误和成功条件
    if (state.failedTasks.isNotEmpty && !widget.trigger.showOnError) {
      return false;
    }

    if (!state.isLoading &&
        state.failedTasks.isEmpty &&
        !widget.trigger.showOnSuccess) {
      return false;
    }

    return true;
  }

  void _showFeedback() {
    if (!mounted) return;

    setState(() {
      _isVisible = true;
      _showStartTime = DateTime.now();
    });

    _fadeController.forward();
    _slideController.forward();

    // 自动隐藏
    if (widget.autoHide) {
      Future.delayed(widget.autoHideDuration, () {
        if (mounted && _isVisible) {
          _hideFeedback();
        }
      });
    }
  }

  void _hideFeedback() {
    if (!mounted) return;

    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
          _showStartTime = null;
        });
      }
    });
    _slideController.reverse();

    widget.onDismiss?.call();
  }

  Widget _buildFeedbackWidget(BuildContext context) {
    switch (widget.type) {
      case LoadingFeedbackType.overlay:
        return _buildOverlay(context);
      case LoadingFeedbackType.inline:
        return _buildInline(context);
      case LoadingFeedbackType.snackbar:
        return _buildSnackbar(context);
      case LoadingFeedbackType.dialog:
        return _buildDialog(context);
      case LoadingFeedbackType.bottomSheet:
        return _buildBottomSheet(context);
    }
  }

  Widget _buildOverlay(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildContent(context, compact: true),
        ),
      ),
    );
  }

  Widget _buildSnackbar(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildContent(context, compact: true),
        ),
      ),
    );
  }

  Widget _buildDialog(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {bool compact = false}) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度指示器
              widget.customIndicator ??
                  UnifiedProgressIndicator(
                    type: compact
                        ? ProgressIndicatorType.linear
                        : ProgressIndicatorType.circular,
                    size: compact
                        ? ProgressIndicatorSize.small
                        : ProgressIndicatorSize.medium,
                    showPercentage: !compact,
                    showTaskCount: !compact,
                    message: widget.customMessage,
                  ),

              if (!compact) ...[
                const SizedBox(height: 16),

                // 详细信息
                if (state.failedTasks.isNotEmpty) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.failedTasks.length} 个任务失败',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // 操作按钮
                if (state.failedTasks.isNotEmpty) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          context
                              .read<LoadingBloc>()
                              .add(const RetryAllFailedTasks());
                          _hideFeedback();
                        },
                        child: const Text('重试'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _hideFeedback,
                        child: const Text('忽略'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
