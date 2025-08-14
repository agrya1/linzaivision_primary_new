import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/pages/settings_page.dart';
// 已移除：搜索功能相关导入
import 'package:linzaivision_primary/views/full_screen_view.dart';
import 'package:linzaivision_primary/views/grid_view.dart';
import 'package:linzaivision_primary/views/timeline_view.dart';
import 'package:linzaivision_primary/views/goal_tree_view_bloc.dart';
import 'package:linzaivision_primary/views/explore_view.dart';
import 'package:linzaivision_primary/widgets/menus/goal_menus.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/pages/auth/login_page.dart';
import 'package:linzaivision_primary/pages/membership/membership_page.dart';
import 'package:linzaivision_primary/widgets/common/share_dialog.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/widgets/pickers/image_picker_dialog.dart';
import 'package:linzaivision_primary/widgets/pickers/membership_prompt_dialog.dart';
import 'package:linzaivision_primary/widgets/dialogs/add_goal_dialog_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
// 导入BLoC适配器
import 'goal_page_bloc_adapter.dart';
// 导入错误处理工具
import '../utils/error_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// 已移除：搜索BLoC导入
import '../routes/navigation_service.dart'; // 导入NavigationService
import '../bloc/component/component_communication_bloc.dart';
import '../bloc/component/component_communication_events.dart' as comm_events;
import '../routes/app_routes.dart'; // 导入AppRoutes
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/goal/goal_state.dart';
import '../utils/bloc_feature_toggles.dart';
import '../utils/ui_state_performance_monitor.dart';
import '../widgets/appbar/view_switch_action.dart';
// 导入接口定义
import '../interfaces/goal_page_interfaces.dart';

/// 主页面
class GoalPage extends StatefulWidget {
  final Goal? parentGoal;
  final VoidCallback? onGoalTreeChanged;
  final bool isSubGoalView; // 添加标记表明这是子目标视图

  const GoalPage({
    super.key,
    this.parentGoal,
    this.onGoalTreeChanged,
    this.isSubGoalView = false, // 默认为false
  });

  @override
  State<GoalPage> createState() => GoalPageState();
}

class GoalPageState extends State<GoalPage> implements GoalPageStateInterface {
  late List<Goal> goals;
  List<Goal> allGoals = [];
  int currentView = 0; // 视图模式：0 - 全屏视图，1 - 时间轴视图，2 - 网格视图
  Goal? currentGoal;
  // 批次3阶段4：UI状态管理清理 - 这些状态将逐步移除
  bool _isLoading = true;
  String? _error;

  // 添加数据库支持
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 编辑状态控制
  bool _isEditingTitle = false;
  bool _isEditingDescription = false;
  final TextEditingController _titleController = TextEditingController();
  // 批次2重构：添加描述控制器，与标题编辑保持一致
  final TextEditingController _descriptionController = TextEditingController();

  // 防止无限循环的标志
  bool _isRefreshing = false;

  // 性能优化：数据缓存
  List<Goal>? _cachedAllGoals;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // 批次3阶段4：待移除 - 性能优化：批处理状态更新
  Timer? _stateUpdateTimer;
  Map<String, dynamic> _pendingStateUpdates = {};

  /// 用户会员状态（模拟数据，实际应该从用户系统获取）
  int _membershipStatus = 0;

  // 倒计时功能已移除，等架构稳定后重新实现
  // 添加时间显示状态变量:
  bool _showTime = true; // 默认显示时间
  // 添加描述显示状态变量:
  bool _showDescription = true; // 默认显示描述

  // 添加标题显示状态变量
  bool _showTitle = true;

  // BLoC适配器 - 影子模式实现
  GoalPageBlocAdapter? _blocAdapter;

  // BLoC功能开关
  final BlocFeatureToggles _featureToggles = BlocFeatureToggles();

  // 从BLoC状态同步到本地状态的方法
  DateTime _lastSyncTime = DateTime.now(); // 移到方法外部作为类成员变量

