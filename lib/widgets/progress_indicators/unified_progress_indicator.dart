import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/loading/loading_bloc.dart';
import '../../bloc/loading/loading_state.dart';

/// 统一的进度指示器类型
enum ProgressIndicatorType {
  circular, // 圆形进度条
  linear, // 线性进度条
  wave, // 波浪动画
  dots, // 点状动画
  skeleton, // 骨架屏
  custom, // 自定义
}

/// 进度指示器大小
enum ProgressIndicatorSize {
  small, // 小尺寸 (24x24)
  medium, // 中等尺寸 (48x48)
  large, // 大尺寸 (72x72)
  extraLarge, // 超大尺寸 (96x96)
}

/// 统一的进度指示器组件
/// 根据加载状态自动选择合适的显示方式
class UnifiedProgressIndicator extends StatefulWidget {
  final ProgressIndicatorType type;
  final ProgressIndicatorSize size;
  final String? message;
  final bool showPercentage;
  final bool showTaskCount;
  final bool showElapsedTime;
  final Color? primaryColor;
  final Color? backgroundColor;
  final double? strokeWidth;
  final Duration animationDuration;
  final Widget? customIndicator;
  final VoidCallback? onTap;

  const UnifiedProgressIndicator({
    Key? key,
    this.type = ProgressIndicatorType.circular,
    this.size = ProgressIndicatorSize.medium,
    this.message,
    this.showPercentage = true,
    this.showTaskCount = false,
    this.showElapsedTime = false,
    this.primaryColor,
    this.backgroundColor,
    this.strokeWidth,
    this.animationDuration = const Duration(milliseconds: 300),
    this.customIndicator,
    this.onTap,
  }) : super(key: key);

  @override
  State<UnifiedProgressIndicator> createState() =>
      _UnifiedProgressIndicatorState();
}

