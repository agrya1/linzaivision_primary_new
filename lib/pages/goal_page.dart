import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/pages/settings_page.dart';
import 'package:linzaivision_primary/widgets/search/goal_search_delegate.dart';
import 'package:linzaivision_primary/views/full_screen_view.dart';
import 'package:linzaivision_primary/views/grid_view.dart';
import 'package:linzaivision_primary/views/timeline_view.dart';
import 'package:linzaivision_primary/views/goal_tree_view.dart';
import 'package:linzaivision_primary/views/explore_view.dart';
import 'package:linzaivision_primary/widgets/status/goal_status_widget.dart';
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

/// 主页面
class GoalPage extends StatefulWidget {
  final Goal? parentGoal;
  final VoidCallback? onGoalTreeChanged;

  const GoalPage({
    super.key,
    this.parentGoal,
    this.onGoalTreeChanged,
  });

  @override
  GoalPageState createState() => GoalPageState();
}

class GoalPageState extends State<GoalPage> {
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

    // 立即检查用户登录状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });

    // 加载数据
    _loadGoals();

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

        // 刷新目标树
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
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
        _isLoading = false;
      });
    }
  }

  // 保存示例数据到数据库
  Future<void> _saveInitialGoals() async {
    print('开始保存初始数据到数据库');

    try {
      // 使用批量插入事务提高性能
      await _dbHelper.batchInsertGoalTree(goals);

      print('初始数据保存完成');
    } catch (e) {
      print('保存初始数据出错: $e');

      // 如果批量插入失败，回退到单个保存方式
      print('尝试使用单个保存方式...');

      // 创建一个列表存储所有保存操作的Future
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

      // 等待所有保存操作完成
      await Future.wait(saveFutures);
      print('初始数据保存完成（单个保存方式）');
    }
  }

  /// 刷新目标树
  Future<void> _refreshGoalTree() async {
    try {
      setState(() {
        _isLoading = true; // 显示加载状态
      });

      // 始终加载全量目标树
      allGoals = await _dbHelper.getGoalTree();

      // 调试输出目标树结构
      print(
          '目标树结构：${allGoals.map((g) => '${g.id}:${g.title} (子项:${g.subGoals.length})').join(', ')}');

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
    } catch (e) {
      print('_refreshGoalTree出错: $e');
      if (mounted) {
        setState(() {
          _error = '加载数据失败: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新数据失败: $e')),
        );
      }
    }
  }

  /// 添加新目标
  Future<void> _addNewGoal(Goal goal) async {
    try {
      // 设置父目标ID
      goal.parentId = widget.parentGoal?.id;

      // 保存到数据库
      final id = await _dbHelper.insertGoal(goal);
      goal.id = id;

      // 更新UI
      setState(() {
        goals.insert(0, goal); // 插入到列表开头
        currentGoal = goal; // 选中新创建的目标
      });

      // 如果是子目标,通知父页面刷新
      if (widget.parentGoal != null && widget.onGoalTreeChanged != null) {
        widget.onGoalTreeChanged!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加目标失败: $e')),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除条目失败: $e')),
      );
    }
  }

  // 修改现有的处理方法,使用新的统一方法
  Future<void> _handleDeleteGoalFromTree(Goal goal) async {
    await _deleteGoal(goal);
  }

  Future<void> _handleUpdateGoalStatusFromTree(
      Goal goal, GoalStatus newStatus) async {
    goal.status = newStatus;
    await _updateGoal(goal);
  }

  @override
  Widget build(BuildContext context) {
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
          // 只在全屏视图下显示更多按钮
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
                // 显示分享对话框
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
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // 背景圖片（只在全屏视图下显示）
          if (currentView == 0)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/default.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          // 其他视图使用纯白色背景
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
                // 全屏視圖（帶遮罩）
                Stack(
                  children: [
                    // 遮罩
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),
                    _buildFullScreenView(),
                  ],
                ),
                // 其視圖（無遮罩
                _buildTimelineView(),
                _buildGridView(),
              ],
            ),
        ],
      ),
    );
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
    _titleController.text = currentGoal!.title;
    setState(() {
      _isEditingTitle = true;
    });
  }

  // 保存标题
  void _saveTitleEdit() {
    if (_titleController.text.isNotEmpty) {
      final updatedGoal = currentGoal!.copyWith(
        title: _titleController.text,
      );
      _updateGoal(updatedGoal);
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
                                  _deleteGoal(currentGoal!);
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
                          _deleteGoal(goal);
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

                        // 添加新条目
                        _addNewGoal(newGoal);
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

    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: GoalTreeView(
            goals: allGoals,
            onSearchTap: () {
              showSearch(
                context: context,
                delegate: GoalSearchDelegate(goals),
              );
            },
            onSyncTap: _handleSyncTap,
            membershipStatus: _membershipStatus,
            onDeleteGoal: _handleDeleteGoalFromTree,
            onUpdateGoalStatus: _handleUpdateGoalStatusFromTree,
            onGoalSelect: (goal) {
              Navigator.pop(context); // 关闭抽屉
              setState(() {
                currentGoal = goal;
                currentView = 0; // 切换到全屏视图
              });
            },
            onSettingsTap: () {
              // 导航到设置页面
              Navigator.pop(context); // 先关闭抽屉
              _navigateToSettings(context);
            },
            onLoginTap: () {
              // 导航到登录页面，不显示对话框直接跳转
              Navigator.pop(context); // 先关闭抽屉
              // 直接跳转到登录页面
              Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ).then((result) async {
                if (result == true) {
                  // 登录成功，更新登录状态
                  await _checkLoginStatus();
                }
              });
            },
            isLoggedIn: authService.isLoggedIn,
            userAvatar: authService.avatarUrl,
            onLogout: _handleLogout,
            onExploreTab: _navigateToExplore, // 添加探索页面导航回调
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
    if (goal.targetDate != null) {
      // 有截止日期，则清除
      await _updateGoalDate(goal, null);
    } else {
      // 无截止日期，则设置
      final now = DateTime.now();
      await _updateGoalDate(goal, now.add(Duration(days: 30)));
    }
  }

  // 更新目标描述
  Future<void> _updateGoalDescription(Goal goal, String newDescription) async {
    try {
      final updatedGoal = goal.copyWith(
        description: newDescription,
      );
      await _updateGoal(updatedGoal);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新描述失败: $e')),
      );
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    await _showImagePicker();
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
      await _updateGoal(updatedGoal);
    }
  }

  // 更新目标日期
  Future<bool> _updateGoalDate(Goal goal, DateTime? newDate) async {
    try {
      final updatedGoal = goal.copyWith(targetDate: newDate);
      await _updateGoal(updatedGoal);
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
  void _showCustomCountdownDialog() async {
    if (currentGoal == null) return;

    // 当前倒计时天数，默认30天
    final int initialDays = currentGoal!.customCountdownDays ?? 30;

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置倒计时天数'),
        content: StatefulBuilder(
          builder: (context, setState) {
            int selectedDays = initialDays;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择倒计时天数: $selectedDays'),
                Slider(
                  min: 1,
                  max: 365,
                  divisions: 364,
                  value: selectedDays.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      selectedDays = value.round();
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 关闭自定义倒计时
              Navigator.pop(context, null);
            },
            child: Text('关闭倒计时'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, initialDays),
            child: Text('确定'),
          ),
        ],
      ),
    );

    // 更新自定义倒计时
    if (result == null) {
      // 关闭倒计时
      final updatedGoal = currentGoal!.copyWith(
        hasCustomCountdown: false,
        customCountdownDays: null,
      );
      await _updateGoal(updatedGoal);
    } else {
      // 设置新的倒计时
      final updatedGoal = currentGoal!.copyWith(
        hasCustomCountdown: true,
        customCountdownDays: result,
      );
      await _updateGoal(updatedGoal);
    }
  }

  // 为特定目标设置自定义倒计时
  Future<void> _setCustomCountdownForGoal(Goal goal, int? days) async {
    if (days == null) {
      // 关闭倒计时
      final updatedGoal = goal.copyWith(
        hasCustomCountdown: false,
        customCountdownDays: null,
      );
      await _updateGoal(updatedGoal);
    } else {
      // 设置新的倒计时
      final updatedGoal = goal.copyWith(
        hasCustomCountdown: true,
        customCountdownDays: days,
      );
      await _updateGoal(updatedGoal);
    }
  }

  // 辅助方法，用于解决类型不匹配问题
  void _addNewGoalWrapper() {
    _showAddGoalDialog();
  }
}