  @override
  void initState() {
    super.initState();
    // 如果是子目标页面，强制显示时间轴视图
    if (widget.parentGoal != null) {
      currentView = 1;
      print('初始化子目标页面: 父目标=${widget.parentGoal!.title}');
    } else {
      print('初始化主页面');
    }

    // 初始化空目标列表
    goals = [];

    // 阶段1+批次1：启用只读渲染和UI状态写路径开关
    // 使用 WidgetsBinding.instance.addPostFrameCallback 确保异步初始化

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBlocToggles();
    });

    // 初始化BLoC适配器，默认为影子模式（不执行BLoC操作）
    _blocAdapter = GoalPageBlocAdapter(
      context,
      logLevel: 1, // 只输出关键日志
      executeMode: false, // 默认不执行BLoC操作
      enablePerformanceMonitoring: true, // 启用性能监控
    );

    // 立即检查用户登录状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });

    // 清理数据库错误数据
    _cleanupDatabaseErrors();

    // 加载数据
    _loadGoals();

    // 如果提供了goalId，则加载特定目标
    if (widget.parentGoal != null) {
      // 延迟加载，确保在页面构建后执行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSpecificGoal(widget.parentGoal!.id!);
      });
    }

    // 确保在第一帧渲染后子目标页面始终显示时间轴视图
    if (widget.parentGoal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentView != 1) {
          print('确保子目标页面显示时间轴视图');
          setState(() {
            currentView = 1;
          });
        }
      });
    } else {
      // 为根页面添加延迟检查树视图数据的回调
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 延迟2秒确保初始化完成
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && allGoals.isEmpty && !_isRefreshing) {
          print('检测到树视图数据为空，尝试重新加载');
          _isRefreshing = true;
          await _refreshGoalTree();
          _isRefreshing = false;
        }
      });
    }

    // 初始化BLoC适配器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBlocAdapter();
    });

    // 加载BLoC功能开关设置
    _featureToggles.loadSettings();
  }

  @override
  void dispose() {
    // 性能优化：清理资源
    _stateUpdateTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }



  // 阶段1+批次1：启用只读渲染和UI状态写路径开关
  void _initializeBlocToggles() async {
    print('【调试】开始初始化BLoC开关...');
    await _featureToggles.loadSettings();
    print('【调试】开关设置已加载');

    // 阶段1：只读渲染开关（必须保持启用）
    await _featureToggles.setFeatureEnabled('displayOptionsBlocDriven', true);
    await _featureToggles.setFeatureEnabled('fullScreenBlocDriven', true);
    await _featureToggles.setFeatureEnabled('viewSwitching', true);
    await _featureToggles.setFeatureEnabled('appBarBlocDriven', true);

    // 批次1灰度：启用showTitle写路径BLoC化
    await _featureToggles.setFeatureEnabled('titleDisplayWriteThrough', true);
    // 批次1灰度：启用showDescription写路径BLoC化
    await _featureToggles.setFeatureEnabled('descriptionDisplayWriteThrough', true);
    // 批次1灰度：启用showTime写路径BLoC化
    await _featureToggles.setFeatureEnabled('timeDisplayWriteThrough', true);
    // 批次1灰度：启用viewMode写路径BLoC化
    await _featureToggles.setFeatureEnabled('viewModeWriteThrough', true);

    // 批次2灰度：启用目标选择写路径BLoC化
    await _featureToggles.setFeatureEnabled('currentGoalSelectionWriteThrough', true);
    // 批次2灰度：启用标题编辑写路径BLoC化
    await _featureToggles.setFeatureEnabled('titleEditingWriteThrough', true);
    // 批次2灰度：启用描述编辑写路径BLoC化
    await _featureToggles.setFeatureEnabled('descriptionEditingWriteThrough', true);

    print('【GoalPage】阶段1+批次1+批次2开关已启用');
    print('  displayOptionsBlocDriven: ${_featureToggles.displayOptionsBlocDriven}');
    print('  appBarBlocDriven: ${_featureToggles.appBarBlocDriven}');
    print('  titleDisplayWriteThrough: ${_featureToggles.titleDisplayWriteThrough}');
    print('  descriptionDisplayWriteThrough: ${_featureToggles.descriptionDisplayWriteThrough}');
    print('  timeDisplayWriteThrough: ${_featureToggles.timeDisplayWriteThrough}');
    print('  viewModeWriteThrough: ${_featureToggles.viewModeWriteThrough}');
    print('  currentGoalSelectionWriteThrough: ${_featureToggles.currentGoalSelectionWriteThrough}');
    print('  titleEditingWriteThrough: ${_featureToggles.titleEditingWriteThrough}');
    print('  descriptionEditingWriteThrough: ${_featureToggles.descriptionEditingWriteThrough}');

    // 验证开关组合（批次1+批次2）
    final batch1Valid = _featureToggles.titleDisplayWriteThrough &&
        _featureToggles.descriptionDisplayWriteThrough &&
        _featureToggles.timeDisplayWriteThrough &&
        _featureToggles.viewModeWriteThrough &&
        _featureToggles.displayOptionsBlocDriven &&
        _featureToggles.appBarBlocDriven;

    final batch2Valid = _featureToggles.currentGoalSelectionWriteThrough &&
        _featureToggles.titleEditingWriteThrough &&
        _featureToggles.descriptionEditingWriteThrough;

    if (batch1Valid && batch2Valid) {
      print('【批次1+批次2灰度】✅ 开关组合验证通过');
    } else {
      print('【批次1+批次2灰度】❌ 开关组合验证失败，自动回退');
      if (!batch1Valid) {
        await _featureToggles.setFeatureEnabled('titleDisplayWriteThrough', false);
        await _featureToggles.setFeatureEnabled('descriptionDisplayWriteThrough', false);
        await _featureToggles.setFeatureEnabled('timeDisplayWriteThrough', false);
        await _featureToggles.setFeatureEnabled('viewModeWriteThrough', false);
      }
      if (!batch2Valid) {
        await _featureToggles.setFeatureEnabled('currentGoalSelectionWriteThrough', false);
        await _featureToggles.setFeatureEnabled('titleEditingWriteThrough', false);
        await _featureToggles.setFeatureEnabled('descriptionEditingWriteThrough', false);
      }
    }
  }

  // 性能优化：检查缓存是否有效
  bool _isCacheValid() {
    if (_cachedAllGoals == null || _lastCacheTime == null) {
      return false;
    }
    return DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  // 性能优化：更新缓存
  void _updateCache(List<Goal> goals) {
    _cachedAllGoals = List.from(goals);
    _lastCacheTime = DateTime.now();
    print('【性能优化】缓存已更新，包含 ${goals.length} 个目标');
  }

  // 性能优化：批处理状态更新
  void _batchStateUpdate(String key, dynamic value) {
    _pendingStateUpdates[key] = value;

    // 取消之前的定时器
    _stateUpdateTimer?.cancel();

    // 设置新的定时器，延迟50ms执行批处理更新
    _stateUpdateTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted && _pendingStateUpdates.isNotEmpty) {
        setState(() {
          _pendingStateUpdates.forEach((key, value) {
            switch (key) {
              case 'allGoals':
                allGoals = value as List<Goal>;
                break;
              case 'goals':
                goals = value as List<Goal>;
                break;
              case 'currentGoal':
                currentGoal = value as Goal?;
                break;
              case 'currentView':
                currentView = value as int;
                break;
              case '_isLoading':
                _isLoading = value as bool;
                break;
              case '_showTitle':
                _showTitle = value as bool;
                break;
              case '_showDescription':
                _showDescription = value as bool;
                break;
              case '_showTime':
                _showTime = value as bool;
                break;
              // 倒计时功能已移除
            }
          });
        });
        _pendingStateUpdates.clear();
        print('【性能优化】批处理更新了 ${_pendingStateUpdates.length} 个状态');
      }
    });
  }

  // 重置数据库用于测试
  Future<void> _resetDatabaseForTesting() async {
    try {
      print('【GoalPage】开始重置数据库进行测试');
      await _dbHelper.resetDatabase();

      // 清理缓存
      _cachedAllGoals = null;
      _lastCacheTime = null;

      // 重置状态
      setState(() {
        goals = [];
        allGoals = [];
        currentGoal = null;
        _isLoading = true;
      });

      print('【GoalPage】数据库重置完成，开始重新加载');
      await _loadGoals();
    } catch (e) {
      print('【GoalPage】重置数据库失败: $e');
    }
  }

  // 清理数据库中的错误数据
  Future<void> _cleanupDatabaseErrors() async {
    try {
      print('【GoalPage】开始清理数据库错误数据');

      // 批次3阶段3：数据加载统一通过BLoC
      List<Goal> allTargets;
      if (_featureToggles.dataLoadingViaBloc) {
        // 新路径：通过BLoC事件加载数据
        print('【GoalPage】使用BLoC方式获取目标树进行数据清理');
        final completer = Completer<List<Goal>>();

        // 监听BLoC状态变化
        late final StreamSubscription<GoalState> subscription;
        subscription = context.read<GoalBloc>().stream.listen((state) {
          if (state is GoalsLoaded) {
            completer.complete(state.allGoals);
            subscription.cancel();
          } else if (state is GoalError) {
            completer.completeError(state.message);
            subscription.cancel();
          }
        });

        // 发送加载事件
        context.read<GoalBloc>().add(const LoadGoals());

        // 等待结果
        allTargets = await completer.future;
      } else {
        // 传统路径：直接从数据库获取
        print('【GoalPage】使用传统方式获取目标树进行数据清理');
        allTargets = await _dbHelper.getGoalTree();
      }

      // 查找孤儿目标（父ID指向不存在的目标）
      final orphanGoals = <Goal>[];
      for (final goal in allTargets) {
        if (goal.parentId != null) {
          final parentExists = allTargets.any((g) => g.id == goal.parentId);
          if (!parentExists) {
            orphanGoals.add(goal);
          }
        }
      }

      // 修复孤儿目标：将它们设为根目标
      for (final orphan in orphanGoals) {
        print('【GoalPage】修复孤儿目标: ${orphan.title} (ID: ${orphan.id})');
        final fixedGoal = orphan.copyWith(parentId: null);

        // 批次3阶段2：CRUD操作统一通过BLoC
        if (_featureToggles.goalCRUDWriteThrough) {
          // 新路径：直接使用BLoC事件，由BLoC处理数据库操作
          context
              .read<GoalBloc>()
              .add(UpdateGoalWithValidation(fixedGoal, validateData: false));
          print('【GoalPage】使用BLoC事件修复孤儿目标: ${fixedGoal.title}');
        } else {
          // 传统路径：直接更新数据库
          await _dbHelper.updateGoal(fixedGoal);
          print('【GoalPage】传统方式修复孤儿目标: ${fixedGoal.title}');
        }
      }

      if (orphanGoals.isNotEmpty) {
        print('【GoalPage】已修复 ${orphanGoals.length} 个孤儿目标');
        // 重新加载数据
        await _loadGoals();
      }
    } catch (e) {
      print('【GoalPage】清理数据库错误失败: $e');
    }
  }

  // 初始化BLoC适配器
  void _initBlocAdapter() {
    if (_blocAdapter == null) {
      _blocAdapter = GoalPageBlocAdapter(
        context,
        logLevel: 2,
        enablePerformanceMonitoring: true,
      );
      _log('BLoC适配器初始化完成，执行模式: ${_blocAdapter?.executeMode}');
    }
  }

  /// 启用BLoC适配器执行模式
  ///
  /// 当我们确认BLoC架构稳定后，可以调用此方法切换到BLoC模式
  void _enableBlocMode() {
    if (_blocAdapter != null) {
      setState(() {
        // 创建新的适配器实例，启用执行模式
        _blocAdapter = GoalPageBlocAdapter(
          context,
          logLevel: 2, // 详细日志
          executeMode: true, // 启用执行模式
          enablePerformanceMonitoring: true, // 启用性能监控
        );
        print('已启用BLoC执行模式 - 数据操作将通过BLoC进行');

        // 显示性能监控提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已启用BLoC执行模式，性能监控已开启'),
            action: SnackBarAction(
              label: '查看性能统计',
              onPressed: () {
                _showPerformanceStats();
              },
            ),
          ),
        );
      });
    }
  }

  /// 显示性能统计对话框
  void _showPerformanceStats() {
    if (_blocAdapter == null) return;

    // 获取性能统计数据
    final stats = _blocAdapter!.getPerformanceStats();

    // 输出到控制台
    _blocAdapter!.printPerformanceStats();

    // 显示对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能统计'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('各操作平均执行时间（毫秒）:'),
              const SizedBox(height: 8),
              ...stats.entries.map((entry) {
                final operation = entry.key;
                final data = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(operation),
                      Text('${data['avg']}ms'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 检查用户登录状态
  Future<void> _checkLoginStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isLoggedIn) {
      // 根据实际会员级别设置状态
      final prefs = await SharedPreferences.getInstance();
      // 获取会员级别，如未找到默认为普通用户（级别1）
      final memberLevel = prefs.getInt('member_level') ?? 1;

      setState(() {
        _membershipStatus = memberLevel;
        print('用户已登录，会员状态: $_membershipStatus'); // 添加日志
      });
    } else {
      setState(() {
        _membershipStatus = 0; // 未登录状态
        print('用户未登录，会员状态: 0'); // 添加日志
      });
    }
  }

  // 加载目标数据
  Future<void> _loadGoals() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 批次3阶段3：数据加载统一通过BLoC
      List<Goal> loadedGoals;
      if (_featureToggles.dataLoadingViaBloc) {
        // 新路径：通过BLoC事件加载数据
        print('【GoalPage】使用BLoC方式加载目标数据');
        final completer = Completer<GoalsLoaded>();

        // 监听BLoC状态变化
        late final StreamSubscription<GoalState> subscription;
        subscription = context.read<GoalBloc>().stream.listen((state) {
          if (state is GoalsLoaded) {
            completer.complete(state);
            subscription.cancel();
          } else if (state is GoalError) {
            completer.completeError(state.message);
            subscription.cancel();
          }
        });

        // 发送加载事件
        context.read<GoalBloc>().add(LoadGoals(parentId: widget.parentGoal?.id));

        // 等待结果
        final goalState = await completer.future;
        allGoals = goalState.allGoals;
        loadedGoals = goalState.goals;
      } else {
        // 传统路径：直接从数据库获取
        print('【GoalPage】使用传统方式加载目标数据');
        // 始终加载全量目标树
        allGoals = await _dbHelper.getGoalTree();
        loadedGoals = await _dbHelper.getGoals(parentId: widget.parentGoal?.id);
      }

      // 如果是根页面(不是子目标页面)且数据库中没有数据，使用示例数据
      if (loadedGoals.isEmpty && widget.parentGoal == null) {
        setState(() {
          goals = [
            Goal(
              title: '让心愿可以被看见',
              description: '描述你的心愿',
              imagePath: 'assets/images/default/default.jpg',
              createdTime: DateTime.now(),
              parentId: null, // 明确设置为根目标
              subGoals: [
                Goal(
                  title: '让目标可以被拆解',
                  description: '描述你的目标',
                  imagePath: 'assets/images/default/default.jpg',
                  createdTime: DateTime.now().add(const Duration(seconds: 2)),
                  // 父目标ID会在保存时设置
                ),
              ],
            ),
            Goal(
              title: '让梦想可以被管理',
              description: '描述你的梦想',
              imagePath: 'assets/images/default/default2.jpg',
              createdTime:
                  DateTime.now().add(const Duration(seconds: 1)), // 确保创建时间不同
              parentId: null, // 明确设置为根目标
            ),
            Goal(
              title: '让意识开始被观测',
              description: '描述你的意识',
              imagePath: 'assets/images/default/default3.jpg',
              createdTime:
                  DateTime.now().add(const Duration(seconds: 1)), // 确保创建时间不同
              parentId: null, // 明确设置为根目标
            ),
          ];
        });

        // 等待保存初始数据完成
        await _saveInitialGoals();

        // 批次3阶段3：数据加载统一通过BLoC
        List<Goal> reloadedGoals;
        if (_featureToggles.dataLoadingViaBloc) {
          // 新路径：通过BLoC事件重新加载数据
          print('【GoalPage】使用BLoC方式重新加载数据以确保完整性');
          final completer = Completer<List<Goal>>();

          // 监听BLoC状态变化
          late final StreamSubscription<GoalState> subscription;
          subscription = context.read<GoalBloc>().stream.listen((state) {
            if (state is GoalsLoaded) {
              completer.complete(state.goals);
              subscription.cancel();
            } else if (state is GoalError) {
              completer.completeError(state.message);
              subscription.cancel();
            }
          });

          // 发送加载事件
          context.read<GoalBloc>().add(LoadGoals(parentId: widget.parentGoal?.id));

          // 等待结果
          reloadedGoals = await completer.future;
        } else {
          // 传统路径：重新从数据库加载数据以确保数据完整
          print('【GoalPage】使用传统方式重新加载数据以确保完整性');
          reloadedGoals = await _dbHelper.getGoals(parentId: widget.parentGoal?.id);
        }

        // 先刷新目标树
        await _refreshGoalTree();

        // 传统模式：正确设置currentGoal和goals
        setState(() {
          // 重要修复：如果是根页面，从allGoals中提取根目标
          if (widget.parentGoal == null) {
            goals = allGoals.where((goal) => goal.parentId == null).toList();
          } else {
            goals = reloadedGoals;
          }
          currentGoal = goals.isNotEmpty ? goals[0] : null;
          _isLoading = false;
        });

        // 第二阶段迁移完成：统一使用BLoC事件加载目标数据（影子模式）
        context.read<GoalBloc>().add(LoadGoals());
        if (reloadedGoals.isNotEmpty) {
          context.read<GoalBloc>().add(SelectGoal(reloadedGoals[0]));
        }
      } else {
        // 传统模式：正确设置currentGoal和goals
        setState(() {
          // 重要修复：如果是根页面，从allGoals中提取根目标
          if (widget.parentGoal == null) {
            goals = allGoals.where((goal) => goal.parentId == null).toList();
          } else {
            goals = loadedGoals;
          }
          currentGoal = goals.isNotEmpty ? goals[0] : null;
          _isLoading = false;
        });

        // 第二阶段迁移完成：统一使用BLoC事件加载目标数据（影子模式）
        context.read<GoalBloc>().add(LoadGoals());
        if (loadedGoals.isNotEmpty) {
          context.read<GoalBloc>().add(SelectGoal(loadedGoals[0]));
        }
      }

      // 使用BLoC适配器加载数据（影子模式）
      _blocAdapter?.loadGoals(
        parentId: widget.parentGoal?.id,
        onSuccess: (blocGoals, blocAllGoals) {
          print('BLoC加载成功 - 影子模式 - 目标数量: ${blocGoals.length}');
        },
        onError: (error) {
          print('BLoC加载失败 - 影子模式: $error');
        },
      );

      // 重要修复：确保在正常流程结束时loading状态为false
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
        _isLoading = false;
      });
    }
  }

  // 保存初始目标数据（带幂等保护）
  Future<void> _saveInitialGoals() async {
    print('开始保存初始数据到数据库');

    try {
      // 批次3阶段3：数据加载统一通过BLoC
      List<Goal> existingAll;
      if (_featureToggles.dataLoadingViaBloc) {
        // 新路径：通过BLoC事件检查现有数据
        print('【GoalPage】使用BLoC方式检查现有数据');
        final completer = Completer<List<Goal>>();

        // 监听BLoC状态变化
        late final StreamSubscription<GoalState> subscription;
        subscription = context.read<GoalBloc>().stream.listen((state) {
          if (state is GoalsLoaded) {
            completer.complete(state.allGoals);
            subscription.cancel();
          } else if (state is GoalError) {
            completer.completeError(state.message);
            subscription.cancel();
          }
        });

        // 发送加载事件
        context.read<GoalBloc>().add(const LoadGoals());

        // 等待结果
        existingAll = await completer.future;
      } else {
        // 传统路径：直接从数据库检查
        print('【GoalPage】使用传统方式检查现有数据');
        existingAll = await _dbHelper.getGoalTree();
      }

      // 1) 幂等检查：数据库如已有数据则跳过种子写入
      if (existingAll.isNotEmpty) {
        print('跳过初始数据保存：数据库已有 ${existingAll.length} 条记录');
        return;
      }

      // 2) 防御处理：确保待插入的种子数据ID为空（避免显式ID导致唯一约束冲突）
      void _resetIdsRecursively(Goal g) {
        g.id = null;
        for (final child in g.subGoals) {
          _resetIdsRecursively(child);
        }
      }
      for (final g in goals) {
        _resetIdsRecursively(g);
      }

      // 批次3阶段2：批量操作统一通过BLoC
      if (_featureToggles.goalCRUDWriteThrough) {
        // 新路径：直接使用BLoC事件，由BLoC处理数据库操作
        context.read<GoalBloc>().add(SaveInitialGoals(goals));
        print('【GoalPage】使用BLoC事件保存初始数据: ${goals.length}个目标');
      } else {
        // 传统路径：先保存到数据库，再通知影子模式
        await _dbHelper.batchInsertGoalTree(goals);
        print('【GoalPage】传统方式保存初始数据完成: ${goals.length}个目标');

        // 4) 仅在实际写入后，通知影子模式适配器
        _blocAdapter?.saveInitialGoals(
          goals: goals,
          onSuccess: () {
            print('BLoC保存初始数据成功 - 影子模式');
          },
          onError: (error) {
            print('BLoC保存初始数据失败 - 影子模式: $error');
          },
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE constraint failed: goals.id')) {
        // 冲突容错：视为已初始化过，跳过
        print('跳过初始数据保存（检测到重复ID插入）: $e');
        return;
      }
      print('保存初始数据出错: $e');
    }
  }

  // 刷新目标树结构
  Future<void> _refreshGoalTree() async {
    final executeMode = _blocAdapter?.executeMode ?? false;
    print('【GoalPage】开始刷新目标树，当前模式: ${executeMode ? "BLoC模式" : "传统模式"}');

    // 性能优化：检查缓存
    if (_isCacheValid()) {
      print('【性能优化】使用缓存数据，跳过数据库查询');
      setState(() {
        allGoals = _cachedAllGoals!;
        _isLoading = false;
      });
      return;
    }

    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    // 根据BLoC模式状态选择方法
    if (isBlocModeEnabled) {
      print('【GoalPage】使用BLoC方式刷新目标树');
      await _refreshGoalTreeWithBloc();
    } else {
      try {
        setState(() {
          _isLoading = true;
        });

        // 批次3阶段3：数据加载统一通过BLoC
        List<Goal> freshGoals;
        if (_featureToggles.dataLoadingViaBloc) {
          // 新路径：通过BLoC事件刷新目标树
          print('【GoalPage】使用BLoC方式刷新目标树');
          final startTime = DateTime.now();
          final completer = Completer<List<Goal>>();

          // 监听BLoC状态变化
          late final StreamSubscription<GoalState> subscription;
          subscription = context.read<GoalBloc>().stream.listen((state) {
            if (state is GoalsLoaded) {
              completer.complete(state.allGoals);
              subscription.cancel();
            } else if (state is GoalError) {
              completer.completeError(state.message);
              subscription.cancel();
            }
          });

          // 发送刷新事件
          context.read<GoalBloc>().add(RefreshGoalTree());

          // 等待结果
          freshGoals = await completer.future;
          final endTime = DateTime.now();
          print('【GoalPage】BLoC方式刷新完成，耗时: ${endTime.difference(startTime).inMilliseconds}ms，获取 ${freshGoals.length} 个目标');
        } else {
          // 传统路径：直接从数据库刷新
          print('【GoalPage】使用传统方式刷新目标树');
          final startTime = DateTime.now();
          freshGoals = await _dbHelper.getGoalTree();
          final endTime = DateTime.now();
          print('【GoalPage】传统方式加载完成，耗时: ${endTime.difference(startTime).inMilliseconds}ms，获取 ${freshGoals.length} 个目标');
        }

        // 性能优化：更新缓存
        _updateCache(freshGoals);

        // 直接更新状态
        setState(() {
          allGoals = freshGoals;
          _isLoading = false;
        });

        if (mounted) {
          // 第二阶段迁移完成：统一使用BLoC事件刷新目标树
          context.read<GoalBloc>().add(const LoadGoals());
        }

        // 使用BLoC适配器刷新目标树（影子模式）
        print('【GoalPage】启动影子模式刷新目标树');
        _blocAdapter?.refreshGoalTree(
          onSuccess: (blocAllGoals) {
            print(
                '【GoalPage】BLoC刷新目标树成功 - 影子模式 - 目标数量: ${blocAllGoals.length}');

            // 在影子模式成功时也更新本地状态
            if (mounted && blocAllGoals.isNotEmpty) {
              print('【GoalPage】从影子模式更新本地目标树');
              // 比较数据差异
              if (blocAllGoals.length != allGoals.length) {
                print(
                    '【GoalPage】数据差异: 传统=${allGoals.length}, BLoC=${blocAllGoals.length}');
              }

              // 第二阶段迁移：影子模式数据同步，移除setState，依赖BLoC状态自动更新
              // 在影子模式下也更新本地状态，确保两种模式数据一致
              allGoals = blocAllGoals;

              // 同时更新goals列表
              if (widget.parentGoal == null) {
                goals = allGoals;
              } else {
                // 查找当前父目标的子目标
                final parentGoal = allGoals.firstWhere(
                  (g) => g.id == widget.parentGoal!.id,
                  orElse: () => widget.parentGoal!,
                );
                goals = parentGoal.subGoals;
              }
            }
          },
          onError: (error) {
            print('【GoalPage】BLoC刷新目标树失败 - 影子模式: $error');
          },
        );

        // 通知父组件目标树已更改
        widget.onGoalTreeChanged?.call();

        // 重要修复：设置loading状态为false
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = '加载数据失败: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  /// 添加新目标
  Future<void> _addNewGoal(Goal goal) async {
    try {
      // 根据页面类型设置正确的父目标ID
      if (widget.isSubGoalView &&
          currentGoal != null &&
          currentGoal!.parentId != null) {
        // 如果是子目标视图，使用当前目标的父目标ID（创建同级子目标）
        goal.parentId = currentGoal!.parentId;
        print(
            '【GoalPage】在子目标视图创建同级子目标: 父ID=${goal.parentId}, 标题=${goal.title}');
      } else {
        // 否则使用当前页面的父目标ID（创建子目标）
        goal.parentId = widget.parentGoal?.id;
        print('【GoalPage】创建子目标: 父ID=${goal.parentId}, 标题=${goal.title}');
      }

      // 批次3阶段2：CRUD操作统一通过BLoC
      if (_featureToggles.goalCRUDWriteThrough) {
        // 新路径：直接使用BLoC事件，由BLoC处理数据库操作
        context
            .read<GoalBloc>()
            .add(AddGoalWithDetails(goal, setAsCurrent: true, insertIndex: 0));
        print('【GoalPage】使用BLoC事件创建目标: 标题=${goal.title}, 父ID=${goal.parentId}');
      } else {
        // 传统路径：先保存到数据库，再同步BLoC状态
        final id = await _dbHelper.insertGoal(goal);
        goal.id = id;
        print('【GoalPage】传统方式创建目标成功: ID=$id, 父ID=${goal.parentId}');

        // 第二阶段迁移完成：统一使用BLoC事件新增目标
        if (_featureToggles.writeThroughBloc) {
          context
              .read<GoalBloc>()
              .add(AddGoalWithDetails(goal, setAsCurrent: true, insertIndex: 0));
        } else {
          // 阶段0：避免双写，使用只读同步刷新BLoC状态
          context.read<GoalBloc>().add(const LoadGoals());
          context.read<GoalBloc>().add(RefreshGoalTree());
          context.read<GoalBloc>().add(SelectGoal(goal));
        }
      }

      // 重要：刷新目标树，确保子目标显示在树中
      await _refreshGoalTreeUnified();

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        print('【GoalPage】通知父页面刷新目标树');
        widget.onGoalTreeChanged!();
      }

      // 使用BLoC适配器添加目标（影子模式）
      _blocAdapter?.addGoal(
        goal: goal,
        onSuccess: (blocGoal) {
          print(
              '【影子模式】子目标添加成功 - 目标ID: ${blocGoal.id}, 父ID: ${blocGoal.parentId}');

          // 记录操作结果比较
          _logBlocOperationResult(
            operation: '添加子目标',
            success: true,
            message: '目标ID: ${goal.id} vs BLoC目标ID: ${blocGoal.id}',
            data: {'goalId': goal.id, 'blocGoalId': blocGoal.id},
          );
        },
        onError: (error) {
          print('【影子模式】子目标添加失败: $error');

          // 记录操作结果比较
          _logBlocOperationResult(
            operation: '添加子目标',
            success: false,
            message: error,
            data: {'goalId': goal.id},
          );
        },
      );
    } catch (e) {
      print('【GoalPage】添加子目标失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加子目标失败: $e')),
      );
    }
  }

  /// 更新目标
  Future<void> _updateGoal(Goal goal) async {
    try {
      // 检查视频路径
      if (goal.hasVideo && goal.videoPath != null) {
        print('更新目标: 视频文件路径检查 ${goal.videoPath}');
        final videoFile = File(goal.videoPath!);
        if (!videoFile.existsSync()) {
          print('警告: 视频文件不存在 ${goal.videoPath}');
        }
      }

      // 批次3阶段2：CRUD操作统一通过BLoC
      if (_featureToggles.goalCRUDWriteThrough) {
        // 新路径：直接使用BLoC事件，由BLoC处理数据库操作
        context
            .read<GoalBloc>()
            .add(UpdateGoalWithValidation(goal, validateData: false));
        print('【GoalPage】使用BLoC事件更新目标: ID=${goal.id}, 标题=${goal.title}');
      } else {
        // 传统路径：先更新数据库，再同步BLoC状态
        await _dbHelper.updateGoal(goal);
        print('【GoalPage】传统方式更新目标成功: ID=${goal.id}, 标题=${goal.title}');

        // 阶段0：避免双写，根据开关决定是否通过BLoC写
        if (_featureToggles.writeThroughBloc) {
          context
              .read<GoalBloc>()
              .add(UpdateGoalWithValidation(goal, validateData: false));
        } else {
          context.read<GoalBloc>().add(const LoadGoals());
          context.read<GoalBloc>().add(RefreshGoalTree());
          // 如当前选中目标为此目标，确保选择保持
          if (currentGoal?.id == goal.id) {
            context.read<GoalBloc>().add(SelectGoal(goal));
          }
        }
      }

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        widget.onGoalTreeChanged!();
      }

      // 影子模式：通过BLoC适配器执行相同操作
      _blocAdapter?.updateGoal(
        goal: goal,
        onSuccess: () {
          print('【影子模式】目标更新成功：${goal.title}');
        },
        onError: (error) {
          print('【影子模式】目标更新失败：$error');
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新目标失败: $e')),
      );
    }
  }

  /// 删除目标
  Future<void> _deleteGoal(Goal goal) async {
    try {
      // 批次3阶段2：CRUD操作统一通过BLoC
      if (_featureToggles.goalCRUDWriteThrough) {
        // 新路径：直接使用BLoC事件，由BLoC处理数据库操作
        context
            .read<GoalBloc>()
            .add(DeleteGoalWithCleanup(goal, updateCurrent: true));
        print('【GoalPage】使用BLoC事件删除目标: ID=${goal.id}, 标题=${goal.title}');
      } else {
        // 传统路径：先删除数据库，再同步BLoC状态
        await _dbHelper.deleteGoal(goal.id!);
        print('【GoalPage】传统方式删除目标成功: ID=${goal.id}, 标题=${goal.title}');

        // 第二阶段迁移完成：统一使用BLoC事件删除目标
        if (_featureToggles.writeThroughBloc) {
          context
              .read<GoalBloc>()
              .add(DeleteGoalWithCleanup(goal, updateCurrent: true));
        } else {
          // 阶段0：避免双写，先删DB，再同步BLoC
          context.read<GoalBloc>().add(const LoadGoals());
          context.read<GoalBloc>().add(RefreshGoalTree());
          // 重新选择当前目标
          if (goals.isNotEmpty) {
            context.read<GoalBloc>().add(SelectGoal(goals.first));
          }
        }
      }

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        widget.onGoalTreeChanged!();
      }

      // 影子模式：通过BLoC适配器执行相同操作
      _blocAdapter?.deleteGoal(
        goalId: goal.id!,
        onSuccess: () {
          print('【影子模式】目标删除成功：${goal.title}');
        },
        onError: (error) {
          print('【影子模式】目标删除失败：$error');
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除条目失败: $e')),
      );
    }
  }

  // 修改现有的处理方法,使用新的统一方法
  Future<void> _handleDeleteGoalFromTree(Goal goal) async {
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    // 根据BLoC模式状态选择方法
    if (isBlocModeEnabled) {
      await _deleteGoalWithBloc(goal);
    } else {
      await _deleteGoal(goal);
    }
  }

  Future<void> _handleUpdateGoalStatusFromTree(
      Goal goal, GoalStatus newStatus) async {
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    // 创建更新后的目标
    final updatedGoal = goal.copyWith(status: newStatus);

    // 根据BLoC模式状态选择方法
    if (isBlocModeEnabled) {
      await _updateGoalWithBloc(updatedGoal);
    } else {
      await _updateGoal(updatedGoal);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 批次3阶段4：UI状态管理清理
    if (_featureToggles.uiStateWriteThrough) {
      // 新路径：完全基于BLoC状态的UI
      return _buildWithBlocBuilder(context);
    } else {
      // 传统路径：混合模式（传统状态 + BLoC监听）
      return _buildWithBlocListener(context);
    }
  }

  /// 批次3阶段4：基于BLoC状态的UI构建
  Widget _buildWithBlocBuilder(BuildContext context) {
    return BlocBuilder<GoalBloc, GoalState>(
      buildWhen: (previous, current) {
        // 优化重建性能：只在关键状态变化时重建
        if (current is GoalLoading) return true;
        if (current is GoalError) return true;
        if (current is GoalsLoaded) {
          if (previous is! GoalsLoaded) return true;
          // 检查关键数据是否变化
          return current.goals != previous.goals ||
                 current.allGoals != previous.allGoals ||
                 current.currentGoal != previous.currentGoal ||
                 current.viewMode != previous.viewMode;
        }
        return false;
      },
      builder: (context, state) {
        if (state is GoalLoading) {
          return _buildLoadingView();
        } else if (state is GoalError) {
          return _buildErrorView(state.message);
        } else if (state is GoalsLoaded) {
          return _buildMainUI(state);
        } else {
          return _buildLoadingView();
        }
      },
    );
  }

  /// 基于BLoC状态构建主UI
  Widget _buildMainUI(GoalsLoaded state) {
    // 使用BLoC状态而不是本地状态
    final goals = state.goals;
    final allGoals = state.allGoals;
    final currentGoal = state.currentGoal;
    final currentView = state.viewMode;

    return MultiBlocListener(
      listeners: [
        BlocListener<ComponentCommunicationBloc, ComponentCommunicationState>(
          listener: (context, state) {
            _handleComponentCommunication(state);
          },
        ),
      ],
      child: _buildScaffoldWithState(goals, allGoals, currentGoal, currentView),
    );
  }

  /// 基于传入状态构建Scaffold（用于BlocBuilder）
  Widget _buildScaffoldWithState(List<Goal> goals, List<Goal> allGoals, Goal? currentGoal, int currentView) {
    return Scaffold(
      extendBodyBehindAppBar: currentView == 0,
      appBar: _buildAppBarForBlocBuilder(currentView),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBodyForBlocBuilder(goals, allGoals, currentGoal, currentView),
          if (currentView == 0 && currentGoal != null)
            _buildFloatingActionButtonForBlocBuilder(currentGoal),
        ],
      ),
    );
  }

  /// 为BlocBuilder构建AppBar
  AppBar _buildAppBarForBlocBuilder(int currentView) {
    return AppBar(
      title: Text(widget.parentGoal?.title ?? '临在意识'),
      backgroundColor: currentView == 0 ? Colors.transparent : Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(
        color: currentView == 0 ? Colors.white : Colors.black,
      ),
      titleTextStyle: TextStyle(
        color: currentView == 0 ? Colors.white : Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 为BlocBuilder构建Body
  Widget _buildBodyForBlocBuilder(List<Goal> goals, List<Goal> allGoals, Goal? currentGoal, int currentView) {
    // 简化版本：基于传入的状态参数构建UI
    switch (currentView) {
      case 0:
        return _buildFullScreenViewForBlocBuilder(currentGoal);
      case 1:
        return _buildTimelineViewForBlocBuilder(goals, currentGoal);
      case 2:
        return _buildGridViewForBlocBuilder(goals);
      default:
        return _buildFullScreenViewForBlocBuilder(currentGoal);
    }
  }

  /// 为BlocBuilder构建全屏视图
  Widget _buildFullScreenViewForBlocBuilder(Goal? currentGoal) {
    if (currentGoal == null) {
      return const Center(child: Text('没有选中的目标'));
    }

    // 简化实现：复用现有的全屏视图构建逻辑
    return _buildFullScreenView();
  }

  /// 为BlocBuilder构建时间轴视图
  Widget _buildTimelineViewForBlocBuilder(List<Goal> goals, Goal? currentGoal) {
    // 简化实现：复用现有的时间轴视图构建逻辑
    return _buildTimelineView();
  }

  /// 为BlocBuilder构建网格视图
  Widget _buildGridViewForBlocBuilder(List<Goal> goals) {
    // 简化实现：复用现有的网格视图构建逻辑
    return _buildGridView();
  }

  /// 为BlocBuilder构建浮动按钮
  Widget _buildFloatingActionButtonForBlocBuilder(Goal currentGoal) {
    // 简化实现：复用现有的浮动按钮构建逻辑
    return _buildFloatingActionButton();
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '错误: $message',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<GoalBloc>().add(const LoadGoals());
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建初始视图
  Widget _buildInitialView() {
    return const Scaffold(
      body: Center(
        child: Text('正在初始化...'),
      ),
    );
  }

  // 已移除：未使用的BLoC状态构建方法已清理

  /// 构建AppBar - 基于BLoC状态
  PreferredSizeWidget _buildAppBarWithState(GoalsLoaded state) {
    return AppBar(
      title: Text(widget.parentGoal?.title ?? '临在意识'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        color: state.viewMode == 0 ? Colors.white : Colors.black,
      ),
      actions: [
        // 已移除：搜索按钮
        IconButton(
          icon: Image.asset(
            state.viewMode == 0
                ? 'assets/icons/View-switch-white.png'
                : state.viewMode == 1
                    ? 'assets/icons/View-switch-white.png'
                    : 'assets/icons/View-switch-white.png',
            width: 24,
            height: 24,
            color: state.viewMode == 0 ? Colors.white : Colors.black,
          ),
          onPressed: () {
            // 使用BLoC事件切换视图
            final nextView = (state.viewMode + 1) % 3;
            context.read<GoalBloc>().add(ToggleViewMode(nextView));
          },
        ),
        // 在全屏视图且有当前目标时显示操作菜单
        if (state.viewMode == 0 && state.currentGoal != null)
          _buildGoalOperationMenuWithState(state),
      ],
    );
  }

  /// 构建目标操作菜单 - 基于BLoC状态
  Widget _buildGoalOperationMenuWithState(GoalsLoaded state) {
    return GoalOperationMenu(
      currentGoal: state.currentGoal,
      onStatusChange: () {
        if (state.currentGoal != null) {
          _showStatusDialog(state.currentGoal!);
        }
      },
      onDelete: _deleteCurrentGoal,
      onShare: () {
        if (state.currentGoal != null) {
          _showShareDialog(state.currentGoal!);
        }
      },
      // 倒计时功能已移除
      onToggleTime: () {
        context.read<GoalBloc>().add(ToggleTimeDisplay(!state.showTime));
      },
      showTime: state.showTime,
      onToggleDescription: () {
        context
            .read<GoalBloc>()
            .add(ToggleDescriptionDisplay(!state.showDescription));
      },
      showDescription: state.showDescription,
      onToggleTitle: () {
        context.read<GoalBloc>().add(ToggleTitleDisplay(!state.showTitle));
      },
      showTitle: state.showTitle,
      onToggleDeadline: () {
        if (state.currentGoal != null) {
          _toggleDeadline(state.currentGoal!);
        }
      },
      onAddSubGoal: () {
        // 智能子条目管理：如果有子条目则查看，没有则新增
        if (state.currentGoal != null &&
            state.currentGoal!.subGoals.isNotEmpty) {
          _viewSubGoalsWithState(state);
        } else {
          _addSubGoalFromFullScreenWithState(state);
        }
      },
      // 倒计时功能已移除
      onViewSubGoals: () {
        _viewSubGoalsWithState(state);
      },
    );
  }

  /// 构建当前视图 - 基于BLoC状态
  Widget _buildCurrentViewWithState(GoalsLoaded state) {
    switch (state.viewMode) {
      case 0:
        return _buildFullScreenViewWithState(state);
      case 1:
        return _buildTimelineViewWithState(state);
      case 2:
        return _buildGridViewWithState(state);
      case 3:
        return _buildGoalTreeViewWithState(state);
      case 4:
        return _buildExploreViewWithState(state);
      default:
        return const Center(
          child: Text(
            '未知视图模式',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }

  /// 构建全屏视图 - 基于BLoC状态
  Widget _buildFullScreenViewWithState(GoalsLoaded state) {
    // 如果没有当前目标，显示空状态
    if (state.currentGoal == null) {
      return const Center(
        child: Text(
          '请选择一个目标',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return FullScreenView(
      currentGoal: state.currentGoal!,
      goals: state.goals,
      onGoalSelect: (goal) {
        _selectGoal(goal);
      },
      showTime: state.showTime,
      showDescription: state.showDescription,
      showTitle: state.showTitle,
      isEditingTitle: state.isEditingTitle,
      titleController: _titleController,
      onTitleEdit: () {
        context.read<GoalBloc>().add(const StartEditingTitle());
      },
      onTitleSave: () {
        final title = _titleController.text;
        context.read<GoalBloc>().add(SaveTitle(title));
      },
      onDescriptionEdit: () {
        _startDescriptionEdit();
      },
      // 批次2重构：添加描述编辑参数，与标题编辑保持一致
      isEditingDescription: state.isEditingDescription,
      descriptionController: _descriptionController,
      onDescriptionSave: () {
        final description = _descriptionController.text;
        context.read<GoalBloc>().add(SaveDescription(description));
      },
      onImagePick: _pickImage,
      onToggleTitle: _toggleShowTitle,
      onAddGoal: _addNewGoalWrapper,
      onAddSubGoal: () => _addSubGoalFromFullScreenWithState(state),
      // 倒计时功能已移除
    );
  }

  /// 构建时间轴视图 - 基于BLoC状态
  Widget _buildTimelineViewWithState(GoalsLoaded state) {
    // 基于 BLoC 的当前目标和列表渲染高亮，仅限只读渲染，小步替换
    final items = widget.parentGoal == null
        ? state.allGoals.where((g) => g.parentId == null).toList()
        : state.allGoals.where((g) => g.parentId == widget.parentGoal!.id).toList();

    return TimelineView(
      goals: items,
      isSubgoal: widget.parentGoal != null,
      currentGoalId: state.currentGoal?.id,
      onGoalSelect: (goal) {
        // 批次2：使用统一的目标选择方法
        _selectGoal(goal);
        // 切换到全屏视图
        if (_featureToggles.viewModeWriteThrough) {
          context.read<GoalBloc>().add(const ToggleViewMode(0));
        } else {
          setState(() {
            currentView = 0;
          });
          context.read<GoalBloc>().add(const ToggleViewMode(0));
        }
      },
      onAddGoal: _showAddGoalDialog,
      onSaveNewGoal: (title, description, imagePath, selectedDate) {
        final newGoal = Goal(
          title: title,
          description: description,
          imagePath: imagePath ?? 'assets/images/default/default.jpg',
          createdTime: DateTime.now(),
          targetDate: selectedDate,
          parentId: widget.parentGoal?.id,
        );
        _addNewGoal(newGoal);
      },
      onUpdateGoalDate: (goal, newDate) async {
        try {
          final updatedGoal = goal.copyWith(targetDate: newDate);
          await _updateGoal(updatedGoal);
          return true;
        } catch (e) {
          print('更新目标日期失败: $e');
          return false;
        }
      },
    );
  }

  /// 构建网格视图 - 基于BLoC状态
  Widget _buildGridViewWithState(GoalsLoaded state) {
    // 只读渲染：使用 BLoC 的 allGoals 按父子关系过滤
    final items = widget.parentGoal == null
        ? state.allGoals.where((g) => g.parentId == null).toList()
        : state.allGoals.where((g) => g.parentId == widget.parentGoal!.id).toList();

    return GoalGridView(
      goals: items,
      currentGoalId: state.currentGoal?.id,
      onGoalSelect: (goal) {
        // 批次2：使用统一的目标选择方法
        _selectGoal(goal);
        context.read<GoalBloc>().add(const ToggleViewMode(0));
      },
      onAddGoal: _showAddGoalDialog,
      onShowOperationMenu: (context, goal) {
        _showDeleteGoalDialog(goal);
      },
    );
  }

  /// 构建目标树视图 - 基于BLoC状态
  Widget _buildGoalTreeViewWithState(GoalsLoaded state) {
    // 暂时使用原有的抽屉构建方法，后续优化
    return _buildDrawer();
  }

  /// 构建探索视图 - 基于BLoC状态
  Widget _buildExploreViewWithState(GoalsLoaded state) {
    return ExploreView(
      onSelectCard: (card) {
        context.read<GoalBloc>().add(SelectGoal(card));
        context.read<GoalBloc>().add(const ToggleViewMode(0));
      },
    );
  }

  /// 原有的BlocListener实现 - 保留作为备份
  Widget _buildWithBlocListener(BuildContext context) {
    // 检查是否启用了任何BLoC功能
    final bool isBlocEnabled = _blocAdapter?.executeMode ?? false;

    // 重要修复：即使在影子模式下，也需要监听BLoC事件来保持状态同步
    // BlocListener只监听状态，不参与UI构建，因此可以安全地在其回调中调用setState
    return MultiBlocListener(
      listeners: [
        BlocListener<GoalBloc, GoalState>(
          // 放宽过滤：任何 GoalState 变化都尝试同步，由内部批处理与节流控制频率
          listenWhen: (previous, current) {
            print('【调试】BlocListener.listenWhen: ${previous.runtimeType} -> ${current.runtimeType}');
            return true;
          },
          listener: (context, state) {
            print('【调试】BlocListener.listener被调用: ${state.runtimeType}');
            if (state is GoalsLoaded) {
              syncStateFromBloc(state);
            }
          },
        ),
        BlocListener<ComponentCommunicationBloc, ComponentCommunicationState>(
          listener: (context, state) {
            _handleComponentCommunication(state);
          },
        ),
        // 添加ComponentCommunicationBloc监听器

      ],
      // 保持原有UI构建不变
      child: _buildScaffold(),
    );
  }

  // 处理组件通信事件
  void _handleComponentCommunication(ComponentCommunicationState state) {
    if (state is NavigationRequested) {
      // 处理导航请求
      switch (state.routeName) {
        case '/settings':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
          break;
        case '/login':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
          break;
        case '/membership':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MembershipPage()),
          );
          break;
        default:
          print('未处理的导航请求: ${state.routeName}');
      }
    } else if (state is DialogRequested) {
      // 处理对话框请求
      switch (state.type) {
        // 已移除：搜索功能
        default:
          print('未处理的对话框请求: ${state.type}');
      }
    } else if (state is MessageRequested) {
      // 处理消息显示请求
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: state.type == 'error'
              ? Colors.red
              : state.type == 'success'
                  ? Colors.green
                  : Colors.blue,
          duration: state.duration ?? const Duration(seconds: 3),
        ),
      );
    }
  }

  // 从BLoC状态同步到本地状态的方法
  void syncStateFromBloc(GoalsLoaded state) {
    try {
      print('【GoalPage】同步BLoC状态到本地状态');

      // 添加防抖机制，避免短时间内多次触发同步
      final now = DateTime.now();
      if (now.difference(_lastSyncTime).inMilliseconds < 100) {
        print('【GoalPage】忽略过于频繁的状态同步');
        return;
      }
      _lastSyncTime = now;

      final syncStartTime = DateTime.now();

      // 第二阶段迁移：BLoC状态同步已经自动处理数据更新，移除手动setState
      // 性能优化：同步目标树数据使用批处理
      if (state.allGoals.isNotEmpty) {
        print('【GoalPage】同步目标树数据: ${state.allGoals.length} 个目标');

        // 更新缓存
        _updateCache(state.allGoals);

        // 批处理更新状态
        _batchStateUpdate('allGoals', state.allGoals);

        // 计算goals列表
        List<Goal> newGoals;
        if (widget.parentGoal == null) {
          newGoals =
              state.allGoals.where((goal) => goal.parentId == null).toList();
        } else {
          final parentGoal = state.allGoals.firstWhere(
            (g) => g.id == widget.parentGoal!.id,
            orElse: () => widget.parentGoal!,
          );
          newGoals = parentGoal.subGoals;
        }
        _batchStateUpdate('goals', newGoals);
      } else {
        print('【GoalPage】警告: BLoC返回的目标树为空，保留本地数据');
      }

      // 只在启用了对应功能且状态确实变化时才更新

      // 标题编辑状态
      if (_featureToggles.titleEditing &&
          _isEditingTitle != state.isEditingTitle) {
        print(
            '【GoalPage】同步标题编辑状态: ${_isEditingTitle} -> ${state.isEditingTitle}');
        setState(() {
          _isEditingTitle = state.isEditingTitle;
        });
      }

      // 同步标题内容（如果处于编辑状态）
      if (_featureToggles.titleEditing &&
          state.isEditingTitle &&
          state.currentGoal != null &&
          _titleController.text.isEmpty) {
        _titleController.text = state.currentGoal!.title;
      }

      // 批次2：当前目标同步（支持灰度模式）
      if (state.currentGoal != null &&
          (currentGoal == null || currentGoal!.id != state.currentGoal!.id)) {
        print(
            '【GoalPage】同步当前目标: ${currentGoal?.id} -> ${state.currentGoal!.id}');

        if (_featureToggles.currentGoalSelectionWriteThrough) {
          // 批次2灰度：只读同步，不通过setState改变
          currentGoal = state.currentGoal;
          // 同时更新goals列表中的对应项
          if (state.goals.isNotEmpty) {
            goals = state.goals;
          }
          print('【批次2灰度】currentGoal只读同步: ${currentGoal?.id}');
        } else {
          // 传统模式：使用setState更新currentGoal以触发UI重建
          setState(() {
            currentGoal = state.currentGoal;
            // 同时更新goals列表中的对应项
            if (state.goals.isNotEmpty) {
              goals = state.goals;
            }
          });
        }

        // 确保标题编辑器内容与当前目标匹配
        if (_isEditingTitle) {
          _titleController.text = state.currentGoal!.title;
        }
      } else if (state.currentGoal != null &&
          currentGoal != null &&
          currentGoal!.id == state.currentGoal!.id) {
        // 同一目标的属性更新
        bool needsUpdate = false;
        Goal updatedGoal = currentGoal!;

        // 检查标题更新
        if (currentGoal!.title != state.currentGoal!.title) {
          print(
              '【GoalPage】同步目标标题: ${currentGoal!.title} -> ${state.currentGoal!.title}');
          updatedGoal = updatedGoal.copyWith(title: state.currentGoal!.title);
          needsUpdate = true;
        }

        // 检查描述更新（批次2：支持新的描述编辑开关）
        if ((_featureToggles.descriptionEditing || _featureToggles.descriptionEditingWriteThrough) &&
            currentGoal!.description != state.currentGoal!.description) {
          print(
              '【GoalPage】同步目标描述: ${currentGoal!.description} -> ${state.currentGoal!.description}');
          updatedGoal =
              updatedGoal.copyWith(description: state.currentGoal!.description);
          needsUpdate = true;
        }

        // 检查状态更新
        if (currentGoal!.status != state.currentGoal!.status) {
          print(
              '【GoalPage】同步目标状态: ${currentGoal!.status} -> ${state.currentGoal!.status}');
          updatedGoal = updatedGoal.copyWith(status: state.currentGoal!.status);
          needsUpdate = true;
        }

        // 检查日期更新
        if (currentGoal!.targetDate != state.currentGoal!.targetDate) {
          print(
              '【GoalPage】同步目标日期: ${currentGoal!.targetDate} -> ${state.currentGoal!.targetDate}');
          updatedGoal =
              updatedGoal.copyWith(targetDate: state.currentGoal!.targetDate);
          needsUpdate = true;
        }

        // 检查自定义倒计时更新
        if (currentGoal!.hasCustomCountdown !=
                state.currentGoal!.hasCustomCountdown ||
            currentGoal!.customCountdownDays !=
                state.currentGoal!.customCountdownDays) {
          print(
              '【GoalPage】同步自定义倒计时: ${currentGoal!.customCountdownDays} -> ${state.currentGoal!.customCountdownDays}');
          updatedGoal = updatedGoal.copyWith(
              hasCustomCountdown: state.currentGoal!.hasCustomCountdown,
              customCountdownDays: state.currentGoal!.customCountdownDays);
          needsUpdate = true;
        }

        // 检查图片/视频更新
        if (currentGoal!.imagePath != state.currentGoal!.imagePath ||
            currentGoal!.videoPath != state.currentGoal!.videoPath ||
            currentGoal!.hasVideo != state.currentGoal!.hasVideo) {
          print(
              '【GoalPage】同步目标媒体: 图片=${state.currentGoal!.imagePath}, 视频=${state.currentGoal!.videoPath}');
          updatedGoal = updatedGoal.copyWith(
              imagePath: state.currentGoal!.imagePath,
              videoPath: state.currentGoal!.videoPath,
              hasVideo: state.currentGoal!.hasVideo);
          needsUpdate = true;
        }

        // 如果有任何属性更新，则更新当前目标
        if (needsUpdate) {
          setState(() {
            currentGoal = updatedGoal;

            // 同时更新goals列表中的对应项
            final index = goals.indexWhere((g) => g.id == updatedGoal.id);
            if (index != -1) {
              goals[index] = updatedGoal;
            }
          });
        }
      }

      // 其他状态同步...
      // 例如视图模式、UI显示选项等
      // 倒计时功能已移除

      if (state.showTime != _showTime) {
        setState(() {
          _showTime = state.showTime;
        });
      }

      if (state.showDescription != _showDescription) {
        setState(() {
          _showDescription = state.showDescription;
        });
      }

      if (state.showTitle != _showTitle) {
        if (_featureToggles.titleDisplayWriteThrough) {
          // 批次1灰度：只读同步，不通过setState改变
          _showTitle = state.showTitle;
          print('【批次1灰度】showTitle只读同步: $_showTitle');
        } else {
          // 传统模式：通过setState同步
          setState(() {
            _showTitle = state.showTitle;
          });
        }
      }

      if (state.showDescription != _showDescription) {
        if (_featureToggles.descriptionDisplayWriteThrough) {
          // 批次1灰度：只读同步，不通过setState改变
          _showDescription = state.showDescription;
          print('【批次1灰度】showDescription只读同步: $_showDescription');
        } else {
          // 传统模式：通过setState同步
          setState(() {
            _showDescription = state.showDescription;
          });
        }
      }

      if (state.showTime != _showTime) {
        if (_featureToggles.timeDisplayWriteThrough) {
          // 批次1灰度：只读同步，不通过setState改变
          _showTime = state.showTime;
          print('【批次1灰度】showTime只读同步: $_showTime');
        } else {
          // 传统模式：通过setState同步
          setState(() {
            _showTime = state.showTime;
          });
        }
      }

      // 同步视图模式
      if (state.viewMode != currentView) {
        if (_featureToggles.viewModeWriteThrough) {
          // 批次1灰度：只读同步，不通过setState改变
          currentView = state.viewMode;
          print('【批次1灰度】viewMode只读同步: $currentView');
        } else {
          // 传统模式：通过setState同步
          setState(() {
            currentView = state.viewMode;
          });
        }
      }

      // 批次2：编辑状态同步
      if (state.isEditingTitle != _isEditingTitle) {
        if (_featureToggles.titleEditingWriteThrough) {
          // 批次2灰度：只读同步编辑状态
          _isEditingTitle = state.isEditingTitle;
          print('【批次2灰度】titleEditing只读同步: $_isEditingTitle');

          // 同步编辑内容到TextEditingController
          if (state.isEditingTitle &&
              state.currentGoal != null &&
              _titleController.text != state.currentGoal!.title) {
            _titleController.text = state.currentGoal!.title;
            print('【批次2灰度】同步标题到编辑器: ${state.currentGoal!.title}');
          }
        } else {
          // 传统模式：通过setState同步
          setState(() {
            _isEditingTitle = state.isEditingTitle;
          });
        }
      }

      // 批次2：描述编辑状态同步
      if (state.isEditingDescription != _isEditingDescription) {
        if (_featureToggles.descriptionEditingWriteThrough) {
          // 批次2灰度：只读同步编辑状态
          _isEditingDescription = state.isEditingDescription;
          print('【批次2灰度】descriptionEditing只读同步: $_isEditingDescription');
        } else {
          // 传统模式：通过setState同步
          setState(() {
            _isEditingDescription = state.isEditingDescription;
          });
        }
      }

      // 添加数据一致性验证
      if (allGoals.length != state.allGoals.length &&
          state.allGoals.isNotEmpty) {
        print(
            '【警告】同步后数据不一致: 本地=${allGoals.length}, BLoC=${state.allGoals.length}');
      }

      // 记录同步耗时
      final syncEndTime = DateTime.now();
      print(
          '【性能】状态同步耗时: ${syncEndTime.difference(syncStartTime).inMilliseconds}ms');
    } catch (e) {
      print('【GoalPage】状态同步出错: $e');
    }
  }

  // 构建传统UI的方法（与原有方法保持一致）
  Widget _buildScaffold() {
    return Scaffold(
      extendBodyBehindAppBar: _featureToggles.viewModeWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0
              : true)
          : currentView == 0,
      appBar: _buildAppBarTraditional(),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (_featureToggles.viewModeWriteThrough
              ? (context.read<GoalBloc>().state is GoalsLoaded
                  ? (context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0
                  : true)
              : currentView == 0)
            // 全屏视图的背景
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: _featureToggles.currentGoalSelectionWriteThrough
                      ? (context.read<GoalBloc>().state is GoalsLoaded
                          ? ((context.read<GoalBloc>().state as GoalsLoaded).currentGoal?.imagePath != null &&
                              (context.read<GoalBloc>().state as GoalsLoaded).currentGoal!.imagePath.isNotEmpty
                              ? _getImageProvider((context.read<GoalBloc>().state as GoalsLoaded).currentGoal!.imagePath)
                              : AssetImage('assets/images/default/default.jpg'))
                          : AssetImage('assets/images/default/default.jpg'))
                      : (currentGoal?.imagePath != null &&
                          currentGoal!.imagePath.isNotEmpty
                      ? _getImageProvider(currentGoal!.imagePath)
                      : AssetImage('assets/images/default/default.jpg')),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_featureToggles.viewModeWriteThrough
              ? (context.read<GoalBloc>().state is GoalsLoaded
                  ? (context.read<GoalBloc>().state as GoalsLoaded).viewMode != 0
                  : false)
              : currentView != 0)
            Container(
              color: Colors.white,
            ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Center(
              child: Text(_error!),
            )
          else
            IndexedStack(
              index: _featureToggles.viewModeWriteThrough
                  ? (context.read<GoalBloc>().state is GoalsLoaded
                      ? (context.read<GoalBloc>().state as GoalsLoaded).viewMode
                      : 0)
                  : currentView,
              children: [
                Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                    ),
                    _buildFullScreenView(),
                  ],
                ),
                // 使用BLoC状态渲染时间轴（只读）
                BlocBuilder<GoalBloc, GoalState>(
                  builder: (context, state) {
                    if (state is GoalsLoaded) {
                      return _buildTimelineViewWithState(state);
                    }
                    return _buildTimelineView();
                  },
                ),
                // 使用BLoC状态渲染网格（只读 + 高亮 + 可点击回到全屏）
                BlocBuilder<GoalBloc, GoalState>(
                  builder: (context, state) {
                    if (state is GoalsLoaded) {
                      return _buildGridViewWithState(state);
                    }
                    return _buildGridView();
                  },
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// 构建传统AppBar
  AppBar _buildAppBarTraditional() {
    return AppBar(
      backgroundColor: _featureToggles.viewModeWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? Colors.transparent : Colors.white)
              : Colors.transparent)
          : (currentView == 0 ? Colors.transparent : Colors.white),
      elevation: _featureToggles.viewModeWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? 0 : 1)
              : 0)
          : (currentView == 0 ? 0 : 1),
      centerTitle: true,
      leading: Builder(
        builder: (BuildContext context) => IconButton(
          icon: Image.asset(
            'assets/icons/Menu-white.png',
            width: 24,
            height: 24,
            color: _featureToggles.viewModeWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? Colors.white : Colors.black)
                    : Colors.white)
                : (currentView == 0 ? Colors.white : Colors.black),
          ),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: widget.parentGoal != null
          ? GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                widget.parentGoal!.title.length > 9
                    ? widget.parentGoal!.title.substring(0, 9) + '…'
                    : widget.parentGoal!.title,
                style: TextStyle(
                  fontSize: 18,
                  color: _featureToggles.viewModeWriteThrough
                      ? (context.read<GoalBloc>().state is GoalsLoaded
                          ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? Colors.white : Colors.black)
                          : Colors.white)
                      : (currentView == 0 ? Colors.white : Colors.black),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'STZhongsong',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
      iconTheme: IconThemeData(
        color: _featureToggles.viewModeWriteThrough
            ? (context.read<GoalBloc>().state is GoalsLoaded
                ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? Colors.white : Colors.black)
                : Colors.white)
            : (currentView == 0 ? Colors.white : Colors.black),
      ),
      actions: [
        IconButton(
          icon: Image.asset(
            _featureToggles.viewModeWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0
                        ? 'assets/icons/View-switch-white.png'
                        : (context.read<GoalBloc>().state as GoalsLoaded).viewMode == 1
                            ? 'assets/icons/View-switch-white.png'
                            : 'assets/icons/View-switch-white.png')
                    : 'assets/icons/View-switch-white.png')
                : (currentView == 0
                    ? 'assets/icons/View-switch-white.png'
                    : currentView == 1
                        ? 'assets/icons/View-switch-white.png'
                        : 'assets/icons/View-switch-white.png'),
            width: 24,
            height: 24,
            color: _featureToggles.viewModeWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? ((context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0 ? Colors.white : Colors.black)
                    : Colors.white)
                : (currentView == 0 ? Colors.white : Colors.black),
          ),
          onPressed: _onChangeView,
        ),
        // 调试：重置数据库按钮
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await _resetDatabaseForTesting();
          },
          tooltip: '重置数据库',
        ),
        if ((_featureToggles.viewModeWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).viewMode == 0
                    : true)
                : currentView == 0) &&
            (_featureToggles.currentGoalSelectionWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).currentGoal != null
                    : false)
                : currentGoal != null))
          (_featureToggles.displayOptionsBlocDriven
              ? BlocBuilder<GoalBloc, GoalState>(
                  buildWhen: (prev, curr) {
                    if (prev is GoalsLoaded && curr is GoalsLoaded) {
                      return prev.showTitle != curr.showTitle ||
                          prev.showDescription != curr.showDescription ||
                          prev.showTime != curr.showTime;
                    }
                    return prev.runtimeType != curr.runtimeType;
                  },
                  builder: (context, state) {
                    if (state is GoalsLoaded) {
                      return GoalOperationMenu(
                        currentGoal: state.currentGoal,
                        onStatusChange: () {
                          if (state.currentGoal != null) {
                            _showStatusDialog(state.currentGoal!);
                          }
                        },
                        onDelete: _deleteCurrentGoal,
                        onShare: () {
                          if (state.currentGoal != null) {
                            _showShareDialog(state.currentGoal!);
                          }
                        },
                        // 倒计时功能已移除
                        onToggleTime: () {
                          context.read<GoalBloc>().add(ToggleTimeDisplay(!state.showTime));
                        },
                        showTime: state.showTime,
                        onToggleDescription: () {
                          context.read<GoalBloc>().add(ToggleDescriptionDisplay(!state.showDescription));
                        },
                        showDescription: state.showDescription,
                        onToggleTitle: () {
                          context.read<GoalBloc>().add(ToggleTitleDisplay(!state.showTitle));
                        },
                        showTitle: state.showTitle,
                        onToggleDeadline: () {
                          if (state.currentGoal != null) {
                            _toggleDeadline(state.currentGoal!);
                          }
                        },
                        onAddSubGoal: () {
                          _addSubGoalFromFullScreen();
                        },
                        // 倒计时功能已移除
                        onViewSubGoals: _viewSubGoals,
                      );
                    }
                    // 回退到本地渲染
                    return GoalOperationMenu(
                      currentGoal: currentGoal,
                      onStatusChange: () {
                        if (currentGoal != null) {
                          _showStatusDialog(currentGoal!);
                        }
                      },
                      onDelete: _deleteCurrentGoal,
                      onShare: () {
                        if (currentGoal != null) {
                          _showShareDialog(currentGoal!);
                        }
                      },
                      // 倒计时功能已移除
                      onToggleTime: _toggleShowTime,
                      showTime: _featureToggles.timeDisplayWriteThrough
                          ? (context.read<GoalBloc>().state is GoalsLoaded
                              ? (context.read<GoalBloc>().state as GoalsLoaded).showTime
                              : true)
                          : _showTime,
                      onToggleDescription: _toggleShowDescription,
                      showDescription: _featureToggles.descriptionDisplayWriteThrough
                          ? (context.read<GoalBloc>().state is GoalsLoaded
                              ? (context.read<GoalBloc>().state as GoalsLoaded).showDescription
                              : true)
                          : _showDescription,
                      onToggleTitle: _toggleShowTitle,
                      showTitle: _featureToggles.titleDisplayWriteThrough
                          ? (context.read<GoalBloc>().state is GoalsLoaded
                              ? (context.read<GoalBloc>().state as GoalsLoaded).showTitle
                              : true)
                          : _showTitle,
                      onToggleDeadline: () {
                        if (currentGoal != null) {
                          _toggleDeadline(currentGoal!);
                        }
                      },
                      onAddSubGoal: () {
                        _addSubGoalFromFullScreen();
                      },
                      // 倒计时功能已移除
                      onViewSubGoals: _viewSubGoals,
                    );
                  },
                )
              : GoalOperationMenu(
                  currentGoal: currentGoal,
                  onStatusChange: () {
                    if (currentGoal != null) {
                      _showStatusDialog(currentGoal!);
                    }
                  },
                  onDelete: _deleteCurrentGoal,
                  onShare: () {
                    if (currentGoal != null) {
                      _showShareDialog(currentGoal!);
                    }
                  },
                  // 倒计时功能已移除
                  onToggleTime: _toggleShowTime,
                  showTime: _featureToggles.timeDisplayWriteThrough
                      ? (context.read<GoalBloc>().state is GoalsLoaded
                          ? (context.read<GoalBloc>().state as GoalsLoaded).showTime
                          : true)
                      : _showTime,
                  onToggleDescription: _toggleShowDescription,
                  showDescription: _featureToggles.descriptionDisplayWriteThrough
                      ? (context.read<GoalBloc>().state is GoalsLoaded
                          ? (context.read<GoalBloc>().state as GoalsLoaded).showDescription
                          : true)
                      : _showDescription,
                  onToggleTitle: _toggleShowTitle,
                  showTitle: _featureToggles.titleDisplayWriteThrough
                      ? (context.read<GoalBloc>().state is GoalsLoaded
                          ? (context.read<GoalBloc>().state as GoalsLoaded).showTitle
                          : true)
                      : _showTitle,
                  onToggleDeadline: () {
                    if (currentGoal != null) {
                      _toggleDeadline(currentGoal!);
                    }
                  },
                  onAddSubGoal: () {
                    _addSubGoalFromFullScreen();
                  },
                  // 倒计时功能已移除
                  onViewSubGoals: _viewSubGoals,
                )),
      ],
    );
  }



  // 日志方法，用于追踪BLoC相关操作
  void _log(String message, [bool forceLog = false]) {
    if ((_blocAdapter?.logLevel ?? 0) > 1 || forceLog) {
      debugPrint('【GoalPage】$message');
    }
  }

  void _onChangeView() {
    // 批次1灰度实施：viewMode写路径BLoC化
    if (_featureToggles.viewModeWriteThrough) {
      // 新路径：Guard检查 + BLoC状态取值 + 事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded) {
        // 性能监控开始
        UIStatePerformanceMonitor.startMeasure('viewMode_toggle');
        UIStatePerformanceMonitor.recordEvent('viewMode_toggle');

        // 从BLoC状态计算下一个视图模式，确保一致性
        final nextView = (currentState.viewMode + 1) % 3;
        context.read<GoalBloc>().add(ToggleViewMode(nextView));

        print('【批次1灰度】viewMode切换: ${currentState.viewMode} -> $nextView');
      } else {
        // Guard保护：非GoalsLoaded状态禁用操作
        UIStatePerformanceMonitor.recordError('viewMode_toggle');
        print('【批次1灰度】viewMode切换被禁用：当前状态${currentState.runtimeType}');
      }
    } else {
      // 传统路径：完全保持不变
      final nextView = (currentView + 1) % 3;
      setState(() {
        currentView = nextView;
      });
      context.read<GoalBloc>().add(ToggleViewMode(nextView));
      print('【传统模式】viewMode切换: $currentView -> $nextView');
    }
  }

  // 全屏视图
  Widget _buildFullScreenView() {
    if (goals.isEmpty || currentGoal == null) {
      return const Center(child: Text('没有目标'));
    }

    // 当开启全屏只读渲染时，从 BLoC 状态驱动 showXxx，并直接派发事件
    if (_featureToggles.fullScreenBlocDriven) {
      return BlocBuilder<GoalBloc, GoalState>(
        buildWhen: (prev, curr) {
          if (prev is GoalsLoaded && curr is GoalsLoaded) {
            return prev.showTitle != curr.showTitle ||
                prev.showDescription != curr.showDescription ||
                prev.showTime != curr.showTime ||
                prev.currentGoal?.id != curr.currentGoal?.id ||
                prev.isEditingTitle != curr.isEditingTitle ||
                prev.isEditingDescription != curr.isEditingDescription;
          }
          return prev.runtimeType != curr.runtimeType;
        },
        builder: (context, state) {
          if (state is GoalsLoaded) {
            return FullScreenView(
              currentGoal: _featureToggles.currentGoalSelectionWriteThrough
                  ? state.currentGoal
                  : currentGoal,
              goals: state.goals, // 批次2修复：使用BLoC状态中的最新goals数据
              isEditingTitle: _featureToggles.titleEditingWriteThrough
                  ? state.isEditingTitle
                  : _isEditingTitle,
              titleController: _titleController,
              onTitleEdit: _startTitleEdit,
              onTitleSave: _saveTitleEdit,
              onDescriptionEdit: () {
                _startDescriptionEdit();
              },
              // 批次2重构：添加描述编辑参数，与标题编辑保持一致
              isEditingDescription: _featureToggles.descriptionEditingWriteThrough
                  ? state.isEditingDescription
                  : _isEditingDescription,
              descriptionController: _descriptionController,
              onDescriptionSave: () {
                final description = _descriptionController.text;
                context.read<GoalBloc>().add(SaveDescription(description));
              },
              onSaveDescription: _updateGoalDescription, // 保留兼容性
              onImagePick: _pickImage,
              onGoalSelect: (goal) {
                _selectGoal(goal);
              },
              onAddGoal: () => _addNewGoalWrapper(),
              onStatusChange: _handleUpdateGoalStatusSimple,
              onUpdateDate: _updateGoalDate,
              showTime: state.showTime,
              showDescription: state.showDescription,
              showTitle: state.showTitle,
              onToggleTitle: () {
                context
                    .read<GoalBloc>()
                    .add(ToggleTitleDisplay(!state.showTitle));
              },
              onToggleDeadline: _toggleDeadline,
              onAddSubGoal: () => _addSubGoalFromFullScreen(),
              // 倒计时功能已移除
            );
          }
          // 回退到本地渲染
          return FullScreenView(
            currentGoal: _featureToggles.currentGoalSelectionWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).currentGoal
                    : currentGoal)
                : currentGoal,
            goals: (context.read<GoalBloc>().state is GoalsLoaded
                ? (context.read<GoalBloc>().state as GoalsLoaded).goals
                : goals), // 批次2修复：确保使用最新的BLoC状态数据
            isEditingTitle: _featureToggles.titleEditingWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingTitle
                    : _isEditingTitle)
                : _isEditingTitle,
            titleController: _titleController,
            onTitleEdit: _startTitleEdit,
            onTitleSave: _saveTitleEdit,
            onDescriptionEdit: () {
              context.read<GoalBloc>().add(const StartEditingDescription());
            },
            // 批次2重构：添加描述编辑参数，与标题编辑保持一致
            isEditingDescription: _featureToggles.descriptionEditingWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingDescription
                    : _isEditingDescription)
                : _isEditingDescription,
            descriptionController: _descriptionController,
            onDescriptionSave: () {
              final description = _descriptionController.text;
              context.read<GoalBloc>().add(SaveDescription(description));
            },
            onSaveDescription: _updateGoalDescription, // 保留兼容性
            onImagePick: _pickImage,
            onGoalSelect: (goal) {
              _selectGoal(goal);
            },
            onAddGoal: () => _addNewGoalWrapper(),
            onStatusChange: _handleUpdateGoalStatusSimple,
            onUpdateDate: _updateGoalDate,
            showTime: _featureToggles.timeDisplayWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).showTime
                    : true)
                : _showTime,
            showDescription: _featureToggles.descriptionDisplayWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).showDescription
                    : true)
                : _showDescription,
            showTitle: _featureToggles.titleDisplayWriteThrough
                ? (context.read<GoalBloc>().state is GoalsLoaded
                    ? (context.read<GoalBloc>().state as GoalsLoaded).showTitle
                    : true)
                : _showTitle,
            onToggleTitle: _toggleShowTitle,
            onToggleDeadline: _toggleDeadline,
            onAddSubGoal: () => _addSubGoalFromFullScreen(),
            // 倒计时功能已移除
          );
        },
      );
    }

    // 默认：沿用本地态渲染
    return FullScreenView(
      currentGoal: _featureToggles.currentGoalSelectionWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).currentGoal
              : currentGoal)
          : currentGoal,
      goals: (context.read<GoalBloc>().state is GoalsLoaded
          ? (context.read<GoalBloc>().state as GoalsLoaded).goals
          : goals), // 批次2修复：确保使用最新的BLoC状态数据
      isEditingTitle: _featureToggles.titleEditingWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingTitle
              : _isEditingTitle)
          : _isEditingTitle,
      titleController: _titleController,
      onTitleEdit: _startTitleEdit,
      onTitleSave: _saveTitleEdit,
      onDescriptionEdit: () {
        _startDescriptionEdit();
      },
      // 批次2重构：添加描述编辑参数，与标题编辑保持一致
      isEditingDescription: _featureToggles.descriptionEditingWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingDescription
              : _isEditingDescription)
          : _isEditingDescription,
      descriptionController: _descriptionController,
      onDescriptionSave: () {
        final description = _descriptionController.text;
        context.read<GoalBloc>().add(SaveDescription(description));
      },
      onSaveDescription: _updateGoalDescription, // 保留兼容性
      onImagePick: _pickImage,
      onGoalSelect: (goal) {
        // 批次2：使用统一的目标选择方法
        _selectGoal(goal);
      },
      onAddGoal: () => _addNewGoalWrapper(),
      onStatusChange: _handleUpdateGoalStatusSimple,
      onUpdateDate: _updateGoalDate,
      showTime: _featureToggles.timeDisplayWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).showTime
              : true)
          : _showTime,
      showDescription: _featureToggles.descriptionDisplayWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).showDescription
              : true)
          : _showDescription,
      showTitle: _featureToggles.titleDisplayWriteThrough
          ? (context.read<GoalBloc>().state is GoalsLoaded
              ? (context.read<GoalBloc>().state as GoalsLoaded).showTitle
              : true)
          : _showTitle,
      onToggleTitle: _toggleShowTitle,
      onToggleDeadline: _toggleDeadline,
      onAddSubGoal: () => _addSubGoalFromFullScreen(),
      // 倒计时功能已移除
    );
  }

  // 批次2：统一的目标选择方法（三路径架构）
  void _selectGoal(Goal goal) {
    if (_featureToggles.currentGoalSelectionWriteThrough) {
      // 新路径：编辑会话检查 + Guard保护 + BLoC事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded) {
        // 检查是否有未保存的编辑
        if (currentState.isEditingTitle || currentState.isEditingDescription) {
          // 有编辑会话：显示未保存提示
          _showUnsavedChangesDialog(
            onSave: () => _saveAndSwitchGoal(goal),
            onDiscard: () => _discardAndSwitchGoal(goal),
            onCancel: () => {}, // 取消切换
          );
        } else {
          // 无编辑冲突：直接切换
          context.read<GoalBloc>().add(SelectGoal(goal));
          print('【批次2灰度】目标选择: ${goal.id}');
        }
      } else {
        // Guard保护：非GoalsLoaded状态禁用操作
        print('【批次2灰度】目标选择被禁用：当前状态${currentState.runtimeType}');
      }
    } else {
      // 传统路径：保持不变
      setState(() {
        currentGoal = goal;
      });
      context.read<GoalBloc>().add(SelectGoal(goal));
      print('【传统模式】目标选择: ${goal.id}');
    }
  }

  // 批次2：未保存修改保护对话框
  void _showUnsavedChangesDialog({
    required VoidCallback onSave,
    required VoidCallback onDiscard,
    required VoidCallback onCancel,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('您有未保存的修改，是否要保存？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDiscard();
            },
            child: const Text('丢弃'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSave();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 批次2：保存并切换目标
  void _saveAndSwitchGoal(Goal goal) {
    // 保存当前编辑（简化版本）
    final isEditingTitle = _featureToggles.titleEditingWriteThrough
        ? (context.read<GoalBloc>().state is GoalsLoaded
            ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingTitle
            : _isEditingTitle)
        : _isEditingTitle;

    final isEditingDescription = _featureToggles.descriptionEditingWriteThrough
        ? (context.read<GoalBloc>().state is GoalsLoaded
            ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingDescription
            : _isEditingDescription)
        : _isEditingDescription;

    if (isEditingTitle) {
      _saveTitleEdit();
    }
    if (isEditingDescription) {
      // 描述编辑保存逻辑（暂时简化）
      if (_featureToggles.descriptionEditingWriteThrough) {
        context.read<GoalBloc>().add(const CancelEditing());
      }
    }

    // 切换目标
    context.read<GoalBloc>().add(SelectGoal(goal));
    print('【批次2灰度】保存并切换目标: ${goal.id}');
  }

  // 批次2：丢弃并切换目标
  void _discardAndSwitchGoal(Goal goal) {
    // 取消编辑状态（简化版本）
    final isEditingTitle = _featureToggles.titleEditingWriteThrough
        ? (context.read<GoalBloc>().state is GoalsLoaded
            ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingTitle
            : _isEditingTitle)
        : _isEditingTitle;

    final isEditingDescription = _featureToggles.descriptionEditingWriteThrough
        ? (context.read<GoalBloc>().state is GoalsLoaded
            ? (context.read<GoalBloc>().state as GoalsLoaded).isEditingDescription
            : _isEditingDescription)
        : _isEditingDescription;

    if (isEditingTitle || isEditingDescription) {
      if (_featureToggles.titleEditingWriteThrough || _featureToggles.descriptionEditingWriteThrough) {
        // 新路径：BLoC事件驱动
        context.read<GoalBloc>().add(const CancelEditing());
      } else {
        // 传统路径：setState
        setState(() {
          _isEditingTitle = false;
          _isEditingDescription = false;
        });
        // 恢复原始标题
        if (currentGoal != null) {
          _titleController.text = currentGoal!.title;
        }
      }
    }
    // 描述编辑功能暂时简化处理

    // 切换目标
    context.read<GoalBloc>().add(SelectGoal(goal));
    print('【批次2灰度】丢弃并切换目标: ${goal.id}');
  }

  // 批次2：开始编辑标题（三路径架构）
  void _startTitleEdit() {
    if (_featureToggles.titleEditingWriteThrough) {
      // 新路径：编辑会话检查 + Guard保护 + BLoC事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded &&
          currentState.currentGoal != null &&
          !currentState.isEditingTitle) {  // 确保无其他编辑会话

        // 初始化TextEditingController
        final initialValue = TextEditingValue(
          text: currentState.currentGoal!.title,
          selection: TextSelection.collapsed(offset: currentState.currentGoal!.title.length),
        );
        _titleController.value = initialValue;

        // 启动编辑会话
        context.read<GoalBloc>().add(const StartEditingTitle());

        print('【批次2灰度】开始标题编辑: ${currentState.currentGoal!.id}');
      } else {
        // Guard保护：无有效目标或有其他编辑会话
        print('【批次2灰度】标题编辑被禁用：${_getEditingBlockReason(currentState)}');
      }
    } else {
      // 传统路径：完全保持不变
      if (currentGoal == null) {
        print('【GoalPage】无法编辑标题：没有选中的目标');
        return;
      }

      print('【GoalPage】开始编辑标题，目标ID: ${currentGoal!.id}');

      // 简化逻辑：直接设置编辑状态确保UI响应
      _titleController.text = currentGoal!.title;
      setState(() {
        _isEditingTitle = true;
      });

      // 同时发送BLoC事件用于状态同步
      context.read<GoalBloc>().add(SelectGoal(currentGoal!));
      context.read<GoalBloc>().add(const StartEditingTitle());
    }
  }

  // 批次2：获取编辑阻止原因
  String _getEditingBlockReason(GoalState state) {
    if (state is! GoalsLoaded) {
      return '当前状态${state.runtimeType}';
    }
    if (state.currentGoal == null) {
      return '无有效目标';
    }
    if (state.isEditingTitle) {
      return '标题编辑中';
    }
    if (state.isEditingDescription) {
      return '描述编辑中';
    }
    return '未知原因';
  }

  // 批次2：保存标题（三路径架构）
  void _saveTitleEdit() {
    if (_featureToggles.titleEditingWriteThrough) {
      // 新路径：Guard检查 + BLoC事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded &&
          currentState.currentGoal != null &&
          currentState.isEditingTitle) {

        if (_titleController.text.trim().isNotEmpty) {
          // 保存标题
          context.read<GoalBloc>().add(SaveTitle(_titleController.text.trim()));
          print('【批次2灰度】保存标题编辑: ${_titleController.text.trim()}');
        } else {
          // 取消编辑（空标题）
          context.read<GoalBloc>().add(const CancelEditing());
          print('【批次2灰度】取消标题编辑：空标题');
        }
      } else {
        print('【批次2灰度】保存标题被禁用：${_getEditingBlockReason(currentState)}');
      }
    } else {
      // 传统路径：完全保持不变
      if (_titleController.text.isNotEmpty && currentGoal != null) {
        final updatedGoal = currentGoal!.copyWith(
          title: _titleController.text,
        );

        print('【GoalPage】保存标题编辑，新标题: ${_titleController.text}');

        // 简化逻辑：直接更新目标和状态确保UI响应
        _updateGoal(updatedGoal);
        setState(() {
          _isEditingTitle = false;
        });

        // 同时发送BLoC事件用于状态同步
        context.read<GoalBloc>().add(SaveTitle(_titleController.text));
      } else {
        // 取消编辑
        setState(() {
          _isEditingTitle = false;
        });
        context.read<GoalBloc>().add(const CancelEditing());
      }
    }
  }

  // 显示描述对话框
  void _showDescriptionDialog() {
    TextEditingController descController = TextEditingController(
      text: currentGoal!.description,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '目标描述',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.9),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.black.withValues(alpha: 0.6),
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: descController,
                  autofocus: true,
                  maxLines: null,
                  minLines: 3,
                  cursorColor: Colors.black,
                  cursorWidth: 2.0,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '在这里添加描述',
                    hintStyle: TextStyle(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: () {
                    final updatedGoal = currentGoal!.copyWith(
                      description: descController.text,
                    );
                    _updateGoal(updatedGoal);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 修改删除目标的方法
  Future<void> _deleteCurrentGoal() async {
    final context = this.context;
    if (!mounted) return;

    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '删除',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.9),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.black.withOpacity(0.6),
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // 内容区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        '确定要删除这个目标吗？',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '删除后将无法恢复',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 添加BLoC模式提示（如果启用）
                      if (isBlocModeEnabled) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'BLoC模式已启用，将使用BLoC架构删除目标',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // 按钮区域
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                '取消',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                if (currentGoal != null) {
                                  // 根据BLoC模式状态选择删除方法
                                  if (isBlocModeEnabled) {
                                    _deleteGoalWithBloc(currentGoal!);
                                  } else {
                                    _deleteGoal(currentGoal!);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '删除',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 时间轴视图
  Widget _buildTimelineView() {
    // 添加调试输出
    print(
        'GoalPage._buildTimelineView: parentGoal=${widget.parentGoal?.title}, goalsCount=${goals.length}');

    if (widget.parentGoal != null) {
      print(
          '子目标页面: 父目标ID=${widget.parentGoal!.id}, 父目标标题=${widget.parentGoal!.title}');
    }

    // 直接返回TimelineView组件
    return TimelineView(
      goals: goals,
      isSubgoal: widget.parentGoal != null,
      onGoalSelect: (goal) {
        // 第二阶段迁移完成：使用BLoC事件选择目标
        context.read<GoalBloc>().add(SelectGoal(goal));
        context.read<GoalBloc>().add(ToggleViewMode(0));
      },
      onAddGoal: _showAddGoalDialog,
      onSaveNewGoal: (title, description, imagePath, selectedDate) {
        // 创建新的目标对象
        final newGoal = Goal(
          title: title,
          description: description,
          imagePath: imagePath ?? 'assets/images/default/default.jpg',
          createdTime: DateTime.now(), // 使用当前时间作为创建时间
          targetDate: selectedDate, // 使用选择的日期作为目标日期
          parentId: widget.parentGoal?.id,
        );

        // 保存新目标
        _addNewGoal(newGoal);
      },
      // 添加目标日期更新回调
      onUpdateGoalDate: (goal, newDate) async {
        try {
          // 创建一个更新了日期的新目标对象
          final updatedGoal = goal.copyWith(targetDate: newDate);

          // 更新到数据库并刷新UI
          await _updateGoal(updatedGoal);

          // 返回成功，UI已在_updateGoal中刷新
          return true;
        } catch (e) {
          print('更新目标日期失败: $e');
          return false;
        }
      },
    );
  }

  // 网格视图
  Widget _buildGridView() {
    return GoalGridView(
      goals: goals,
      onGoalSelect: (goal) {
        // 本地立即切回全屏，确保可见交互；同时派发BLoC事件同步
        setState(() {
          currentGoal = goal;
          currentView = 0;
        });
        context.read<GoalBloc>().add(SelectGoal(goal));
        context.read<GoalBloc>().add(ToggleViewMode(0));
      },
      onAddGoal: _showAddGoalDialog,
      onShowOperationMenu: (context, goal) {
        // 只处理删除目标的确认对话框
        _showDeleteGoalDialog(goal);
      },
    );
  }

  // BLoC化的删除目标确认对话框
  void _showDeleteGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialogBloc(
        title: '删除目标',
        message: '您确定要删除这个目标吗？此操作无法撤销。',
        confirmText: '删除',
        cancelText: '取消',
        onConfirm: () {
          // 第二阶段迁移完成：使用BLoC事件删除目标
          if (_featureToggles.writeThroughBloc) {
            context.read<GoalBloc>().add(DeleteGoalWithCleanup(
                  goal,
                  deleteSubGoals: true,
                  updateCurrent: true,
                ));
          } else {
            // 阶段0：避免双写，使用只读方式同步
            context.read<GoalBloc>().add(const LoadGoals());
            context.read<GoalBloc>().add(RefreshGoalTree());
            if (goals.isNotEmpty) {
              context.read<GoalBloc>().add(SelectGoal(goals.first));
            }
          }
        },
      ),
    );
  }

  // BLoC化的添加目标对话框方法
  void _showAddGoalDialog() {
    print('添加新目标，当前会员状态: $_membershipStatus');

    // 如果是顶级目标，需要检查权限和数量限制
    if (widget.parentGoal == null) {
      // 重新获取AuthService确认登录状态
      final authService = Provider.of<AuthService>(context, listen: false);
      print('AuthService登录状态: ${authService.isLoggedIn}');

      // 未登录用户需要先登录
      if (!authService.isLoggedIn) {
        print('用户未登录，跳转登录页面');
        _navigateToLogin(context);
        return;
      }

      // 获取会员级别
      final memberLevel = _membershipStatus > 0 ? _membershipStatus : 1;

      // 普通用户（会员级别为1）检查项目数量限制
      if (memberLevel == 1) {
        // 获取顶级目标的数量
        final rootGoalsCount =
            goals.where((goal) => goal.parentId == null).length;
        print('普通用户，当前顶级目标数量: $rootGoalsCount');

        // 普通用户最多3个项目，也就是达到3个后才限制
        if (rootGoalsCount >= 3) {
          print('达到普通用户项目上限，显示会员提示');
          _showMembershipLimitPrompt();
          return;
        }
      }
      // 会员用户 (会员级别 >= 2) 不做数量限制
      print('用户会员状态: $memberLevel，允许创建新项目');
    }

    // 第二阶段迁移完成：使用BLoC化的对话框组件
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddGoalDialogBloc(
        parentGoal: widget.parentGoal,
        membershipStatus: _membershipStatus,
      ),
    );
  }

  // 显示会员数量限制提示
  void _showMembershipLimitPrompt() {
    MembershipPromptDialog.showLimitPrompt(context);
  }

  // 添加自定义日期选择对话框方法
  Future<DateTime?> _showCustomDatePicker(
    BuildContext context,
    DateTime initialDate,
    String title,
  ) async {
    DateTime tempSelectedDate = initialDate;

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 日期选择器部分 - 简洁版本，无标题
                  Container(
                    height: 400,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Theme(
                      data: ThemeData.light().copyWith(
                        primaryColor: Colors.black,
                        colorScheme: ColorScheme.light(
                          primary: Colors.black,
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: tempSelectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        onDateChanged: (DateTime date) {
                          setState(() {
                            tempSelectedDate = date;
                          });
                        },
                      ),
                    ),
                  ),

                  // 底部按钮 - 仅保留取消和确定
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                          ),
                          child:
                              const Text('取消', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, tempSelectedDate),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                                const Color(0xFF000000)),
                            foregroundColor:
                                MaterialStateProperty.all<Color>(Colors.white),
                            padding:
                                MaterialStateProperty.all<EdgeInsetsGeometry>(
                                    const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 10)),
                            shape: MaterialStateProperty.all<
                                RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            elevation: MaterialStateProperty.all<double>(0),
                          ),
                          child:
                              const Text('确定', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 中文格式化日期显示
  String _formatDateChinese(DateTime date) {
    // 只显示年份
    if (date.month == 1 && date.day == 1) {
      return '${date.year}年';
    }
    // 显示年月
    else if (date.day == 1) {
      return '${date.year}年${date.month}月';
    }
    // 显示完整日期
    else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }

  // 添加设置页面的导航方法
  Future<void> _navigateToSettings(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    if (result == true) {
      await _checkLoginStatus();
    }
  }

  // 导航到登录页面
  Future<void> _navigateToLogin(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('需要登录'),
        content: const Text('请先登录账号后再创建新项目'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
            child: const Text('暂不登录'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('去登录'),
          ),
        ],
      ),
    );

    if (result == true) {
      final loginResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );

      if (loginResult == true) {
        // 登录成功，立即更新登录状态
        print('用户登录成功，立即更新会员状态');
        await _checkLoginStatus();
        print('登录后会员状态更新为: $_membershipStatus');

        // 强制刷新UI
        setState(() {});
      }
    }
  }

  // 添加更改状态的对话框方法
  void _showStatusDialog(Goal goal) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '更改状态',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.9),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.black.withOpacity(0.6),
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // 状态选项列表
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    _buildStatusOption(
                      icon: Icons.pending_outlined,
                      label: '进行中',
                      isSelected: goal.status == GoalStatus.pending,
                      onTap: () {
                        // 第二阶段迁移完成：使用BLoC事件更新目标状态
                        final updatedGoal =
                            goal.copyWith(status: GoalStatus.pending);
                        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
                        Navigator.pop(context);
                      },
                      isPending: true,
                    ),
                    _buildStatusOption(
                      icon: Icons.check_circle_outline,
                      label: '已完成',
                      isSelected: goal.status == GoalStatus.completed,
                      onTap: () {
                        // 第二阶段迁移完成：使用BLoC事件更新目标状态
                        final updatedGoal =
                            goal.copyWith(status: GoalStatus.completed);
                        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
                        Navigator.pop(context);
                      },
                      isPending: false,
                    ),
                    _buildStatusOption(
                      icon: Icons.cancel_outlined,
                      label: '已放弃',
                      isSelected: goal.status == GoalStatus.abandoned,
                      onTap: () {
                        // 第二阶段迁移完成：使用BLoC事件更新目标状态
                        final updatedGoal =
                            goal.copyWith(status: GoalStatus.abandoned);
                        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
                        Navigator.pop(context);
                      },
                      isPending: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isPending,
  }) {
    Color getColor() {
      if (isSelected) {
        return Colors.black;
      }
      return isPending
          ? Colors.black.withOpacity(0.8)
          : Colors.black.withOpacity(0.4);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: getColor(),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: getColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: Colors.black,
              ),
          ],
        ),
      ),
    );
  }

  // 倒计时功能已移除，等架构稳定后重新实现

  // 显示分享对话框
  void _showShareDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ShareDialog(
          title: goal.title,
          backgroundImagePath: goal.imagePath,
        );
      },
    );
  }

  /// 处理登出
  Future<void> _handleLogout() async {
    // 显示确认对话框
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87, // 设置文字颜色为黑色
              ),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.black, // 按钮背景色
                foregroundColor: Colors.white, // 文字颜色为白色
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      await _checkLoginStatus();
    }
  }

  /// 构建侧边栏
  Widget _buildDrawer() {
    final authService = Provider.of<AuthService>(context);

    // 调试输出当前目标树结构
    print(
        '构建抽屉时的目标树结构：${allGoals.map((g) => '${g.id}:${g.title} (子项:${g.subGoals.length})').join(', ')}');

    // 如果allGoals为空，尝试刷新目标树
    if (allGoals.isEmpty) {
      print('警告：树视图数据为空，尝试刷新');
      // 使用Future.microtask确保在当前帧构建完成后执行刷新操作
      Future.microtask(() async {
        await _refreshGoalTree();
      });
    }

    // 已移除：开发者选项相关代码

    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: GoalTreeViewBloc(
                  goals: allGoals,
                  membershipStatus: _membershipStatus,
                  isLoggedIn: authService.isLoggedIn,
                  userAvatar: authService.avatarUrl,
                  userNickname: authService.userName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleShowTime() {
    // 批次1灰度实施：showTime写路径BLoC化
    if (_featureToggles.timeDisplayWriteThrough) {
      // 新路径：Guard检查 + BLoC状态取值 + 事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded) {
        // 性能监控开始
        UIStatePerformanceMonitor.startMeasure('time_toggle');
        UIStatePerformanceMonitor.recordEvent('time_toggle');

        // 从BLoC状态取反，确保一致性
        context.read<GoalBloc>().add(ToggleTimeDisplay(!currentState.showTime));

        print('【批次1灰度】showTime切换: ${!currentState.showTime}');
      } else {
        // Guard保护：非GoalsLoaded状态禁用操作
        UIStatePerformanceMonitor.recordError('time_toggle');
        print('【批次1灰度】showTime切换被禁用：当前状态${currentState.runtimeType}');
      }
    } else {
      // 传统路径：完全保持不变
      setState(() {
        _showTime = !_showTime;
      });
      context.read<GoalBloc>().add(ToggleTimeDisplay(_showTime));
      print('【传统模式】showTime切换: $_showTime');
    }
  }

  void _toggleShowDescription() {
    // 批次1灰度实施：showDescription写路径BLoC化
    if (_featureToggles.descriptionDisplayWriteThrough) {
      // 新路径：Guard检查 + BLoC状态取值 + 事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded) {
        // 性能监控开始
        UIStatePerformanceMonitor.startMeasure('description_toggle');
        UIStatePerformanceMonitor.recordEvent('description_toggle');

        // 从BLoC状态取反，确保一致性
        context.read<GoalBloc>().add(ToggleDescriptionDisplay(!currentState.showDescription));

        print('【批次1灰度】showDescription切换: ${!currentState.showDescription}');
      } else {
        // Guard保护：非GoalsLoaded状态禁用操作
        UIStatePerformanceMonitor.recordError('description_toggle');
        print('【批次1灰度】showDescription切换被禁用：当前状态${currentState.runtimeType}');
      }
    } else {
      // 传统路径：完全保持不变
      setState(() {
        _showDescription = !_showDescription;
      });
      context.read<GoalBloc>().add(ToggleDescriptionDisplay(_showDescription));
      print('【传统模式】showDescription切换: $_showDescription');
    }
  }

  void _toggleShowTitle() {
    // 批次1灰度实施：showTitle写路径BLoC化
    if (_featureToggles.titleDisplayWriteThrough) {
      // 新路径：Guard检查 + BLoC状态取值 + 事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded) {
        // 性能监控开始
        UIStatePerformanceMonitor.startMeasure('title_toggle');
        UIStatePerformanceMonitor.recordEvent('title_toggle');

        // 从BLoC状态取反，确保一致性
        context.read<GoalBloc>().add(ToggleTitleDisplay(!currentState.showTitle));

        print('【批次1灰度】showTitle切换: ${!currentState.showTitle}');
      } else {
        // Guard保护：非GoalsLoaded状态禁用操作
        UIStatePerformanceMonitor.recordError('title_toggle');
        print('【批次1灰度】showTitle切换被禁用：当前状态${currentState.runtimeType}');
      }
    } else {
      // 传统路径：完全保持不变
      setState(() {
        _showTitle = !_showTitle;
      });
      context.read<GoalBloc>().add(ToggleTitleDisplay(_showTitle));
      print('【传统模式】showTitle切换: $_showTitle');
    }
  }

  // 为新建目标显示图片选择器
  Future<void> _showImagePickerForNewGoal(
      Function(String, {bool isVideo}) onImageSelected) async {
    if (!mounted) return;

    // 使用新的图片选择器组件
    await ImagePickerDialog.show(
      context: context,
      membershipStatus: _membershipStatus,
      onImageSelected: onImageSelected,
      onMembershipPrompt: () {
        // 显示会员提示
        MembershipPromptDialog.showImagePrompt(context);
      },
    );
  }

  // 也需要更新现有目标的图片选择器功能
  Future<void> _showImagePicker() async {
    if (!mounted) return;

    // 使用新的图片选择器组件
    await ImagePickerDialog.show(
      context: context,
      membershipStatus: _membershipStatus,
      onImageSelected: (path, {isVideo = false}) async {
        if (currentGoal == null) return;

        if (isVideo) {
          // 更新当前目标为视频
          print('选择了视频文件: $path');

          // 验证视频文件是否存在
          final videoFile = File(path);
          if (!videoFile.existsSync()) {
            print('错误: 视频文件不存在: $path');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('视频文件不存在或无法访问')),
            );
            return;
          }

          // 检查文件大小和可访问性
          try {
            final fileSize = videoFile.lengthSync();
            print('视频文件存在，大小: $fileSize 字节');
            if (fileSize <= 0) {
              print('错误: 视频文件大小为0: $path');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('视频文件大小为0，无法使用')),
              );
              return;
            }

            // 尝试读取文件的前几个字节，确认可访问性
            final bytes = videoFile.openRead(0, 1024).first;
            await bytes;
          } catch (e) {
            print('错误: 视频文件无法读取: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('视频文件无法读取: $e')),
            );
            return;
          }

          final updatedGoal = currentGoal!.copyWith(
            imagePath: 'assets/images/default/default.jpg', // 使用默认图片路径
            videoPath: path, // 保存视频路径到videoPath
            hasVideo: true, // 标记为视频
            videoMuted: false, // 默认不静音
          );

          print(
              '更新目标为视频: id=${updatedGoal.id}, videoPath=${updatedGoal.videoPath}, hasVideo=${updatedGoal.hasVideo}');
          await _updateGoal(updatedGoal);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已设置视频背景')),
          );
        } else {
          // 更新当前目标的图片
          print('选择了图片文件: $path');
          final updatedGoal = currentGoal!.copyWith(
            imagePath: path,
            videoPath: null, // 清除视频路径
            hasVideo: false, // 标记为非视频
          );

          print(
              '更新目标为图片: id=${updatedGoal.id}, imagePath=${updatedGoal.imagePath}, hasVideo=${updatedGoal.hasVideo}');
          await _updateGoal(updatedGoal);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已更新图片')),
          );
        }

        // 刷新视图
        setState(() {});
      },
      onMembershipPrompt: () {
        // 显示会员提示
        MembershipPromptDialog.showImagePrompt(context);
      },
    );
  }

  /// 处理云同步点击
  void _handleSyncTap() async {
    switch (_membershipStatus) {
      case 0: // 未登录
        await _navigateToLogin(context);
        break;
      case 1: // 已登录未购买会员
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MembershipPage()),
        );
        if (result == true) {
          // 购买会员成功，更新会员状态
          await _checkLoginStatus();
        }
        break;
      case 2: // 已是会员
        _syncData();
        break;
    }
  }

  /// 执行数据同步
  Future<void> _syncData() async {
    try {
      // 显示同步进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在同步数据...'),
              ],
            ),
          );
        },
      );

      // TODO: 实现实际的云同步逻辑
      // 1. 上传本地数据到云端
      // 2. 获取云端数据
      // 3. 合并数据
      await Future.delayed(const Duration(seconds: 2)); // 模拟同步过程

      // 关闭进度对话框
      if (!mounted) return;
      Navigator.pop(context);

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据同步成功')),
      );
    } catch (e) {
      // 关闭进度对话框
      if (!mounted) return;
      Navigator.pop(context);

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败: $e')),
      );
    }
  }

  // 显示探索页面
  void _navigateToExplore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('意识探索'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
          body: ExploreView(
            onSelectCard: (Goal card) {
              // 处理探索卡片选择
              Navigator.pop(context);
              setState(() {
                currentView = 0; // 切换到全屏视图
                currentGoal = card;
              });
            },
          ),
        ),
      ),
    );
  }

  // 添加截止日期切换功能
  Future<void> _toggleDeadline(Goal goal) async {
    try {
      if (goal.targetDate != null) {
        // 有截止日期，则清除
        print('【GoalPage】删除截止日期，目标ID: ${goal.id}');
        final updatedGoal = goal.copyWith(targetDate: null);

        // 检查BLoC适配器执行模式状态
        final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

        if (isBlocModeEnabled) {
          // 使用BLoC更新
          context.read<GoalBloc>().add(UpdateGoal(updatedGoal));

          // 立即更新本地状态
          setState(() {
            if (currentGoal?.id == goal.id) {
              currentGoal = updatedGoal;
            }

            // 同时更新goals列表中的对应项
            final index = goals.indexWhere((g) => g.id == goal.id);
            if (index != -1) {
              goals[index] = updatedGoal;
            }
          });
        } else {
          // 使用传统方式更新
          await _updateGoal(updatedGoal);
        }
      } else {
        // 无截止日期，则设置
        print('【GoalPage】设置截止日期，目标ID: ${goal.id}');

        // 使用日期选择器让用户选择日期
        final now = DateTime.now();
        final selectedDate = await _showCustomDatePicker(
          context,
          now.add(const Duration(days: 30)),
          '选择截止日期',
        );

        // 如果用户选择了日期
        if (selectedDate != null) {
          final updatedGoal = goal.copyWith(targetDate: selectedDate);

          // 第二阶段迁移完成：统一使用BLoC更新
          context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
        }
      }
    } catch (e) {
      print('【GoalPage】切换截止日期失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置截止日期失败: $e')),
      );
    }
  }

  // 批次2：更新目标描述（三路径架构）
  void _updateGoalDescription(Goal goal, String newDescription) {
    if (_featureToggles.descriptionEditingWriteThrough) {
      // 新路径：Guard检查 + BLoC事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded &&
          currentState.currentGoal != null &&
          currentState.currentGoal!.id == goal.id) {

        if (newDescription.trim().isNotEmpty || goal.description.isNotEmpty) {
          // 保存描述（允许空描述）
          context.read<GoalBloc>().add(SaveDescription(newDescription.trim()));
          print('【批次2灰度】保存描述编辑: ${newDescription.trim()}');

          // 强制UI同步：等待BLoC状态更新后手动触发同步
          Future.delayed(const Duration(milliseconds: 100), () {
            final updatedState = context.read<GoalBloc>().state;
            if (updatedState is GoalsLoaded) {
              print('【批次2修复】强制触发UI同步');
              syncStateFromBloc(updatedState);

              // 额外修复：强制刷新当前页面以确保FullScreenView更新
              if (mounted) {
                setState(() {
                  // 触发页面重建
                });
                print('【批次2修复】强制刷新页面UI');
              }
            }
          });
        } else {
          // 取消编辑（无变化）
          context.read<GoalBloc>().add(const CancelEditing());
          print('【批次2灰度】取消描述编辑：无变化');
        }
      } else {
        print('【批次2灰度】保存描述被禁用：${_getEditingBlockReason(currentState)}');
      }
    } else {
      // 传统路径：完全保持不变
      final updatedGoal = goal.copyWith(
        description: newDescription,
      );

      // 检查BLoC适配器执行模式状态和描述编辑功能开关
      final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
      final bool isDescriptionEditingEnabled = _featureToggles.descriptionEditing;

      print(
          '【GoalPage】更新目标描述，BLoC模式: ${isBlocModeEnabled && isDescriptionEditingEnabled}');

      // 根据BLoC模式状态选择更新方法
      if (isBlocModeEnabled && isDescriptionEditingEnabled) {
        // 使用UpdateGoal事件代替SaveDescription事件，确保传递完整的目标信息
        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
      } else {
        _updateGoal(updatedGoal);
      }
    }
  }

  // 批次2重构：开始编辑描述，与标题编辑保持完全一致的架构
  void _startDescriptionEdit() {
    if (_featureToggles.descriptionEditingWriteThrough) {
      // 新路径：编辑会话检查 + Guard保护 + BLoC事件驱动
      final currentState = context.read<GoalBloc>().state;
      if (currentState is GoalsLoaded &&
          currentState.currentGoal != null &&
          !currentState.isEditingTitle &&
          !currentState.isEditingDescription) {  // 确保无其他编辑会话

        // 初始化TextEditingController（与标题编辑保持一致）
        final initialValue = TextEditingValue(
          text: currentState.currentGoal!.description,
          selection: TextSelection.collapsed(offset: currentState.currentGoal!.description.length),
        );
        _descriptionController.value = initialValue;

        // 启动编辑会话
        context.read<GoalBloc>().add(const StartEditingDescription());

        print('【批次2灰度】开始描述编辑: ${currentState.currentGoal!.id}');
      } else {
        // Guard保护：无有效目标或有其他编辑会话
        print('【批次2灰度】描述编辑被禁用：${_getEditingBlockReason(currentState)}');
      }
    } else {
      // 传统路径：与标题编辑保持一致的处理
      if (currentGoal == null) {
        print('【GoalPage】无法编辑描述：没有选中的目标');
        return;
      }

      print('【GoalPage】开始编辑描述，目标ID: ${currentGoal!.id}');

      // 简化逻辑：直接设置编辑状态确保UI响应
      _descriptionController.text = currentGoal!.description;
      setState(() {
        _isEditingDescription = true;
      });

      // 同时发送BLoC事件用于状态同步
      context.read<GoalBloc>().add(SelectGoal(currentGoal!));
      context.read<GoalBloc>().add(const StartEditingDescription());
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    // 根据BLoC模式状态选择方法
    if (isBlocModeEnabled) {
      await _pickImageWithBloc();
    } else {
      await _showImagePicker();
    }
  }

  // 简化的状态更新处理方法
  Future<void> _handleUpdateGoalStatusSimple(Goal goal, bool showDialog) async {
    if (showDialog) {
      _showStatusDialog(goal);
    } else {
      // 轮换状态: 待完成 -> 已完成 -> 已放弃 -> 待完成
      GoalStatus newStatus;
      switch (goal.status) {
        case GoalStatus.pending:
          newStatus = GoalStatus.completed;
          break;
        case GoalStatus.completed:
          newStatus = GoalStatus.abandoned;
          break;
        case GoalStatus.abandoned:
          newStatus = GoalStatus.pending;
          break;
      }

      final updatedGoal = goal.copyWith(status: newStatus);

      print('【GoalPage】更新目标状态，目标ID: ${goal.id}, 新状态: $newStatus');

      // 第二阶段迁移完成：统一使用BLoC更新
      context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
    }
  }

  // 更新目标日期
  Future<bool> _updateGoalDate(Goal goal, DateTime? newDate) async {
    try {
      final updatedGoal = goal.copyWith(targetDate: newDate);

      print(
          '【GoalPage】更新目标日期，目标ID: ${goal.id}, 新日期: ${newDate?.toString() ?? "无"}');

      // 第二阶段迁移完成：统一使用BLoC更新
      context.read<GoalBloc>().add(UpdateGoal(updatedGoal));

      return true;
    } catch (e) {
      print('更新日期失败: $e');
      return false;
    }
  }

  // 从全屏视图添加子目标
  void _addSubGoalFromFullScreen() async {
    if (currentGoal == null) return;

    // 导航到新的子目标页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalPage(
          parentGoal: currentGoal,
          onGoalTreeChanged: () {
            // 子目标变化时刷新父页面
            _refreshGoalTree();
          },
        ),
      ),
    );

    // 返回后刷新目标树
    await _refreshGoalTree();
  }

  // 倒计时功能已移除，等架构稳定后重新实现

  // 倒计时功能已移除，等架构稳定后重新实现

  // 辅助方法，用于解决类型不匹配问题
  void _addNewGoalWrapper() {
    _showAddGoalDialog();
  }

  /// 记录和分析BLoC操作结果
  ///
  /// 此方法用于在开发阶段记录和分析BLoC操作与直接数据库操作的差异
  /// 当我们确认BLoC架构稳定后，可以移除此方法
  void _logBlocOperationResult({
    required String operation,
    required bool success,
    String? message,
    dynamic data,
  }) {
    // 记录操作结果
    print('【BLoC分析】操作: $operation, 结果: ${success ? '成功' : '失败'}');

    if (message != null) {
      print('【BLoC分析】消息: $message');
    }

    if (data != null) {
      print('【BLoC分析】数据: $data');
    }

    // 在开发阶段，可以在这里添加更多的分析逻辑
    // 例如，比较BLoC操作和直接数据库操作的结果
    // 或者记录操作耗时等性能指标
  }

  /// 使用BLoC直接添加新目标
  ///
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  /// 作为渐进式重构的第一步，我们先实现这个方法，然后逐步替换其他方法
  Future<void> _addNewGoalWithBloc(Goal goal) async {
    try {
      // 根据页面类型设置正确的父目标ID
      if (widget.isSubGoalView &&
          currentGoal != null &&
          currentGoal!.parentId != null) {
        // 如果是子目标视图，使用当前目标的父目标ID（创建同级子目标）
        goal.parentId = currentGoal!.parentId;
        print(
            '【GoalPage】BLoC模式在子目标视图创建同级子目标: 父ID=${goal.parentId}, 标题=${goal.title}');
      } else {
        // 否则使用当前页面的父目标ID（创建子目标）
        goal.parentId = widget.parentGoal?.id;
        print('【GoalPage】BLoC模式创建子目标: 父ID=${goal.parentId}, 标题=${goal.title}');
      }

      // 显示加载指示器
      setState(() {
        _isLoading = true;
      });

      // 使用BLoC添加目标
      final completer = Completer<Goal>();

      // 使用BLoC适配器添加目标
      _blocAdapter?.addGoal(
        goal: goal,
        onSuccess: (blocGoal) {
          print(
              '【GoalPage】BLoC模式子目标添加成功 - 目标ID: ${blocGoal.id}, 父ID: ${blocGoal.parentId}');
          completer.complete(blocGoal);
        },
        onError: (error) {
          print('【GoalPage】BLoC模式子目标添加失败: $error');
          completer.completeError(error);
        },
      );

      // 等待操作完成
      final addedGoal = await completer.future;

      // 更新UI
      setState(() {
        goals.insert(0, addedGoal); // 插入到列表开头
        currentGoal = addedGoal; // 选中新创建的目标
        _isLoading = false;
      });

      // 重要：刷新目标树，确保子目标显示在树中
      await _refreshGoalTreeWithBloc();

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        print('【GoalPage】通知父页面刷新目标树');
        widget.onGoalTreeChanged!();
      }

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('子目标添加成功 (使用BLoC)')),
      );
    } catch (e) {
      // 隐藏加载指示器
      setState(() {
        _isLoading = false;
      });

      print('【GoalPage】BLoC模式添加子目标失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加子目标失败: $e')),
      );
    }
  }

  /// 使用BLoC直接删除目标
  ///
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  Future<void> _deleteGoalWithBloc(Goal goal) async {
    try {
      print('【GoalPage】BLoC模式删除目标: ID=${goal.id}, 标题=${goal.title}');

      // 显示加载指示器
      setState(() {
        _isLoading = true;
      });

      // 使用BLoC删除目标
      final completer = Completer<void>();

      // 使用BLoC适配器删除目标
      _blocAdapter?.deleteGoal(
        goalId: goal.id!,
        onSuccess: () {
          print('【GoalPage】BLoC模式删除目标成功 - 目标ID: ${goal.id}');
          completer.complete();
        },
        onError: (error) {
          print('【GoalPage】BLoC模式删除目标失败: $error');
          completer.completeError(error);
        },
      );

      // 等待操作完成
      await completer.future;

      // 更新UI
      setState(() {
        goals.remove(goal);
        if (currentGoal?.id == goal.id) {
          currentGoal = goals.isNotEmpty ? goals[0] : null;
        }
        _isLoading = false;
      });

      // 重要：刷新目标树，确保目标树更新
      await _refreshGoalTreeWithBloc();

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        print('【GoalPage】通知父页面刷新目标树');
        widget.onGoalTreeChanged!();
      }

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目标删除成功 (使用BLoC)')),
      );
    } catch (e) {
      // 隐藏加载指示器
      setState(() {
        _isLoading = false;
      });

      print('【GoalPage】BLoC模式删除目标失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除目标失败: $e')),
      );
    }
  }

  /// 使用BLoC直接更新目标
  ///
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  Future<void> _updateGoalWithBloc(Goal goal) async {
    try {
      print('【GoalPage】BLoC模式更新目标: ID=${goal.id}, 标题=${goal.title}');

      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);

      // 发送更新事件
      goalBloc.add(UpdateGoal(goal));

      // 更新当前目标
      setState(() {
        final index = goals.indexWhere((g) => g.id == goal.id);
        if (index != -1) {
          goals[index] = goal;
          currentGoal = goal;
        }
      });

      // 如果是子目标或更新会影响目标树，刷新目标树
      if (goal.parentId != null || goal.subGoals.isNotEmpty) {
        print('【GoalPage】目标有父子关系，刷新目标树');
        await _refreshGoalTreeWithBloc();

        // 如果是子目标,通知父页面刷新
        if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
          print('【GoalPage】通知父页面刷新目标树');
          widget.onGoalTreeChanged!();
        }
      }
    } catch (e) {
      print('【GoalPage】BLoC模式更新目标失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新目标失败: $e')),
      );
    }
  }

  // 倒计时功能已移除，等架构稳定后重新实现

  /// 使用BLoC直接刷新目标树
  ///
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  Future<void> _refreshGoalTreeWithBloc() async {
    print('【GoalPage】开始使用BLoC方式刷新目标树');

    try {
      setState(() {
        _isLoading = true;
      });

      // 创建一个Completer，用于异步等待BLoC操作完成
      final completer = Completer<void>();

      // 添加一次性监听器，等待状态更新
      late StreamSubscription<GoalState> subscription;
      subscription = context.read<GoalBloc>().stream.listen((state) {
        if (state is GoalsLoaded) {
          print('【GoalPage】BLoC刷新目标树成功，获取 ${state.allGoals.length} 个目标');

          // 更新本地状态
          if (mounted && !completer.isCompleted) {
            setState(() {
              allGoals = state.allGoals;

              // 更新goals列表
              if (widget.parentGoal == null) {
                // 根页面goals为顶级目标
                goals = allGoals;
              } else {
                // 查找当前父目标的子目标
                final parentGoal = allGoals.firstWhere(
                  (g) => g.id == widget.parentGoal!.id,
                  orElse: () => widget.parentGoal!,
                );
                goals = parentGoal.subGoals;
              }

              if (goals.isNotEmpty && currentGoal == null) {
                currentGoal = goals[0];
              }

              _isLoading = false;
            });

            // 完成异步操作
            completer.complete();
            subscription.cancel();
          }
        } else if (state is GoalError) {
          print('【GoalPage】BLoC刷新目标树失败: ${state.message}');

          if (mounted && !completer.isCompleted) {
            setState(() {
              _error = '刷新目标树失败: ${state.message}';
              _isLoading = false;
            });

            // 完成异步操作
            completer.complete();
            subscription.cancel();
          }
        }
      });

      // 触发BLoC事件
      context.read<GoalBloc>().add(const RefreshGoalTree());

      // 添加超时处理
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          print('【GoalPage】BLoC刷新目标树超时');
          subscription.cancel();

          if (mounted) {
            setState(() {
              _error = '刷新目标树超时';
              _isLoading = false;
            });
          }

          completer.complete();
        }
      });

      // 等待操作完成
      await completer.future;

      // 通知父组件目标树已更改
      widget.onGoalTreeChanged?.call();
    } catch (e) {
      print('【GoalPage】BLoC刷新目标树出错: $e');

      if (mounted) {
        setState(() {
          _error = '刷新目标树出错: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 使用BLoC选择并更新图片/视频背景
  ///
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  Future<void> _pickImageWithBloc() async {
    if (!mounted || currentGoal == null) return;

    await ImagePickerDialog.show(
      context: context,
      membershipStatus: _membershipStatus,
      onImageSelected: (path, {isVideo = false}) async {
        try {
          // 显示加载指示器
          setState(() {
            _isLoading = true;
          });

          // 创建更新后的目标
          Goal updatedGoal;
          if (isVideo) {
            // 验证视频文件
            final videoFile = File(path);
            if (!videoFile.existsSync()) {
              throw Exception('视频文件不存在或无法访问');
            }

            // 检查文件大小和可访问性
            try {
              final fileSize = videoFile.lengthSync();
              print('视频文件存在，大小: $fileSize 字节');
              if (fileSize <= 0) {
                throw Exception('视频文件大小为0，无法使用');
              }

              // 尝试读取文件的前几个字节，确认可访问性
              final bytes = videoFile.openRead(0, 1024).first;
              await bytes;
            } catch (e) {
              throw Exception('视频文件无法读取: $e');
            }

            updatedGoal = currentGoal!.copyWith(
              imagePath: 'assets/images/default/default.jpg', // 使用默认图片路径
              videoPath: path, // 保存视频路径到videoPath
              hasVideo: true, // 标记为视频
              videoMuted: false, // 默认不静音
            );
          } else {
            updatedGoal = currentGoal!.copyWith(
              imagePath: path,
              videoPath: null, // 清除视频路径
              hasVideo: false, // 标记为非视频
            );
          }

          print(
              '【GoalPage】更新目标背景，BLoC模式: true, 目标ID: ${currentGoal!.id}, 是视频: $isVideo, 路径: $path');

          // 直接使用BLoC事件更新目标
          context.read<GoalBloc>().add(UpdateGoal(updatedGoal));

          // 立即更新本地状态，避免UI闪烁
          setState(() {
            currentGoal = updatedGoal;
            _isLoading = false;
          });

          // 显示成功消息
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVideo ? '视频背景设置成功' : '图片背景更新成功')),
          );
        } catch (e) {
          // 隐藏加载指示器
          setState(() {
            _isLoading = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新背景失败: $e')),
          );
        }
      },
      onMembershipPrompt: () {
        // 显示会员提示
        MembershipPromptDialog.showImagePrompt(context);
      },
    );
  }

  // 已移除：搜索功能相关方法

  // 已移除：BLoC搜索功能相关方法

  // 加载特定目标
  Future<void> _loadSpecificGoal(int goalId) async {
    print('【GoalPage】加载特定目标: $goalId');

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 检查BLoC适配器执行模式状态
      final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

      // 根据BLoC模式状态选择方法
      if (isBlocModeEnabled) {
        // 使用BLoC加载特定目标
        print('【GoalPage】通过BLoC加载特定目标: $goalId');

        // 创建一个Completer，用于异步等待BLoC操作完成
        final completer = Completer<void>();

        // 添加一次性监听器，等待状态更新
        late StreamSubscription<GoalState> subscription;
        subscription = context.read<GoalBloc>().stream.listen((state) {
          print('【GoalPage】收到BLoC状态更新: ${state.runtimeType}');

          if (state is GoalsLoaded && state.currentGoal != null) {
            print(
                '【GoalPage】BLoC加载特定目标成功: ID=${state.currentGoal!.id}, 标题=${state.currentGoal!.title}');

            // 验证加载的是否是请求的目标
            if (state.currentGoal!.id != goalId) {
              print(
                  '【GoalPage】警告：加载的目标ID(${state.currentGoal!.id})与请求的ID($goalId)不匹配');
            }

            if (mounted && !completer.isCompleted) {
              setState(() {
                currentGoal = state.currentGoal;
                goals = state.goals;
                allGoals = state.allGoals;
                currentView = 0; // 切换到全屏视图
                _isLoading = false;
              });

              // 完成异步操作
              completer.complete();
              subscription.cancel();
            }
          } else if (state is GoalError) {
            print('【GoalPage】BLoC加载特定目标失败: ${state.message}');

            if (mounted && !completer.isCompleted) {
              setState(() {
                _error = state.message;
                _isLoading = false;
              });

              // 完成异步操作
              completer.complete();
              subscription.cancel();
            }
          }
        });

        // 触发BLoC事件
        print('【GoalPage】发送LoadSpecificGoal事件，goalId: $goalId');
        context.read<GoalBloc>().add(LoadSpecificGoal(goalId));

        // 添加超时处理
        Future.delayed(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            print('【GoalPage】BLoC加载特定目标超时');
            subscription.cancel();

            if (mounted) {
              setState(() {
                _error = '加载特定目标超时';
                _isLoading = false;
              });
            }

            completer.complete();
          }
        });

        // 等待操作完成
        print('【GoalPage】等待BLoC操作完成');
        await completer.future;
        print('【GoalPage】BLoC操作已完成');
      } else {
        // 批次3阶段3：数据加载统一通过BLoC
        if (_featureToggles.dataLoadingViaBloc) {
          // 新路径：通过BLoC事件加载特定目标
          print('【GoalPage】使用BLoC方式加载特定目标: $goalId');
          final completer = Completer<void>();

          // 监听BLoC状态变化
          late final StreamSubscription<GoalState> subscription;
          subscription = context.read<GoalBloc>().stream.listen((state) {
            if (state is GoalsLoaded && state.currentGoal?.id == goalId) {
              print('【GoalPage】BLoC方式加载特定目标成功: ID=${state.currentGoal!.id}, 标题=${state.currentGoal!.title}');
              completer.complete();
              subscription.cancel();
            } else if (state is GoalError) {
              print('【GoalPage】BLoC方式加载特定目标失败: ${state.message}');
              completer.completeError(state.message);
              subscription.cancel();
            }
          });

          // 发送加载特定目标事件
          context.read<GoalBloc>().add(LoadSpecificGoal(goalId));

          // 等待结果
          await completer.future;
        } else {
          // 传统路径：直接从数据库加载
          print('【GoalPage】通过传统方式加载特定目标: $goalId');
          final goal = await _dbHelper.getGoal(goalId);
          if (goal != null) {
            print('【GoalPage】传统方式加载特定目标成功: ID=${goal.id}, 标题=${goal.title}');

            // 加载同级目标（如果是子目标，加载其兄弟节点）
            List<Goal> siblingGoals;
            if (goal.parentId != null) {
              siblingGoals = await _dbHelper.getGoals(parentId: goal.parentId);
              print('【GoalPage】加载同级目标: ${siblingGoals.length}个');
            } else {
              siblingGoals = await _dbHelper.getGoals(parentId: null);
              print('【GoalPage】加载根目标: ${siblingGoals.length}个');
            }
          }
        }

        // 第二阶段迁移完成：统一使用BLoC事件加载特定目标
        if (!_featureToggles.dataLoadingViaBloc) {
          context.read<GoalBloc>().add(LoadSpecificGoal(goalId));
        }

        // 使用BLoC适配器加载特定目标（影子模式）
        _blocAdapter?.loadSpecificGoal(
          goalId: goalId,
          onSuccess: (blocGoal) {
            print('【影子模式】加载特定目标成功: ID=${blocGoal.id}, 标题=${blocGoal.title}');
          },
          onError: (error) {
            print('【影子模式】加载特定目标失败: $error');
          },
        );
      }
    } catch (e) {
      print('【GoalPage】加载特定目标出错: $e');
      setState(() {
        _isLoading = false;
        _error = '加载特定目标出错: $e';
      });
    }
  }

  // 构建浮动操作按钮
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showAddGoalDialog,
      backgroundColor: Colors.black,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  // 解释下一步操作
  void _explainNextSteps() {
    _log('=== BLoC渐进式迁移 - 下一步操作 ===');
    _log('当前进度: 已完成标题和描述编辑功能的BLoC适配');

    _log('1. 目前适配器状态:');
    _log('   - 执行模式: ${_blocAdapter?.executeMode ?? false ? '已启用' : '未启用'}');
    _log('   - 标题编辑功能: ${_featureToggles.titleEditing ? '已启用' : '未启用'}');
    _log('   - 描述编辑功能: ${_featureToggles.descriptionEditing ? '已启用' : '未启用'}');

    _log('2. 下一步建议:');
    _log('   a. 继续适配其他UI功能，如状态切换、日期更新等');
    _log('   b. 增加单元测试覆盖率，验证BLoC逻辑');
    _log('   c. 逐步提高BLoC执行模式的使用比例');

    _log('3. 渐进式启用流程:');
    _log('   a. 在开发者设置中启用特定功能');
    _log('   b. 使用该功能并验证其行为');
    _log('   c. 收集任何异常或不一致情况');
    _log('   d. 解决问题后再启用更多功能');

    _log('4. 当前迁移策略:');
    _log('   - 保留传统UI构建方法');
    _log('   - 使用BlocListener监听状态变化');
    _log('   - 根据功能开关决定使用传统方法还是BLoC方法');
    _log('   - 使用影子模式验证BLoC操作是否正确');

    _log('5. 完全迁移的标志:');
    _log('   - 所有功能都使用BLoC事件和状态');
    _log('   - UI完全由BlocBuilder/BlocConsumer构建');
    _log('   - 移除传统的setState调用');
    _log('   - 移除BLoC适配器');
  }

  // 记录BLoC操作结果，用于比较和调试
  void _logBlocOperationResult2({
    required String operation,
    required bool success,
    required String message,
    Map<String, dynamic>? data,
  }) {
    final logPrefix = success ? '✅ 成功' : '❌ 失败';
    print('【影子模式】$logPrefix - $operation: $message');

    // 如果有额外数据，打印出来
    if (data != null && data.isNotEmpty) {
      print('【影子模式】数据: $data');
    }

    // 如果启用了性能监控，记录操作结果
    _blocAdapter?.recordOperationResult(
      operation: operation,
      success: success,
      data: data,
    );
  }

  // 使用BLoC方式删除目标
  Future<void> _deleteGoalWithBloc2(Goal goal) async {
    if (goal.id == null) {
      print('【GoalPage】无法删除目标：ID为空');
      return;
    }

    print('【GoalPage】开始使用BLoC方式删除目标: ${goal.id}');

    try {
      setState(() {
        _isLoading = true;
      });

      // 创建一个Completer，用于异步等待BLoC操作完成
      final completer = Completer<void>();

      // 添加一次性监听器，等待状态更新
      late StreamSubscription<GoalState> subscription;
      subscription = context.read<GoalBloc>().stream.listen((state) {
        if (state is GoalsLoaded) {
          // 检查目标是否已被删除
          final isDeleted = !state.allGoals.any((g) => g.id == goal.id);

          if (isDeleted) {
            print('【GoalPage】BLoC删除目标成功: ${goal.id}');

            // 更新本地状态
            if (mounted && !completer.isCompleted) {
              setState(() {
                // 从goals列表中移除
                goals.removeWhere((g) => g.id == goal.id);

                // 如果删除的是当前目标，选择新的当前目标
                if (currentGoal?.id == goal.id) {
                  currentGoal = goals.isNotEmpty ? goals[0] : null;
                }

                // 更新allGoals
                allGoals = state.allGoals;

                _isLoading = false;
              });

              // 完成异步操作
              completer.complete();
              subscription.cancel();

              // 如果是子目标，通知父页面刷新
              if (widget.parentGoal != null &&
                  widget.onGoalTreeChanged != null) {
                widget.onGoalTreeChanged!();
              }
            }
          }
        } else if (state is GoalError) {
          print('【GoalPage】BLoC删除目标失败: ${state.message}');

          if (mounted && !completer.isCompleted) {
            setState(() {
              _error = '删除目标失败: ${state.message}';
              _isLoading = false;
            });

            // 完成异步操作
            completer.complete();
            subscription.cancel();
          }
        }
      });

      // 触发BLoC事件
      context.read<GoalBloc>().add(DeleteGoal(goal.id!));

      // 添加超时处理
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          print('【GoalPage】BLoC删除目标超时');
          subscription.cancel();

          if (mounted) {
            setState(() {
              _error = '删除目标超时';
              _isLoading = false;
            });
          }

          completer.complete();
        }
      });

      // 等待操作完成
      await completer.future;
    } catch (e) {
      print('【GoalPage】BLoC删除目标出错: $e');

      if (mounted) {
        setState(() {
          _error = '删除目标出错: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 获取图片提供者，处理本地文件和资源文件
  ImageProvider _getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      print('【GoalPage】图片路径为空，使用默认图片');
      return const AssetImage('assets/images/default/default.jpg');
    }

    if (path.startsWith('assets/')) {
      return AssetImage(path);
    } else {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          print('【GoalPage】图片文件不存在: $path');
          return const AssetImage('assets/images/default/default.jpg');
        }
      } catch (e) {
        print('【GoalPage】加载图片失败: $path, 错误: $e');
        return const AssetImage('assets/images/default/default.jpg');
      }
    }
  }

  // 统一的目标树刷新方法，处理传统模式和BLoC模式
  Future<void> _refreshGoalTreeUnified() async {
    print('【GoalPage】开始统一刷新目标树');

    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    try {
      setState(() {
        _isLoading = true;
      });

      if (isBlocModeEnabled) {
        // BLoC模式刷新
        await _refreshGoalTreeWithBloc();
      } else {
        // 传统模式刷新
        final startTime = DateTime.now();

        // 记录刷新前的目标树状态
        final int oldGoalsCount = allGoals.length;
        final Map<int?, List<int?>> oldParentChildMap = {};
        for (var goal in allGoals) {
          if (goal.id != null) {
            oldParentChildMap[goal.parentId] =
                oldParentChildMap[goal.parentId] ?? [];
            oldParentChildMap[goal.parentId]!.add(goal.id);
          }
        }
        print(
            '【GoalPage】刷新前的目标树: ${oldGoalsCount}个目标, ${oldParentChildMap[null]?.length ?? 0}个根目标');

        // 批次3阶段3：数据加载统一通过BLoC
        if (_featureToggles.dataLoadingViaBloc) {
          // 新路径：通过BLoC事件获取最新目标树
          print('【GoalPage】使用BLoC方式获取最新目标树');
          final completer = Completer<List<Goal>>();

          // 监听BLoC状态变化
          late final StreamSubscription<GoalState> subscription;
          subscription = context.read<GoalBloc>().stream.listen((state) {
            if (state is GoalsLoaded) {
              completer.complete(state.allGoals);
              subscription.cancel();
            } else if (state is GoalError) {
              completer.completeError(state.message);
              subscription.cancel();
            }
          });

          // 发送刷新事件
          context.read<GoalBloc>().add(RefreshGoalTree());

          // 等待结果
          allGoals = await completer.future;
        } else {
          // 传统路径：直接从数据库获取最新目标树
          print('【GoalPage】使用传统方式获取最新目标树');
          allGoals = await _dbHelper.getGoalTree();
        }

        // 记录刷新后的目标树状态
        final int newGoalsCount = allGoals.length;
        final Map<int?, List<int?>> newParentChildMap = {};
        for (var goal in allGoals) {
          if (goal.id != null) {
            newParentChildMap[goal.parentId] =
                newParentChildMap[goal.parentId] ?? [];
            newParentChildMap[goal.parentId]!.add(goal.id);
          }
        }
        print(
            '【GoalPage】刷新后的目标树: ${newGoalsCount}个目标, ${newParentChildMap[null]?.length ?? 0}个根目标');

        // 比较变化
        if (oldGoalsCount != newGoalsCount) {
          print('【GoalPage】目标总数变化: $oldGoalsCount -> $newGoalsCount');
        }

        // 检查每个父目标的子目标数量变化
        final Set<int?> allParentIds = {
          ...oldParentChildMap.keys,
          ...newParentChildMap.keys
        };
        for (var parentId in allParentIds) {
          final oldChildrenCount = oldParentChildMap[parentId]?.length ?? 0;
          final newChildrenCount = newParentChildMap[parentId]?.length ?? 0;
          if (oldChildrenCount != newChildrenCount) {
            print(
                '【GoalPage】父目标ID=$parentId 的子目标数量变化: $oldChildrenCount -> $newChildrenCount');
          }
        }

        final endTime = DateTime.now();
        print(
            '【GoalPage】传统方式加载完成，耗时: ${endTime.difference(startTime).inMilliseconds}ms，获取 ${allGoals.length} 个目标');

        if (mounted) {
          setState(() {
            // 更新当前页面的目标列表
            if (widget.parentGoal == null) {
              // 根页面goals为顶级目标
              goals = allGoals;
              print('【GoalPage】更新根目标列表: ${goals.length}个');
            } else {
              // 查找当前父目标的子目标
              final parentGoal = allGoals.firstWhere(
                (g) => g.id == widget.parentGoal!.id,
                orElse: () => widget.parentGoal!,
              );
              goals = parentGoal.subGoals;
              print(
                  '【GoalPage】更新子目标列表: ${goals.length}个, 父目标ID=${widget.parentGoal!.id}, 父目标标题=${widget.parentGoal!.title}');

              // 详细记录子目标信息
              for (var i = 0; i < goals.length; i++) {
                print(
                    '【GoalPage】子目标[$i]: ID=${goals[i].id}, 标题=${goals[i].title}, 父ID=${goals[i].parentId}');
              }
            }

            _isLoading = false;
          });
        }

        // 影子模式：也刷新BLoC状态
        _blocAdapter?.refreshGoalTree(
          onSuccess: (blocAllGoals) {
            print('【影子模式】目标树刷新成功: ${blocAllGoals.length}个目标');

            // 比较数据一致性
            if (blocAllGoals.length != allGoals.length) {
              print(
                  '【警告】目标树数据不一致: 传统=${allGoals.length}, BLoC=${blocAllGoals.length}');
            }

            // 在影子模式下也更新本地状态，确保两种模式数据一致
            if (mounted) {
              setState(() {
                allGoals = blocAllGoals;

                // 同时更新goals列表
                if (widget.parentGoal == null) {
                  goals = allGoals;
                } else {
                  // 查找当前父目标的子目标
                  final parentGoal = allGoals.firstWhere(
                    (g) => g.id == widget.parentGoal!.id,
                    orElse: () => widget.parentGoal!,
                  );
                  goals = parentGoal.subGoals;
                }
              });
            }
          },
          onError: (error) {
            print('【影子模式】目标树刷新失败: $error');
          },
        );
      }

      // 通知父组件目标树已更改
      widget.onGoalTreeChanged?.call();
    } catch (e) {
      print('【GoalPage】刷新目标树出错: $e');
      if (mounted) {
        setState(() {
          _error = '刷新目标树失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 查看子目标功能
  void _viewSubGoals() {
    if (currentGoal == null || currentGoal!.subGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前目标没有子目标')),
      );
      return;
    }

    print(
        '【GoalPage】查看子目标: 父ID=${currentGoal!.id}, 子目标数量=${currentGoal!.subGoals.length}');

    // 导航到子目标页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalPage(
          parentGoal: currentGoal,
          isSubGoalView: true, // 标记为子目标视图
          onGoalTreeChanged: () {
            // 子目标变化时刷新父页面
            _refreshGoalTreeUnified();
          },
        ),
      ),
    ).then((_) {
      // 返回后刷新目标树
      _refreshGoalTreeUnified();
    });
  }

  /// 基于BLoC状态的子条目添加方法
  void _addSubGoalFromFullScreenWithState(GoalsLoaded state) async {
    if (state.currentGoal == null) return;

    // 显示新增子条目弹窗
    _showAddGoalDialog();
  }

  /// 基于BLoC状态的查看子条目方法
  void _viewSubGoalsWithState(GoalsLoaded state) {
    if (state.currentGoal == null || state.currentGoal!.subGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前目标没有子目标')),
      );
      return;
    }

    print(
        '【GoalPage】查看子目标: 父ID=${state.currentGoal!.id}, 子目标数量=${state.currentGoal!.subGoals.length}');

    // 导航到子目标页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalPage(
          parentGoal: state.currentGoal,
          isSubGoalView: true, // 标记为子目标视图
          onGoalTreeChanged: () {
            // 子目标变化时刷新父页面
            _refreshGoalTreeUnified();
          },
        ),
      ),
    ).then((_) {
      // 返回后刷新目标树
      _refreshGoalTreeUnified();
    });
  }
}
