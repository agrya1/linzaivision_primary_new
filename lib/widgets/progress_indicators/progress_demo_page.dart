import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/loading/loading_bloc.dart';
import '../../bloc/loading/loading_state.dart';
import '../../bloc/loading/loading_event.dart';
import '../../bloc/loading/loading_task.dart';
import 'unified_progress_indicator.dart';
import 'smart_loading_feedback.dart';
import 'loading_state_manager.dart';

/// 进度指示器演示页面
/// 展示各种进度指示器的使用方法和效果
class ProgressDemoPage extends StatefulWidget {
  const ProgressDemoPage({Key? key}) : super(key: key);

  @override
  State<ProgressDemoPage> createState() => _ProgressDemoPageState();
}

class _ProgressDemoPageState extends State<ProgressDemoPage> {
  @override
  Widget build(BuildContext context) {
    return LoadingStateManager(
      config: const LoadingStateConfig(
        enableGlobalIndicator: true,
        enableSmartFeedback: true,
        enablePerformanceMonitoring: true,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('进度指示器演示'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('基础进度指示器'),
              _buildBasicIndicators(),
              const SizedBox(height: 32),
              _buildSectionTitle('不同尺寸'),
              _buildSizeVariations(),
              const SizedBox(height: 32),
              _buildSectionTitle('智能反馈系统'),
              _buildSmartFeedbackDemo(),
              const SizedBox(height: 32),
              _buildSectionTitle('加载状态构建器'),
              _buildLoadingStateBuilderDemo(),
              const SizedBox(height: 32),
              _buildSectionTitle('操作按钮'),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildBasicIndicators() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const UnifiedProgressIndicator(
                      type: ProgressIndicatorType.circular,
                      size: ProgressIndicatorSize.medium,
                      showPercentage: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '圆形',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Column(
                  children: [
                    const SizedBox(
                      width: 100,
                      child: UnifiedProgressIndicator(
                        type: ProgressIndicatorType.linear,
                        showPercentage: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '线性',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Column(
                  children: [
                    const UnifiedProgressIndicator(
                      type: ProgressIndicatorType.dots,
                      size: ProgressIndicatorSize.medium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点状',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const UnifiedProgressIndicator(
                      type: ProgressIndicatorType.wave,
                      size: ProgressIndicatorSize.medium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '波浪',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Column(
                  children: [
                    const UnifiedProgressIndicator(
                      type: ProgressIndicatorType.skeleton,
                      size: ProgressIndicatorSize.medium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '骨架屏',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeVariations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const UnifiedProgressIndicator(
                  type: ProgressIndicatorType.circular,
                  size: ProgressIndicatorSize.small,
                  showPercentage: false,
                ),
                const SizedBox(height: 8),
                Text(
                  '小',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Column(
              children: [
                const UnifiedProgressIndicator(
                  type: ProgressIndicatorType.circular,
                  size: ProgressIndicatorSize.medium,
                  showPercentage: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '中',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Column(
              children: [
                const UnifiedProgressIndicator(
                  type: ProgressIndicatorType.circular,
                  size: ProgressIndicatorSize.large,
                  showPercentage: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '大',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Column(
              children: [
                const UnifiedProgressIndicator(
                  type: ProgressIndicatorType.circular,
                  size: ProgressIndicatorSize.extraLarge,
                  showPercentage: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '超大',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartFeedbackDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('智能反馈系统会根据加载状态自动选择合适的反馈方式'),
            const SizedBox(height: 16),
            SmartLoadingFeedback(
              type: LoadingFeedbackType.inline,
              trigger: const FeedbackTrigger(
                minDuration: Duration(milliseconds: 100),
                showOnError: true,
                showOnSuccess: true,
              ),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('智能反馈演示区域'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStateBuilderDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LoadingStateBuilder(
          builder: (context, state) {
            return Column(
              children: [
                Text('当前状态: ${state.isLoading ? "加载中" : "空闲"}'),
                const SizedBox(height: 8),
                Text('活跃任务: ${state.activeTasks.length}'),
                Text('已完成任务: ${state.completedTasks.length}'),
                Text('失败任务: ${state.failedTasks.length}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.overallProgress,
                  backgroundColor: Theme.of(context).dividerColor,
                ),
              ],
            );
          },
          loadingBuilder: (context) {
            return const Center(
              child: UnifiedProgressIndicator(
                type: ProgressIndicatorType.circular,
                size: ProgressIndicatorSize.medium,
                message: '正在加载状态构建器演示...',
              ),
            );
          },
          errorBuilder: (context, failedTasks) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('${failedTasks.length} 个任务失败'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startSimpleLoading,
                    child: const Text('开始简单加载'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startComplexLoading,
                    child: const Text('开始复杂加载'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _simulateError,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('模拟错误'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearAllTasks,
                    child: const Text('清除所有任务'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startSimpleLoading() {
    final loadingBloc = context.read<LoadingBloc>();

    final task = LoadingTask<String>(
      id: 'simple_demo',
      name: '简单演示任务',
      executor: (context) async {
        for (int i = 0; i <= 100; i += 10) {
          await Future.delayed(const Duration(milliseconds: 200));
          loadingBloc.add(UpdateTaskProgress(
            taskId: 'simple_demo',
            progress: i / 100.0,
            message: '进度: $i%',
          ));
        }
        return '简单任务完成';
      },
      priority: LoadingPriority.normal,
    );

    loadingBloc.add(RegisterLoadingTasks([task]));
    loadingBloc.add(StartLoadingTasks(['simple_demo']));
  }

  void _startComplexLoading() {
    final loadingBloc = context.read<LoadingBloc>();

    final tasks = [
      LoadingTask<String>(
        id: 'task_1',
        name: '任务1',
        executor: (context) async {
          await Future.delayed(const Duration(seconds: 2));
          return '任务1完成';
        },
        priority: LoadingPriority.high,
      ),
      LoadingTask<String>(
        id: 'task_2',
        name: '任务2',
        executor: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return '任务2完成';
        },
        dependencies: ['task_1'],
      ),
      LoadingTask<String>(
        id: 'task_3',
        name: '任务3',
        executor: (context) async {
          await Future.delayed(const Duration(milliseconds: 800));
          return '任务3完成';
        },
        dependencies: ['task_1'],
      ),
    ];

    loadingBloc.add(RegisterLoadingTasks(tasks));
    loadingBloc.add(StartLoadingTasks(['task_1', 'task_2', 'task_3']));
  }

  void _simulateError() {
    final loadingBloc = context.read<LoadingBloc>();

    final task = LoadingTask<String>(
      id: 'error_demo',
      name: '错误演示任务',
      executor: (context) async {
        await Future.delayed(const Duration(seconds: 1));
        throw Exception('模拟的错误');
      },
      maxRetries: 2,
    );

    loadingBloc.add(RegisterLoadingTasks([task]));
    loadingBloc.add(StartLoadingTasks(['error_demo']));
  }

  void _clearAllTasks() {
    context.read<LoadingBloc>().add(const ResetLoadingState());
  }
}
