import 'package:flutter/material.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/pages/settings_page.dart';
import 'package:linzaivision_primary/widgets/search/goal_search_delegate.dart';
import 'package:linzaivision_primary/widgets/search/goal_search_delegate_bloc.dart';
import 'package:linzaivision_primary/views/full_screen_view.dart';
import 'package:linzaivision_primary/views/grid_view.dart';
import 'package:linzaivision_primary/views/timeline_view.dart';
import 'package:linzaivision_primary/views/goal_tree_view.dart';
import 'package:linzaivision_primary/views/explore_view.dart';
import 'package:linzaivision_primary/widgets/menus/goal_menus.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/pages/auth/login_page.dart';
import 'package:linzaivision_primary/pages/membership/membership_page.dart';
import 'package:linzaivision_primary/widgets/common/share_dialog.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/widgets/pickers/image_picker_dialog.dart';
import 'package:linzaivision_primary/widgets/pickers/membership_prompt_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
// 导入BLoC适配器
import 'goal_page_bloc_adapter.dart';
// 导入错误处理工具
import '../utils/error_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search/search_bloc.dart';
import '../routes/navigation_service.dart'; // 导入NavigationService
import '../routes/app_routes.dart'; // 导入AppRoutes
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/goal/goal_state.dart';
import '../utils/bloc_feature_toggles.dart';
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
  bool _isLoading = true;
  String? _error;

  // 添加数据库支持
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 编辑状态控制
  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();

  /// 用户会员状态（模拟数据，实际应该从用户系统获取）
  int _membershipStatus = 0;

  // 添加倒计时显示状态变量:
  bool _showCountdown = false; // 默认不显示倒计时
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
        if (mounted && allGoals.isEmpty) {
          print('检测到树视图数据为空，尝试重新加载');
          await _refreshGoalTree();
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

      // 始终加载全量目标树
      allGoals = await _dbHelper.getGoalTree();

      final loadedGoals =
          await _dbHelper.getGoals(parentId: widget.parentGoal?.id);

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

        // 重新从数据库加载数据以确保数据完整
        final reloadedGoals =
            await _dbHelper.getGoals(parentId: widget.parentGoal?.id);
        setState(() {
          goals = reloadedGoals;
          if (goals.isNotEmpty && currentGoal == null) {
            currentGoal = goals[0];
          }
          _isLoading = false;
        });

        await _refreshGoalTree();
      } else {
        setState(() {
          goals = loadedGoals;
          if (goals.isNotEmpty && currentGoal == null) {
            currentGoal = goals[0];
          }
          _isLoading = false;
        });
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
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
        _isLoading = false;
      });
    }
  }

  // 保存初始目标数据
  Future<void> _saveInitialGoals() async {
    print('开始保存初始数据到数据库');

    try {
      // 使用批量插入事务提高性能
      await _dbHelper.batchInsertGoalTree(goals);

      print('初始数据保存完成');

      // 使用BLoC适配器保存初始数据（影子模式）
      _blocAdapter?.saveInitialGoals(
        goals: goals,
        onSuccess: () {
          print('BLoC保存初始数据成功 - 影子模式');
        },
        onError: (error) {
          print('BLoC保存初始数据失败 - 影子模式: $error');
        },
      );
    } catch (e) {
      print('保存初始数据出错: $e');

      // 如果批量插入失败，回退到单个保存方式
      // 使用Future.wait确保所有异步操作完成
      List<Future> saveFutures = [];

      for (var goal in goals) {
        // 先保存父目标
        print('保存父目标: ${goal.title}');
        final Future<int> idFuture = _dbHelper.insertGoal(goal);

        // 添加处理完成后设置ID的回调
        final parentFuture = idFuture.then((id) {
          goal.id = id; // 保存数据库生成的ID
          print('父目标ID: ${goal.id}');

          // 保存子目标并设置父子关系
          List<Future> subFutures = [];
          if (goal.subGoals.isNotEmpty) {
            print('保存子目标，数量: ${goal.subGoals.length}');
            for (var subGoal in goal.subGoals) {
              subGoal.parentId = goal.id; // 设置父目标ID
              print('设置子目标父ID: ${subGoal.title} -> 父ID: ${subGoal.parentId}');
              final subFuture = _dbHelper.insertGoal(subGoal).then((subId) {
                subGoal.id = subId;
                print('子目标已保存，ID: ${subGoal.id}');
              });
              subFutures.add(subFuture);
            }
          }
          return Future.wait(subFutures);
        });

        saveFutures.add(parentFuture);
      }

      await Future.wait(saveFutures);
    }
  }

  // 刷新目标树结构
  Future<void> _refreshGoalTree() async {
    final executeMode = _blocAdapter?.executeMode ?? false;
    print('【GoalPage】开始刷新目标树，当前模式: ${executeMode ? "BLoC模式" : "传统模式"}');
    
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

        print('【GoalPage】使用传统方式刷新目标树');
        final startTime = DateTime.now();
      allGoals = await _dbHelper.getGoalTree();
        final endTime = DateTime.now();
        print(
            '【GoalPage】传统方式加载完成，耗时: ${endTime.difference(startTime).inMilliseconds}ms，获取 ${allGoals.length} 个目标');

      if (mounted) {
        setState(() {
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
              
              // 在影子模式下也更新本地状态，确保两种模式数据一致
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
            print('【GoalPage】BLoC刷新目标树失败 - 影子模式: $error');
          },
        );

        // 通知父组件目标树已更改
        widget.onGoalTreeChanged?.call();
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

      // 保存到数据库
      final id = await _dbHelper.insertGoal(goal);
      goal.id = id;
      print('【GoalPage】子目标创建成功: ID=$id, 父ID=${goal.parentId}');

      // 更新UI
      setState(() {
        goals.insert(0, goal); // 插入到列表开头
        currentGoal = goal; // 选中新创建的目标
      });

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

      // 更新数据库
      await _dbHelper.updateGoal(goal);

      // 更新UI
      setState(() {
        final index = goals.indexWhere((g) => g.id == goal.id);
        if (index != -1) {
          goals[index] = goal;
          if (currentGoal?.id == goal.id) {
            currentGoal = goal;
          }
        }
      });

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
      // 从数据库中删除
      await _dbHelper.deleteGoal(goal.id!);

      // 更新UI
      setState(() {
        goals.remove(goal);
        if (currentGoal?.id == goal.id) {
          currentGoal = goals.isNotEmpty ? goals[0] : null;
        }
      });

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
    // 检查是否启用了任何BLoC功能
    final bool isBlocEnabled = _blocAdapter?.executeMode ?? false;
    
    // 如果启用了BLoC功能，使用BlocListener进行状态监听
    // BlocListener只监听状态，不参与UI构建，因此可以安全地在其回调中调用setState
    return isBlocEnabled 
        ? BlocListener<GoalBloc, GoalState>(
            listenWhen: (previous, current) {
              // 只在状态真正变化时触发监听
              if (previous is GoalsLoaded && current is GoalsLoaded) {
                // 检查目标树数据变化
                if (previous.allGoals.length != current.allGoals.length) {
                  print(
                      '【GoalPage】BlocListener监测到目标树变化: ${previous.allGoals.length} -> ${current.allGoals.length}');
                  return true;
                }
                
                // 检查所有可能需要UI更新的状态变化
                final prevGoal = previous.currentGoal;
                final currGoal = current.currentGoal;
                
                // 如果当前目标发生变化，需要更新
                if (prevGoal?.id != currGoal?.id) {
                  print(
                      '【GoalPage】BlocListener监测到目标ID变化: ${prevGoal?.id} -> ${currGoal?.id}');
                  return true;
                }
                
                // 如果当前目标的属性发生变化，需要更新
                if (prevGoal != null &&
                    currGoal != null &&
                    prevGoal.id == currGoal.id) {
                  final titleChanged = prevGoal.title != currGoal.title;
                  final descChanged =
                      prevGoal.description != currGoal.description;
                  final statusChanged = prevGoal.status != currGoal.status;
                  final dateChanged =
                      prevGoal.targetDate != currGoal.targetDate;
                  final countdownChanged = prevGoal.hasCustomCountdown !=
                          currGoal.hasCustomCountdown ||
                      prevGoal.customCountdownDays !=
                          currGoal.customCountdownDays;
                  final mediaChanged =
                      prevGoal.imagePath != currGoal.imagePath ||
                                       prevGoal.videoPath != currGoal.videoPath || 
                                       prevGoal.hasVideo != currGoal.hasVideo;
                  
                  if (titleChanged ||
                      descChanged ||
                      statusChanged ||
                      dateChanged ||
                      countdownChanged ||
                      mediaChanged) {
                    print('【GoalPage】BlocListener监测到目标属性变化: ' +
                          (titleChanged ? '标题 ' : '') +
                          (descChanged ? '描述 ' : '') +
                          (statusChanged ? '状态 ' : '') +
                          (dateChanged ? '日期 ' : '') +
                          (countdownChanged ? '倒计时 ' : '') +
                          (mediaChanged ? '媒体 ' : ''));
                    return true;
                  }
                }
                
                // 如果UI状态发生变化，需要更新
                final editTitleChanged =
                    previous.isEditingTitle != current.isEditingTitle;
                final editDescChanged = previous.isEditingDescription !=
                    current.isEditingDescription;
                final viewModeChanged = previous.viewMode != current.viewMode;
                final showCountdownChanged =
                    previous.showCountdown != current.showCountdown;
                final showTimeChanged = previous.showTime != current.showTime;
                final showDescChanged =
                    previous.showDescription != current.showDescription;
                final showTitleChanged =
                    previous.showTitle != current.showTitle;

                if (editTitleChanged ||
                    editDescChanged ||
                    viewModeChanged ||
                    showCountdownChanged ||
                    showTimeChanged ||
                    showDescChanged ||
                    showTitleChanged) {
                  print('【GoalPage】BlocListener监测到UI状态变化: ' +
                        (editTitleChanged ? '标题编辑 ' : '') +
                        (editDescChanged ? '描述编辑 ' : '') +
                        (viewModeChanged ? '视图模式 ' : '') +
                        (showCountdownChanged ? '显示倒计时 ' : '') +
                        (showTimeChanged ? '显示时间 ' : '') +
                        (showDescChanged ? '显示描述 ' : '') +
                        (showTitleChanged ? '显示标题 ' : ''));
                  return true;
                }
                
                return false;
              }
              return true; // 其他状态类型变化时都触发
            },
            listener: (context, state) {
              if (state is GoalsLoaded) {
                _log('收到BLoC状态更新: ${state.runtimeType}');
                
                // 在listener回调中同步状态
                syncStateFromBloc(state);
              }
              
              if (state is GoalError) {
                _log('BLoC错误: ${state.message}', true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('操作失败: ${state.message}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            // 保持原有UI构建不变
            child: _buildScaffold(),
          )
        : _buildScaffold();
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
      
      // 同步目标树数据 (allGoals)
      if (state.allGoals.isNotEmpty) {
        print('【GoalPage】同步目标树数据: ${state.allGoals.length} 个目标');
        setState(() {
          allGoals = state.allGoals;
          
          // 如果是根页面，同时更新goals列表
          if (widget.parentGoal == null) {
            goals = allGoals;
          } else {
            // 如果是子目标页面，更新子目标列表
            final parentGoal = allGoals.firstWhere(
              (g) => g.id == widget.parentGoal!.id,
              orElse: () => widget.parentGoal!,
            );
            goals = parentGoal.subGoals;
          }
        });
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
      
      // 当前目标 - 只在明确需要切换目标时才更新
      if (state.currentGoal != null && 
          (currentGoal == null || currentGoal!.id != state.currentGoal!.id)) {
        print(
            '【GoalPage】同步当前目标: ${currentGoal?.id} -> ${state.currentGoal!.id}');
        setState(() {
          currentGoal = state.currentGoal;
          // 确保标题编辑器内容与当前目标匹配
          if (_isEditingTitle) {
            _titleController.text = state.currentGoal!.title;
          }
          
          // 同时更新goals列表中的对应项
          if (state.goals.isNotEmpty) {
            goals = state.goals;
          }
        });
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
        
        // 检查描述更新
        if (_featureToggles.descriptionEditing && 
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
      if (state.showCountdown != _showCountdown) {
        setState(() {
          _showCountdown = state.showCountdown;
        });
      }
      
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
        setState(() {
          _showTitle = state.showTitle;
        });
      }
      
      // 同步视图模式
      if (state.viewMode != currentView) {
        setState(() {
          currentView = state.viewMode;
        });
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
      extendBodyBehindAppBar: currentView == 0,
      appBar: AppBar(
        backgroundColor: currentView == 0 ? Colors.transparent : Colors.white,
        elevation: currentView == 0 ? 0 : 1,
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) => IconButton(
            icon: Image.asset(
              'assets/icons/Menu-white.png',
              width: 24,
              height: 24,
              color: currentView == 0 ? Colors.white : Colors.black,
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
                    color: currentView == 0 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'STZhongsong',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        iconTheme: IconThemeData(
          color: currentView == 0 ? Colors.white : Colors.black,
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              currentView == 0
                  ? 'assets/icons/View-switch-white.png'
                  : currentView == 1
                      ? 'assets/icons/View-switch-white.png'
                      : 'assets/icons/View-switch-white.png',
              width: 24,
              height: 24,
              color: currentView == 0 ? Colors.white : Colors.black,
            ),
            onPressed: _onChangeView,
          ),
          if (currentView == 0 && currentGoal != null)
            GoalOperationMenu(
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
              onToggleCountdown: _toggleCountdown,
              showCountdown: _showCountdown,
              onToggleTime: _toggleShowTime,
              showTime: _showTime,
              onToggleDescription: _toggleShowDescription,
              showDescription: _showDescription,
              onToggleTitle: () {
                setState(() {
                  _showTitle = !_showTitle;
                });
              },
              showTitle: _showTitle,
              onToggleDeadline: () {
                if (currentGoal != null) {
                  _toggleDeadline(currentGoal!);
                }
              },
              onAddSubGoal: () {
                _addSubGoalFromFullScreen();
              },
              onToggleCustomCountdown: () {
                if (currentGoal != null) {
                  _showCustomCountdownDialog();
                }
              },
              hasCustomCountdown: currentGoal?.hasCustomCountdown ?? false,
              // 添加查看子目标的回调
              onViewSubGoals: _viewSubGoals,
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (currentView == 0)
            // 全屏视图的背景
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: currentGoal?.imagePath != null &&
                          currentGoal!.imagePath.isNotEmpty
                      ? _getImageProvider(currentGoal!.imagePath)
                      : AssetImage('assets/images/default/default.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (currentView != 0)
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
              index: currentView,
              children: [
                Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),
                    _buildFullScreenView(),
                  ],
                ),
                _buildTimelineView(),
                _buildGridView(),
              ],
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  // 日志方法，用于追踪BLoC相关操作
  void _log(String message, [bool forceLog = false]) {
    if ((_blocAdapter?.logLevel ?? 0) > 1 || forceLog) {
      debugPrint('【GoalPage】$message');
    }
  }

  void _onChangeView() {
    setState(() {
      currentView = (currentView + 1) % 3;
    });
  }

  // 全屏视图
  Widget _buildFullScreenView() {
    if (goals.isEmpty || currentGoal == null) {
      return const Center(child: Text('没有目标'));
    }

    return FullScreenView(
      currentGoal: currentGoal,
      goals: goals,
      isEditingTitle: _isEditingTitle,
      titleController: _titleController,
      onTitleEdit: _startTitleEdit,
      onTitleSave: _saveTitleEdit,
      onDescriptionEdit: () {
        setState(() {
          _showDescription = !_showDescription;
        });
      },
      onSaveDescription: _updateGoalDescription,
      onImagePick: _pickImage,
      onGoalSelect: (goal) {
        setState(() {
          currentGoal = goal;
        });
      },
      onAddGoal: () => _addNewGoalWrapper(),
      onStatusChange: _handleUpdateGoalStatusSimple,
      onUpdateDate: _updateGoalDate,
      showTime: _showTime,
      showDescription: _showDescription,
      showTitle: _showTitle,
      onToggleTitle: () {
        setState(() {
          _showTitle = !_showTitle;
        });
      },
      onToggleDeadline: _toggleDeadline,
      onAddSubGoal: () => _addSubGoalFromFullScreen(),
      onSetCustomCountdown: (goal, days) =>
          _setCustomCountdownForGoal(goal, days),
      hasCustomCountdown: currentGoal?.hasCustomCountdown ?? false,
    );
  }

  // 开始编辑标题
  void _startTitleEdit() {
    // 确保有当前目标
    if (currentGoal == null) {
      print('【GoalPage】无法编辑标题：没有选中的目标');
      return;
    }
    
    // 检查BLoC适配器执行模式状态和标题编辑功能开关
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
    final bool isTitleEditingEnabled = _featureToggles.titleEditing;
    
    print(
        '【GoalPage】开始编辑标题，BLoC模式: ${isBlocModeEnabled && isTitleEditingEnabled}, 目标ID: ${currentGoal!.id}');
    
    if (isBlocModeEnabled && isTitleEditingEnabled) {
      // 首先确保BLoC知道当前选中的目标
      context.read<GoalBloc>().add(SelectGoal(currentGoal!));
      
      // 然后使用BLoC触发标题编辑事件
      context.read<GoalBloc>().add(const StartEditingTitle());
      
      // 设置标题控制器文本
      _titleController.text = currentGoal!.title;
      
      // 也在本地设置编辑状态，不仅依赖BLoC状态同步
      setState(() {
        _isEditingTitle = true;
      });
    } else {
      // 保持原有行为
    _titleController.text = currentGoal!.title;
    setState(() {
      _isEditingTitle = true;
    });
    }
  }

  // 保存标题
  void _saveTitleEdit() {
    if (_titleController.text.isNotEmpty && currentGoal != null) {
      final updatedGoal = currentGoal!.copyWith(
        title: _titleController.text,
      );
      
      // 检查BLoC适配器执行模式状态和标题编辑功能开关
      final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
      final bool isTitleEditingEnabled = _featureToggles.titleEditing;
      
      print(
          '【GoalPage】保存标题编辑，BLoC模式: ${isBlocModeEnabled && isTitleEditingEnabled}, 新标题: ${_titleController.text}');
      
      // 根据BLoC模式状态选择更新方法
      if (isBlocModeEnabled && isTitleEditingEnabled) {
        // 使用UpdateGoal事件更新标题，确保传递完整的目标信息
        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
        
        // 手动关闭编辑状态，不要等待BLoC状态同步
        setState(() {
          _isEditingTitle = false;
          // 立即更新本地目标，避免UI闪烁
          currentGoal = updatedGoal;
          
          // 同时更新goals列表中的对应项
          final index = goals.indexWhere((g) => g.id == updatedGoal.id);
          if (index != -1) {
            goals[index] = updatedGoal;
          }
        });
      } else {
        // 使用传统方式更新目标
      _updateGoal(updatedGoal);
        
        setState(() {
          _isEditingTitle = false;
        });
      }
    } else {
      // 取消编辑
      setState(() {
        _isEditingTitle = false;
      });
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
                    color: Colors.black.withOpacity(0.8),
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '在这里添加描述',
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black.withOpacity(0.1),
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
        setState(() {
          currentGoal = goal;
          currentView = 0;
        });
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
        setState(() {
          currentGoal = goal;
          currentView = 0;
        });
      },
      onAddGoal: _showAddGoalDialog,
      onShowOperationMenu: (context, goal) {
        // 只处理删除目标的确认对话框
        _showDeleteGoalDialog(goal);
      },
    );
  }

  // 显示删除目标确认对话框
  void _showDeleteGoalDialog(Goal goal) {
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
    
    showDialog(
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
                // 确认信息
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Text(
                    '您确定要删除这个目标吗？此操作无法撤销。',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
                // 添加BLoC模式提示（如果启用）
                if (isBlocModeEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
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
                ),
                // 按钮区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 取消按钮
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 确认删除按钮
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          // 根据BLoC模式状态选择删除方法
                          if (isBlocModeEnabled) {
                            _deleteGoalWithBloc(goal);
                          } else {
                          _deleteGoal(goal);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          '删除',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  // 添加新建目标的方法
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

    // 以下是原有的添加目标弹窗逻辑
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    // 移除 selectedDate 变量，不再需要日期选择
    String? imagePath;
    
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    // 创建一个StatefulBuilder以确保弹窗内的状态更新能够刷新UI
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
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
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.parentGoal != null ? '新建子条目' : '新建条目',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.9),
                            ),
                          ),
                          if (widget.parentGoal != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  widget.parentGoal!.title.length > 15
                                      ? widget.parentGoal!.title
                                              .substring(0, 12) +
                                          '...'
                                      : widget.parentGoal!.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
                // 内容区域 - 使用SingleChildScrollView
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 目标标题标签(必填)
                        Row(
                          children: [
                            const Text(
                              '*',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '标题',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 目标标题输入
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: titleController,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            decoration: InputDecoration(
                              hintText: '输入标题',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 描述标签(非必填)
                        Text(
                          '描述',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 目标描述输入
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: descriptionController,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: '输入描述',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 日期和图片选择器
                        Row(
                          children: [
                            // 移除日期选择按钮，只保留图片选择按钮
                            // 图片选择按钮，修改为调用_showImagePickerForNewGoal
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // 显示选择背景弹窗
                                  _showImagePickerForNewGoal((selectedImagePath,
                                      {isVideo = false}) {
                                    // 使用StatefulBuilder的setState刷新弹窗UI
                                    setDialogState(() {
                                      imagePath = selectedImagePath;
                                      // 如果是视频，可以在这里设置额外标记
                                      // 但由于这是新建目标的弹窗，我们会在创建Goal时设置hasVideo属性
                                    });
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 16,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        imagePath == null ? '选择背景' : '已选择背景',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // 添加BLoC模式选择
                        if (isBlocModeEnabled) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
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
                                    'BLoC模式已启用，将使用BLoC架构添加目标',
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
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        // 检查是否是视频文件
                        bool isVideo = false;
                        if (imagePath != null) {
                          final lowerPath = imagePath!.toLowerCase();
                          isVideo = lowerPath.endsWith('.mp4') ||
                              lowerPath.endsWith('.mov') ||
                              lowerPath.endsWith('.avi') ||
                              lowerPath.endsWith('.wmv') ||
                              lowerPath.endsWith('.mkv');
                        }

                        final newGoal = Goal(
                          title: titleController.text,
                          description: descriptionController.text,
                          imagePath:
                              imagePath ?? 'assets/images/default/default.jpg',
                          createdTime: DateTime.now(),
                          targetDate: null, // 不设置目标日期
                          parentId: widget.parentGoal?.id,
                          videoPath: isVideo ? imagePath : null,
                          hasVideo: isVideo,
                          videoMuted: false, // 默认不静音
                        );

                        // 先关闭弹窗
                        Navigator.pop(context);

                        // 暂时禁用BLoC模式，使用传统方式添加目标
                        // 根据BLoC模式状态选择添加方法
                        /*if (isBlocModeEnabled) {
                          // 使用BLoC架构添加目标
                          _addNewGoalWithBloc(newGoal);
                        } else {*/
                          // 使用传统方式添加目标
                        _addNewGoal(newGoal);
                        //}
                      }
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
                    child: Text(
                      widget.parentGoal != null ? '创建子条目' : '创建条目',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
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
                        setState(() {
                          goal.status = GoalStatus.pending;
                        });
                        Navigator.pop(context);
                      },
                      isPending: true,
                    ),
                    _buildStatusOption(
                      icon: Icons.check_circle_outline,
                      label: '已完成',
                      isSelected: goal.status == GoalStatus.completed,
                      onTap: () {
                        setState(() {
                          goal.status = GoalStatus.completed;
                        });
                        Navigator.pop(context);
                      },
                      isPending: false,
                    ),
                    _buildStatusOption(
                      icon: Icons.cancel_outlined,
                      label: '已放弃',
                      isSelected: goal.status == GoalStatus.abandoned,
                      onTap: () {
                        setState(() {
                          goal.status = GoalStatus.abandoned;
                        });
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

  // 切换倒计时显示
  void _toggleCountdown() {
    setState(() {
      _showCountdown = !_showCountdown;
    });
  }

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

    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;

    return Drawer(
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
                    _showSearch();
            },
            onSyncTap: _handleSyncTap,
            membershipStatus: _membershipStatus,
            onDeleteGoal: _handleDeleteGoalFromTree,
            onUpdateGoalStatus: _handleUpdateGoalStatusFromTree,
            onGoalSelect: (goal) {
                    // 关闭抽屉
                    Navigator.pop(context);
                    
                    // 直接加载目标，而不是通过路由
                    print(
                        '【GoalPage】从目标树选择目标: ID=${goal.id}, 标题=${goal.title}, 父ID=${goal.parentId}, 是否子目标=${goal.parentId != null}');
                    _loadSpecificGoal(goal.id!);
                  },
                  isLoggedIn: authService.isLoggedIn,
                  userAvatar: authService.avatarUrl,
            onSettingsTap: () {
                    // 关闭抽屉
                    Navigator.pop(context);
                    
                    // 使用NavigationService导航到设置页面
                    NavigationService().navigateTo(AppRoutes.settings);
            },
            onLoginTap: () {
                    // 关闭抽屉
                    Navigator.pop(context);
                    
                    // 使用NavigationService导航到登录页面
                    NavigationService().navigateTo(AppRoutes.login);
                  },
                  onLogout: _handleLogout,
                  onExploreTab: () {
                    // 关闭抽屉
                    Navigator.pop(context);
                    
                    // 使用NavigationService导航到探索页面
                    NavigationService().navigateTo(AppRoutes.explore);
                  },
                ),
              ),
              // 开发者选项区域
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '开发者选项',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BLoC模式',
                          style: TextStyle(fontSize: 14),
                        ),
                        Switch(
                          value: isBlocModeEnabled,
                          onChanged: (value) {
                            if (value) {
                              _enableBlocMode();
                            } else {
                              // 禁用BLoC模式
                              setState(() {
                                _blocAdapter = GoalPageBlocAdapter(
                context,
                                  logLevel: 2,
                                  executeMode: false,
                                );
                                print('已禁用BLoC执行模式 - 恢复影子模式');
                              });
                            }
                            Navigator.pop(context); // 关闭抽屉
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBlocModeEnabled ? '当前模式：BLoC执行模式' : '当前模式：影子模式',
                      style: TextStyle(
                        fontSize: 12,
                        color: isBlocModeEnabled ? Colors.green : Colors.orange,
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '性能统计',
                          style: TextStyle(fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bar_chart, size: 20),
                          onPressed: () {
                            Navigator.pop(context); // 关闭抽屉
                            _showPerformanceStats();
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '错误统计',
                          style: TextStyle(fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.error_outline, size: 20),
                          onPressed: () {
                            Navigator.pop(context); // 关闭抽屉
                            ErrorHandler.showErrorStatsDialog(context);
                          },
                        ),
                      ],
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

  void _toggleShowTime() {
    setState(() {
      _showTime = !_showTime;
    });
  }

  void _toggleShowDescription() {
    setState(() {
      _showDescription = !_showDescription;
    });
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

  // 更新目标描述
  void _updateGoalDescription(Goal goal, String newDescription) {
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
      
      // 检查BLoC适配器执行模式状态
      final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
      
      print(
          '【GoalPage】更新目标状态，BLoC模式: $isBlocModeEnabled, 目标ID: ${goal.id}, 新状态: $newStatus');
      
      // 根据BLoC模式状态选择更新方法
      if (isBlocModeEnabled) {
        // 使用UpdateGoal事件直接更新状态，确保传递完整的目标信息
        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
        
        // 立即更新本地状态，避免UI闪烁
        setState(() {
          // 更新当前目标
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
      await _updateGoal(updatedGoal);
        
        // 确保UI立即更新
        setState(() {
          // 更新当前目标
          if (currentGoal?.id == goal.id) {
            currentGoal = updatedGoal;
          }
          
          // 同时更新goals列表中的对应项
          final index = goals.indexWhere((g) => g.id == goal.id);
          if (index != -1) {
            goals[index] = updatedGoal;
          }
        });
      }
    }
  }

  // 更新目标日期
  Future<bool> _updateGoalDate(Goal goal, DateTime? newDate) async {
    try {
      final updatedGoal = goal.copyWith(targetDate: newDate);
      
      // 检查BLoC适配器执行模式状态
      final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
      
      print(
          '【GoalPage】更新目标日期，BLoC模式: $isBlocModeEnabled, 目标ID: ${goal.id}, 新日期: ${newDate?.toString() ?? "无"}');
      
      // 根据BLoC模式状态选择更新方法
      if (isBlocModeEnabled) {
        // 使用UpdateGoal事件直接更新日期，确保传递完整的目标信息
        context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
        
        // 立即更新本地状态，避免UI闪烁
        setState(() {
          // 更新当前目标
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
        
        // 确保UI立即更新
        setState(() {
          // 更新当前目标
          if (currentGoal?.id == goal.id) {
            currentGoal = updatedGoal;
          }
          
          // 同时更新goals列表中的对应项
          final index = goals.indexWhere((g) => g.id == goal.id);
          if (index != -1) {
            goals[index] = updatedGoal;
          }
        });
        
        // 影子模式：通过BLoC适配器执行相同操作
        _blocAdapter?.updateGoalDate(
          goal: goal,
          newDate: newDate,
          onSuccess: () {
            print('【影子模式】目标日期更新成功：${goal.title}');
          },
          onError: (error) {
            print('【影子模式】目标日期更新失败：$error');
          },
        );
      }
      
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

  // 显示自定义倒计时对话框
  Future<void> _showCustomCountdownDialog() async {
    if (currentGoal == null) return;

    // 简化版本：只切换倒计时显示状态，不设置具体倒计时
    setState(() {
      _showCountdown = !_showCountdown;
    });
    
    // 添加提示信息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('倒计时功能将在架构迁移完成后重新实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 为特定目标设置自定义倒计时
  Future<void> _setCustomCountdownForGoal(Goal goal, int? days) async {
    // 简化版本：只切换倒计时显示状态
                    setState(() {
      _showCountdown = days != null;
    });
    
    // 添加提示信息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('倒计时功能将在架构迁移完成后重新实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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

  /// 使用BLoC直接设置自定义倒计时
  /// 
  /// 这是一个完全使用BLoC架构的方法，不再直接操作数据库
  Future<void> _setCustomCountdownForGoalWithBloc(Goal goal, int? days) async {
    // 简化版本：只切换倒计时显示状态
    setState(() {
      _showCountdown = days != null;
    });
    
    // 添加提示信息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('倒计时功能将在架构迁移完成后重新实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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

  /// 使用搜索功能
  void _showSearch() {
    // 检查BLoC适配器执行模式状态
    final bool isBlocModeEnabled = _blocAdapter?.executeMode ?? false;
    
    // 根据BLoC模式状态选择搜索方法
    if (isBlocModeEnabled) {
      _showSearchWithBloc();
    } else {
      showSearch(
        context: context,
        delegate: GoalSearchDelegate(goals),
      );
    }
  }

  /// 使用BLoC架构的搜索功能
  void _showSearchWithBloc() async {
    try {
      // 获取SearchBloc
      final searchBloc = BlocProvider.of<SearchBloc>(context);
      
      // 显示基于BLoC的搜索代理
      final selectedGoal = await showSearch<Goal?>(
        context: context,
        delegate: GoalSearchDelegateBloc(searchBloc),
      );
      
      // 处理选中的目标
      if (selectedGoal != null && mounted) {
        setState(() {
          currentGoal = selectedGoal;
          currentView = 0; // 切换到全屏视图
        });
        
        // 记录性能数据
        if (_blocAdapter != null) {
          print('搜索并选择了目标: ${selectedGoal.title}');
        }
      }
    } catch (e) {
      print('使用BLoC搜索失败: $e');
      
      // 回退到传统搜索
      showSearch(
        context: context,
        delegate: GoalSearchDelegate(goals),
      );
    }
  }

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
        // 使用传统方式加载特定目标
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
          
          setState(() {
            currentGoal = goal;
            goals = siblingGoals; // 设置同级目标列表
            currentView = 0; // 切换到全屏视图
            _isLoading = false;
          });
          
          // 使用BLoC适配器加载特定目标（影子模式）
          _blocAdapter?.loadSpecificGoal(
            goalId: goalId,
            onSuccess: (blocGoal) {
              print('【影子模式】加载特定目标成功: ID=${blocGoal.id}, 标题=${blocGoal.title}');
              
              // 比较数据差异
              if (blocGoal.id != goal.id) {
                print('【影子模式】数据差异: 传统ID=${goal.id}, BLoC ID=${blocGoal.id}');
              }
              if (blocGoal.title != goal.title) {
                print(
                    '【影子模式】数据差异: 传统标题=${goal.title}, BLoC标题=${blocGoal.title}');
              }
            },
            onError: (error) {
              print('【影子模式】加载特定目标失败: $error');
            },
          );
        } else {
          print('【GoalPage】通过传统方式加载特定目标失败: 未找到目标 $goalId');
          setState(() {
            _isLoading = false;
            _error = '未找到目标: $goalId';
          });
        }
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
        
        // 获取最新的目标树
        allGoals = await _dbHelper.getGoalTree();
        
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
}
