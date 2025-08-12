import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../views/goal_tree_view.dart'; // 导入GoalTreeView
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_event.dart';
import '../bloc/explore/explore_state.dart';
import '../models/explore_card.dart';
import '../models/goal.dart';
import '../routes/navigation_service.dart'; // 导入NavigationService
import '../routes/app_routes.dart'; // 导入AppRoutes
import '../bloc/goal/goal_bloc.dart'; // 导入GoalBloc以获取目标数据
import '../bloc/goal/goal_event.dart'; // 导入GoalEvent
import '../bloc/goal/goal_state.dart'; // 导入GoalState
import '../bloc/auth/auth_bloc.dart'; // 导入AuthBloc以获取登录状态
import '../bloc/auth/auth_event.dart'; // 导入AuthEvent
import '../bloc/auth/auth_state.dart'; // 导入AuthState
// 导入BLoC适配器
import 'explore_page_bloc_adapter.dart';
import 'package:flutter/foundation.dart';

/// 意识探索页面
class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // BLoC适配器 - 影子模式实现
  late ExplorePageBlocAdapter _blocAdapter;

  @override
  void initState() {
    super.initState();

    // 初始化BLoC适配器，默认为影子模式（不执行BLoC操作）
    _blocAdapter = ExplorePageBlocAdapter(
      context,
      logLevel: 1, // 只输出关键日志
      executeMode: false, // 默认不执行BLoC操作
      enablePerformanceMonitoring: true, // 启用性能监控
    );

    // 跨页面同步将通过BLoC事件自动处理

    // 加载意识卡片
    context.read<ExploreBloc>().add(FetchExploreCards());
    // 加载目标数据
    context.read<GoalBloc>().add(const LoadGoals());
    context.read<GoalBloc>().add(RefreshGoalTree());

    // 影子模式：通过BLoC适配器加载卡片
    _blocAdapter.loadExploreCards(
      onSuccess: (cards) {
        if (kDebugMode) {
          print('【影子模式】BLoC加载卡片成功: ${cards.length}个卡片');
        }
        // 通知跨页面同步 - 使用正确的方法名
        // _syncAdapter.requestExploreDataRefresh();
      },
      onError: (error) {
        if (kDebugMode) {
          print('【影子模式】BLoC加载卡片失败: $error');
        }
      },
    );
  }

  @override
  void dispose() {
    // 输出性能统计信息
    if (kDebugMode) {
      _blocAdapter.printPerformanceStats();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前登录状态
    final authState = context.watch<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;

    // 获取目标数据
    final goalState = context.watch<GoalBloc>().state;
    final List<Goal> allGoals =
        goalState is GoalsLoaded ? goalState.allGoals : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '意识探索',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 使用标准抽屉按钮
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // 视图切换按钮
          IconButton(
            icon: Icon(_getViewModeIcon()),
            onPressed: _toggleViewMode,
            color: Colors.black,
          ),
        ],
      ),
      // 使用GoalTreeView作为抽屉
      drawer: Drawer(
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: GoalTreeView(
                    goals: allGoals,
                    onSearchTap: () {
                      Navigator.pop(context);
                      // TODO: 实现搜索功能
                    },
                    onSyncTap: () {
                      Navigator.pop(context);
                      // TODO: 实现同步功能
                    },
                    membershipStatus: isLoggedIn ? 1 : 0, // 根据实际情况设置会员状态
                    onDeleteGoal: (goal) {
                      // 删除目标的处理
                      Navigator.pop(context);
                      context.read<GoalBloc>().add(DeleteGoal(goal.id!));
                    },
                    onUpdateGoalStatus: (goal, newStatus) {
                      // 更新目标状态的处理
                      Navigator.pop(context);
                      // 创建更新后的目标
                      final updatedGoal = goal.copyWith(status: newStatus);
                      context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
                    },
                    onGoalSelect: (goal) {
                      // 选择目标的处理
                      Navigator.pop(context);
                      NavigationService().navigateTo(
                        AppRoutes.goalDetails,
                        arguments: {'goalId': goal.id},
                      );
                    },
                    onSettingsTap: () {
                      // 设置页面的处理
                      Navigator.pop(context);
                      NavigationService().navigateTo(AppRoutes.settings);
                    },
                    onLoginTap: () {
                      // 登录页面的处理
                      Navigator.pop(context);
                      NavigationService().navigateTo(AppRoutes.login);
                    },
                    isLoggedIn: isLoggedIn,
                    userAvatar: null, // 根据实际情况设置用户头像
                    onLogout: () {
                      // 退出登录的处理
                      Navigator.pop(context);
                      context.read<AuthBloc>().add(LogoutEvent());
                    },
                    onExploreTab: () {
                      // 探索页面的处理
                      Navigator.pop(context);
                      // 已经在探索页面，不需要导航
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  /// 构建页面主体
  Widget _buildBody() {
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        if (state is ExploreLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ExploreLoaded) {
          // 根据BLoC状态中的视图模式显示不同布局
          switch (state.viewMode) {
            case ViewMode.grid:
              return _buildGridView(state);
            case ViewMode.fullScreen:
              return _buildFullscreenView(state);
          }
        } else if (state is ExploreError) {
          return Center(
            child: Text(
              '加载失败: ${state.message}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // 默认显示空白页面
        return const Center(child: Text('暂无意识卡片'));
      },
    );
  }

  /// 构建网格视图
  Widget _buildGridView(ExploreLoaded state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: state.cards.length,
      itemBuilder: (context, index) {
        final card = state.cards[index];
        return _buildCard(card);
      },
    );
  }

  /// 构建列表视图
  Widget _buildListView(ExploreLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.cards.length,
      itemBuilder: (context, index) {
        final card = state.cards[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildHorizontalCard(card),
        );
      },
    );
  }

  /// 构建全屏视图
  Widget _buildFullscreenView(ExploreLoaded state) {
    if (state.cards.isEmpty) {
      return const Center(child: Text('暂无意识卡片'));
    }

    return PageView.builder(
      itemCount: state.cards.length,
      itemBuilder: (context, index) {
        final card = state.cards[index];
        return _buildFullscreenCard(card);
      },
    );
  }

  /// 构建卡片（网格视图）
  Widget _buildCard(ExploreCard card) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onCardTap(card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 卡片图片
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  image: card.imagePath.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(card.imagePath),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: card.imagePath.isEmpty
                    ? const Center(
                        child: Icon(Icons.image, size: 40, color: Colors.grey))
                    : null,
              ),
            ),

            // 卡片内容
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片（列表视图）
  Widget _buildHorizontalCard(ExploreCard card) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onCardTap(card),
        child: Row(
          children: [
            // 卡片图片
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: card.imagePath.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(card.imagePath),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: card.imagePath.isEmpty
                  ? const Center(
                      child: Icon(Icons.image, size: 40, color: Colors.grey))
                  : null,
            ),

            // 卡片内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片（全屏视图）
  Widget _buildFullscreenCard(ExploreCard card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        image: card.imagePath.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(card.imagePath),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
            stops: const [0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              card.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _onCardTap(card),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('查看详情'),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换视图模式 - 完全使用BLoC状态管理
  void _toggleViewMode() {
    // 获取当前ExploreBloc状态
    final exploreState = context.read<ExploreBloc>().state;
    if (exploreState is ExploreLoaded) {
      // 计算新的视图模式
      final newViewMode = exploreState.viewMode == ViewMode.grid
          ? ViewMode.fullScreen
          : ViewMode.grid;

      // 通过BLoC事件切换视图模式
      context.read<ExploreBloc>().add(ChangeViewMode(newViewMode));

      // 影子模式：通过BLoC适配器切换视图模式
      _blocAdapter.changeViewMode(
        viewMode: newViewMode,
        onSuccess: () {
          if (kDebugMode) {
            print('【影子模式】BLoC切换视图模式成功: $newViewMode');
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('【影子模式】BLoC切换视图模式失败: $error');
          }
        },
      );
    }
  }

  /// 获取当前视图模式图标 - 基于BLoC状态
  IconData _getViewModeIcon() {
    final exploreState = context.watch<ExploreBloc>().state;
    if (exploreState is ExploreLoaded) {
      switch (exploreState.viewMode) {
        case ViewMode.grid:
          return Icons.view_module;
        case ViewMode.fullScreen:
          return Icons.fullscreen;
      }
    }
    // 默认图标
    return Icons.view_module;
  }

  /// 处理卡片点击
  void _onCardTap(ExploreCard card) {
    // 触发使用卡片事件
    context.read<ExploreBloc>().add(UseCard(card));

    // 影子模式：通过BLoC适配器选择卡片
    _blocAdapter.selectCard(
      card: card,
      onSuccess: () {
        if (kDebugMode) {
          print('【影子模式】BLoC选择卡片成功: ${card.title}');
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('【影子模式】BLoC选择卡片失败: $error');
        }
      },
    );
  }
}
