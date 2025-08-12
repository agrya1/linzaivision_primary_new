import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/component_state_provider.dart';
import '../widgets/goal_status_badge.dart';
import '../mixins/component_state_mixin.dart';
import '../utils/component_state_manager.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/goal/goal_state.dart';
import '../models/goal.dart';

/// 组件状态测试页面
///
/// 用于验证新的组件状态传递机制的有效性
class ComponentStateTestPage extends StatefulWidget {
  const ComponentStateTestPage({Key? key}) : super(key: key);

  @override
  State<ComponentStateTestPage> createState() => _ComponentStateTestPageState();
}

class _ComponentStateTestPageState extends State<ComponentStateTestPage>
    with ComponentStateMixin {
  bool _useNewStateManagement = true;

  @override
  void initState() {
    super.initState();

    // 加载测试数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTestData();
    });
  }

  void _loadTestData() {
    // 触发加载目标数据
    dispatchGoalEvent(const LoadGoals());
  }

  void _createTestGoal() {
    final testGoal = Goal(
      title: '测试目标 ${DateTime.now().millisecondsSinceEpoch}',
      description: '这是一个用于测试组件状态传递机制的目标',
      imagePath: '',
      status: GoalStatus.pending,
      createdTime: DateTime.now(),
    );

    addGoal(testGoal);
  }

  void _toggleStateManagement() {
    setState(() {
      _useNewStateManagement = !_useNewStateManagement;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('组件状态测试'),
        actions: [
          Switch(
            value: _useNewStateManagement,
            onChanged: (_) => _toggleStateManagement(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: AutoComponentStateProvider(
        pageName: 'component_state_test',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态管理模式指示器
              _buildModeIndicator(),
              const SizedBox(height: 16),

              // 当前目标信息
              if (_useNewStateManagement) ...[
                const CurrentGoalInfo(),
                const SizedBox(height: 16),
              ],

              // 目标列表
              _buildGoalList(),
              const SizedBox(height: 16),

              // 目标统计
              if (_useNewStateManagement) ...[
                GoalStatusStats(useNewStateManagement: _useNewStateManagement),
                const SizedBox(height: 16),
              ],

              // 操作按钮
              _buildActionButtons(),
              const SizedBox(height: 16),

              // 状态信息
              _buildStateInfo(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTestGoal,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildModeIndicator() {
    return Card(
      color: _useNewStateManagement ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _useNewStateManagement ? Icons.auto_awesome : Icons.settings,
              color: _useNewStateManagement ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _useNewStateManagement ? '新状态管理模式' : '传统状态管理模式',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _useNewStateManagement
                        ? '使用ComponentStateManager统一管理状态'
                        : '使用传统的setState和回调方式',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: _useNewStateManagement,
              onChanged: (_) => _toggleStateManagement(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalList() {
    if (_useNewStateManagement && hasStateManager) {
      // 使用新状态管理机制
      return ComponentStateBuilder(
        listenToKeys: const [
          ComponentStateKeys.goals,
          ComponentStateKeys.currentGoal
        ],
        rebuildOnAnyChange: false,
        builder: (context, stateManager) {
          final goalList =
              stateManager.getState<List<Goal>>(ComponentStateKeys.goals) ?? [];
          final currentGoal =
              stateManager.getState<Goal>(ComponentStateKeys.currentGoal);

          return _buildGoalListContent(goalList, currentGoal);
        },
      );
    } else {
      // 使用传统方式
      return BlocBuilder<GoalBloc, GoalState>(
        builder: (context, state) {
          if (state is GoalsLoaded) {
            return _buildGoalListContent(state.goals, state.currentGoal);
          } else if (state is GoalLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is GoalError) {
            return Center(child: Text('错误: ${state.message}'));
          }
          return const Center(child: Text('未加载数据'));
        },
      );
    }
  }

  Widget _buildGoalListContent(List<Goal> goalList, Goal? currentGoal) {
    if (goalList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('暂无目标，点击右下角按钮添加'),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '目标列表',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...goalList
              .map((goal) => ListTile(
                    leading: GoalStatusBadge(
                      goal: goal,
                      useNewStateManagement: _useNewStateManagement,
                      onTap: () => _onGoalStatusTap(goal),
                    ),
                    title: Text(goal.title),
                    subtitle: goal.description.isNotEmpty
                        ? Text(goal.description)
                        : null,
                    trailing: currentGoal?.id == goal.id
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    selected: currentGoal?.id == goal.id,
                    onTap: () => _onGoalTap(goal),
                  ))
              .toList(),
        ],
      ),
    );
  }

  void _onGoalTap(Goal goal) {
    if (_useNewStateManagement && hasStateManager) {
      // 使用新状态管理机制
      selectGoal(goal);
    } else {
      // 使用传统方式
      context.read<GoalBloc>().add(SelectGoal(goal));
    }
  }

  void _onGoalStatusTap(Goal goal) {
    if (!_useNewStateManagement) {
      // 传统方式切换状态
      final newStatus = goal.status == GoalStatus.completed
          ? GoalStatus.pending
          : GoalStatus.completed;

      final updatedGoal = goal.copyWith(status: newStatus);
      context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
    }
    // 新状态管理模式在GoalStatusBadge中处理
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作测试',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _createTestGoal,
                  icon: const Icon(Icons.add),
                  label: const Text('添加目标'),
                ),
                ElevatedButton.icon(
                  onPressed: _useNewStateManagement && hasStateManager
                      ? () {
                          toggleViewMode();
                        }
                      : null,
                  icon: const Icon(Icons.view_module),
                  label: const Text('切换视图'),
                ),
                ElevatedButton.icon(
                  onPressed: _useNewStateManagement && hasStateManager
                      ? () {
                          refreshGoalTree();
                        }
                      : () {
                          context.read<GoalBloc>().add(const RefreshGoalTree());
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新数据'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateInfo() {
    if (!_useNewStateManagement || !hasStateManager) {
      return const SizedBox.shrink();
    }

    return ComponentStateBuilder(
      builder: (context, stateManager) {
        final isLoading =
            stateManager.getState<bool>(ComponentStateKeys.isLoading) ?? false;
        final error = stateManager.getState<String>(ComponentStateKeys.error);
        final viewMode =
            stateManager.getState<int>(ComponentStateKeys.viewMode) ?? 0;
        final goalCount =
            (stateManager.getState<List<Goal>>(ComponentStateKeys.goals) ?? [])
                .length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '状态信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('加载状态: ${isLoading ? "加载中" : "已完成"}'),
                Text('视图模式: ${viewMode == 0 ? "全屏" : "网格"}'),
                Text('目标数量: $goalCount'),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '错误: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
