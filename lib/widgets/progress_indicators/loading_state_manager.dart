import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/loading/loading_bloc.dart';
import '../../bloc/loading/loading_state.dart';
import '../../bloc/loading/loading_event.dart';
import 'unified_progress_indicator.dart';
import 'smart_loading_feedback.dart';

/// 加载状态管理器配置
class LoadingStateConfig {
  final bool enableGlobalIndicator;
  final bool enableSmartFeedback;
  final bool enablePerformanceMonitoring;
  final Duration feedbackDelay;
  final Duration maxLoadingTime;
  final Map<LoadingPriority, ProgressIndicatorType> priorityIndicators;

  const LoadingStateConfig({
    this.enableGlobalIndicator = true,
    this.enableSmartFeedback = true,
    this.enablePerformanceMonitoring = true,
    this.feedbackDelay = const Duration(milliseconds: 500),
    this.maxLoadingTime = const Duration(minutes: 2),
    this.priorityIndicators = const {
      LoadingPriority.critical: ProgressIndicatorType.circular,
      LoadingPriority.high: ProgressIndicatorType.linear,
      LoadingPriority.normal: ProgressIndicatorType.dots,
      LoadingPriority.low: ProgressIndicatorType.skeleton,
      LoadingPriority.background: ProgressIndicatorType.skeleton,
    },
  });
}

/// 加载状态管理器
/// 统一管理应用中的所有加载状态和进度指示器
class LoadingStateManager extends StatefulWidget {
  final Widget child;
  final LoadingStateConfig config;
  final Widget? customGlobalIndicator;
  final Widget? customErrorWidget;
  final VoidCallback? onLoadingTimeout;
  final Function(LoadingBlocState)? onStateChange;

  const LoadingStateManager({
    Key? key,
    required this.child,
    this.config = const LoadingStateConfig(),
    this.customGlobalIndicator,
    this.customErrorWidget,
    this.onLoadingTimeout,
    this.onStateChange,
  }) : super(key: key);

  @override
  State<LoadingStateManager> createState() => _LoadingStateManagerState();
}

class _LoadingStateManagerState extends State<LoadingStateManager>
    with TickerProviderStateMixin {
  late AnimationController _globalIndicatorController;
  late AnimationController _errorShakeController;
  late Animation<double> _errorShakeAnimation;

  DateTime? _loadingStartTime;
  bool _hasShownTimeoutWarning = false;

  @override
  void initState() {
    super.initState();
    _globalIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _errorShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorShakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _errorShakeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _globalIndicatorController.dispose();
    _errorShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoadingBloc, LoadingBlocState>(
      listener: (context, state) {
        _handleStateChange(state);
        widget.onStateChange?.call(state);
      },
      child: Stack(
        children: [
          // 主要内容
          widget.child,

          // 全局进度指示器
          if (widget.config.enableGlobalIndicator)
            _buildGlobalIndicator(context),

          // 智能反馈系统
          if (widget.config.enableSmartFeedback) _buildSmartFeedback(context),

          // 错误提示
          _buildErrorIndicator(context),
        ],
      ),
    );
  }

  void _handleStateChange(LoadingBlocState state) {
    // 处理加载开始
    if (state.isLoading && _loadingStartTime == null) {
      _loadingStartTime = DateTime.now();
      _hasShownTimeoutWarning = false;
      _globalIndicatorController.forward();
    }

    // 处理加载结束
    if (!state.isLoading && _loadingStartTime != null) {
      _loadingStartTime = null;
      _globalIndicatorController.reverse();
    }

    // 处理错误
    if (state.failedTasks.isNotEmpty) {
      _errorShakeController.forward().then((_) {
        _errorShakeController.reset();
      });
    }

    // 检查超时
    if (widget.config.enablePerformanceMonitoring) {
      _checkLoadingTimeout(state);
    }
  }

  void _checkLoadingTimeout(LoadingBlocState state) {
    if (_loadingStartTime == null || !state.isLoading) return;

    final elapsed = DateTime.now().difference(_loadingStartTime!);

    // 检查是否超时
    if (elapsed > widget.config.maxLoadingTime && !_hasShownTimeoutWarning) {
      _hasShownTimeoutWarning = true;
      widget.onLoadingTimeout?.call();

      // 显示超时警告
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('加载时间较长，请检查网络连接'),
            action: SnackBarAction(
              label: '取消',
              onPressed: () {
                context.read<LoadingBloc>().add(const CancelAllTasks());
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildGlobalIndicator(BuildContext context) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, state) {
        if (!state.isLoading) return const SizedBox.shrink();

        final indicatorType =
            _getIndicatorTypeForPriority(state.currentPriority);

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: AnimatedBuilder(
            animation: _globalIndicatorController,
            builder: (context, child) {
              return Transform.scale(
                scale: _globalIndicatorController.value,
                child: Opacity(
                  opacity: _globalIndicatorController.value,
                  child: widget.customGlobalIndicator ??
                      UnifiedProgressIndicator(
                        type: indicatorType,
                        size: ProgressIndicatorSize.small,
                        showPercentage: false,
                        showTaskCount: false,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSmartFeedback(BuildContext context) {
    return SmartLoadingFeedback(
      type: LoadingFeedbackType.snackbar,
      trigger: FeedbackTrigger(
        minDuration: widget.config.feedbackDelay,
        taskCountThreshold: 3,
        priorityThreshold: LoadingPriority.high,
        showOnError: true,
        showOnSuccess: false,
      ),
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildErrorIndicator(BuildContext context) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, state) {
        if (state.failedTasks.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _errorShakeAnimation,
            builder: (context, child) {
              final shake = _errorShakeAnimation.value;
              return Transform.translate(
                offset: Offset(shake * 10 * (1 - shake), 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: widget.customErrorWidget ??
                      Row(
                        children: [
                          const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${state.failedTasks.length} 个任务失败',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context
                                  .read<LoadingBloc>()
                                  .add(const RetryAllFailedTasks());
                            },
                            child: const Text(
                              '重试',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  ProgressIndicatorType _getIndicatorTypeForPriority(
      LoadingPriority? priority) {
    if (priority == null) return ProgressIndicatorType.circular;
    return widget.config.priorityIndicators[priority] ??
        ProgressIndicatorType.circular;
  }
}

/// 便捷的加载状态包装器
class LoadingWrapper extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final ProgressIndicatorType type;
  final ProgressIndicatorSize size;
  final bool overlay;

  const LoadingWrapper({
    Key? key,
    required this.child,
    this.isLoading = false,
    this.message,
    this.type = ProgressIndicatorType.circular,
    this.size = ProgressIndicatorSize.medium,
    this.overlay = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    if (overlay) {
      return Stack(
        children: [
          child,
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: UnifiedProgressIndicator(
                type: type,
                size: size,
                message: message,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          UnifiedProgressIndicator(
            type: type,
            size: size,
            message: message,
          ),
          const SizedBox(height: 16),
          child,
        ],
      );
    }
  }
}

/// 加载状态构建器
class LoadingStateBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, LoadingBlocState state) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, List<String> failedTasks)?
      errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;

  const LoadingStateBuilder({
    Key? key,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, state) {
        // 错误状态
        if (state.failedTasks.isNotEmpty && errorBuilder != null) {
          return errorBuilder!(context, state.failedTasks);
        }

        // 加载状态
        if (state.isLoading && loadingBuilder != null) {
          return loadingBuilder!(context);
        }

        // 空状态
        if (state.taskStates.isEmpty && emptyBuilder != null) {
          return emptyBuilder!(context);
        }

        // 正常状态
        return builder(context, state);
      },
    );
  }
}