class _UnifiedProgressIndicatorState extends State<UnifiedProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, state) {
        // 记录开始时间
        if (state.isLoading && _startTime == null) {
          _startTime = DateTime.now();
        } else if (!state.isLoading) {
          _startTime = null;
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: _buildProgressIndicator(context, state),
        );
      },
    );
  }

  Widget _buildProgressIndicator(BuildContext context, LoadingBlocState state) {
    switch (widget.type) {
      case ProgressIndicatorType.circular:
        return _buildCircularIndicator(context, state);
      case ProgressIndicatorType.linear:
        return _buildLinearIndicator(context, state);
      case ProgressIndicatorType.wave:
        return _buildWaveIndicator(context, state);
      case ProgressIndicatorType.dots:
        return _buildDotsIndicator(context, state);
      case ProgressIndicatorType.skeleton:
        return _buildSkeletonIndicator(context, state);
      case ProgressIndicatorType.custom:
        return widget.customIndicator ??
            _buildCircularIndicator(context, state);
    }
  }

  Widget _buildCircularIndicator(BuildContext context, LoadingBlocState state) {
    final size = _getIndicatorSize();
    final progress = state.overallProgress;
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).dividerColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圆环
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: widget.strokeWidth ?? _getStrokeWidth(),
                  backgroundColor: backgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
                ),
              ),
              // 进度圆环
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: state.isLoading ? _pulseAnimation.value : 1.0,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: widget.strokeWidth ?? _getStrokeWidth(),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(context, progress, state),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // 中心内容
              _buildCenterContent(context, state, size),
            ],
          ),
        ),
        if (_shouldShowMessage(state)) ...[
          const SizedBox(height: 8),
          _buildMessage(context, state),
        ],
        if (widget.showTaskCount) ...[
          const SizedBox(height: 4),
          _buildTaskCount(context, state),
        ],
        if (widget.showElapsedTime && _startTime != null) ...[
          const SizedBox(height: 4),
          _buildElapsedTime(context),
        ],
      ],
    );
  }

  Widget _buildLinearIndicator(BuildContext context, LoadingBlocState state) {
    final progress = state.overallProgress;
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).dividerColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_shouldShowMessage(state)) ...[
          _buildMessage(context, state),
          const SizedBox(height: 8),
        ],
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(context, progress, state),
              ),
            ),
          ),
        ),
        if (widget.showPercentage || widget.showTaskCount) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.showPercentage)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (widget.showTaskCount) _buildTaskCount(context, state),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWaveIndicator(BuildContext context, LoadingBlocState state) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: _getIndicatorSize(),
          height: _getIndicatorSize(),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.primaryColor ?? Theme.of(context).primaryColor)
                .withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(
              _getStatusIcon(state),
              size: _getIndicatorSize() * 0.4,
              color: widget.primaryColor ?? Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotsIndicator(BuildContext context, LoadingBlocState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final delay = index * 0.2;
            final animValue = (_animationController.value + delay) % 1.0;
            final scale = 0.5 + (0.5 * (1 - (animValue - 0.5).abs() * 2));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        widget.primaryColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSkeletonIndicator(BuildContext context, LoadingBlocState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _getIndicatorSize(),
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: _getIndicatorSize() * 0.7,
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterContent(
      BuildContext context, LoadingBlocState state, double size) {
    if (widget.showPercentage) {
      final percentage = (state.overallProgress * 100).toInt();
      return Text(
        '$percentage%',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: size * 0.15,
            ),
      );
    } else {
      return Icon(
        _getStatusIcon(state),
        size: size * 0.3,
        color: widget.primaryColor ?? Theme.of(context).primaryColor,
      );
    }
  }

  Widget _buildMessage(BuildContext context, LoadingBlocState state) {
    final message = widget.message ?? state.currentMessage ?? '加载中...';
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTaskCount(BuildContext context, LoadingBlocState state) {
    final completed = state.completedTasks.length;
    final total = state.taskStates.length;
    final failed = state.failedTasks.length;

    return Text(
      failed > 0 ? '$completed/$total (${failed}失败)' : '$completed/$total',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: failed > 0 ? Colors.red : null,
          ),
    );
  }

  Widget _buildElapsedTime(BuildContext context) {
    if (_startTime == null) return const SizedBox.shrink();

    final elapsed = DateTime.now().difference(_startTime!);
    final seconds = elapsed.inSeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    final timeText = minutes > 0
        ? '${minutes}m ${remainingSeconds}s'
        : '${remainingSeconds}s';

    return Text(
      timeText,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.7),
          ),
    );
  }

  double _getIndicatorSize() {
    switch (widget.size) {
      case ProgressIndicatorSize.small:
        return 24.0;
      case ProgressIndicatorSize.medium:
        return 48.0;
      case ProgressIndicatorSize.large:
        return 72.0;
      case ProgressIndicatorSize.extraLarge:
        return 96.0;
    }
  }

  double _getStrokeWidth() {
    switch (widget.size) {
      case ProgressIndicatorSize.small:
        return 2.0;
      case ProgressIndicatorSize.medium:
        return 3.0;
      case ProgressIndicatorSize.large:
        return 4.0;
      case ProgressIndicatorSize.extraLarge:
        return 5.0;
    }
  }

  Color _getProgressColor(
      BuildContext context, double progress, LoadingBlocState state) {
    if (state.failedTasks.isNotEmpty) {
      return Colors.red;
    } else if (progress >= 1.0) {
      return Colors.green;
    } else if (state.currentPriority == LoadingPriority.critical) {
      return Colors.orange;
    } else {
      return widget.primaryColor ?? Theme.of(context).primaryColor;
    }
  }

  IconData _getStatusIcon(LoadingBlocState state) {
    if (state.failedTasks.isNotEmpty) {
      return Icons.warning;
    } else if (state.overallProgress >= 1.0) {
      return Icons.check;
    } else if (state.currentPriority == LoadingPriority.critical) {
      return Icons.priority_high;
    } else {
      return Icons.hourglass_empty;
    }
  }

  bool _shouldShowMessage(LoadingBlocState state) {
    return widget.message != null ||
        state.currentMessage != null ||
        state.isLoading;
  }
}
