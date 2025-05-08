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

      setState(() {
        // 如果是根页面(不是子目标页面)且数据库中没有数据，使用示例数据
        if (loadedGoals.isEmpty && widget.parentGoal == null) {
          goals = [
            Goal(
              title: '开启21天显化之旅',
              description: '描述你的心愿',
              imagePath: 'assets/images/default/default.jpg',
              createdTime: DateTime.now(),
              parentId: null, // 明确设置为根目标
            ),
            Goal(
              title: '愿景二',
              description: '描述你的心愿',
              imagePath: 'assets/images/default/default2.jpg',
              createdTime:
                  DateTime.now().add(const Duration(seconds: 1)), // 确保创建时间不同
              parentId: null, // 明确设置为根目标
            ),
          ];
          // 保存示例数据到数据库
          _saveInitialGoals();
        } else {
          goals = loadedGoals;
        }

        if (goals.isNotEmpty && currentGoal == null) {
          currentGoal = goals[0]; // 默认选择第一个目标(最新创建的)
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
        _isLoading = false;
      });
    }
  }

  // 保存示例数据到数据库
  Future<void> _saveInitialGoals() async {
    for (var goal in goals) {
      final id = await _dbHelper.insertGoal(goal);
      goal.id = id; // 保存数据库生成的ID
    }
  }

  /// 刷新目标树
  Future<void> _refreshGoalTree() async {
    try {
      // 始终加载全量目标树
      allGoals = await _dbHelper.getGoalTree();
      if (widget.parentGoal == null) {
        // 根页面goals为全量树
        setState(() {
          goals = allGoals;
          if (goals.isNotEmpty && currentGoal == null) {
            currentGoal = goals[0];
          }
        });
      } else {
        // 子页面goals为当前父目标下的子目标
        final subGoals =
            await _dbHelper.getGoals(parentId: widget.parentGoal!.id);
        setState(() {
          goals = subGoals;
          if (goals.isNotEmpty && currentGoal == null) {
            currentGoal = goals[0];
          }
        });
      }
    } catch (e) {
      print('_refreshGoalTree出错: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新数据失败: $e')),
      );
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
        SnackBar(content: Text('删除目标失败: $e')),
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
                    fontFamily: 'Songti',
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
          if (currentView == 0)
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
    if (goals.isEmpty) {
      return FullScreenView(
        currentGoal: null,
        goals: goals,
        isEditingTitle: _isEditingTitle,
        titleController: _titleController,
        onTitleEdit: _startTitleEdit,
        onTitleSave: _saveTitle,
        onDescriptionEdit: _showDescriptionDialog,
        onImagePick: _showImagePicker,
        onAddGoal: _showAddGoalDialog,
        onGoalSelect: (goal) {
          setState(() {
            currentGoal = goal;
          });
        },
        onSaveDescription: (goal, description) async {
          try {
            // 创建一个更新了描述的新目标对象
            final updatedGoal = goal.copyWith(description: description);

            // 更新到数据库并刷新UI
            await _updateGoal(updatedGoal);

            // 显示保存成功消息
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('目标描述已更新'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            print('更新目标描述失败: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('更新目标描述失败: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        showTime: _showTime,
        showDescription: _showDescription,
      );
    }

    return Stack(
      children: [
        FullScreenView(
          currentGoal: currentGoal,
          goals: goals,
          isEditingTitle: _isEditingTitle,
          titleController: _titleController,
          onTitleEdit: _startTitleEdit,
          onTitleSave: _saveTitle,
          onDescriptionEdit: _showDescriptionDialog,
          onImagePick: _showImagePicker,
          onAddGoal: _showAddGoalDialog,
          onGoalSelect: (goal) {
            setState(() {
              currentGoal = goal;
            });
          },
          onUpdateDate: (goal, newDate) async {
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
          onSaveDescription: (goal, description) async {
            try {
              // 创建一个更新了描述的新目标对象
              final updatedGoal = goal.copyWith(description: description);

              // 更新到数据库并刷新UI
              await _updateGoal(updatedGoal);

              // 显示保存成功消息
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('目标描述已更新'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              print('更新目标描述失败: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('更新目标描述失败: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          showTime: _showTime,
          showDescription: _showDescription,
        ),
        // 拆解目标按钮
        if (currentGoal != null)
          Positioned(
            top: 438,
            right: 50,
            child: GestureDetector(
              onTap: () async {
                // 先获取子目标列表，确保子目标页面有数据显示
                try {
                  final childGoals =
                      await _dbHelper.getGoals(parentId: currentGoal!.id);
                  print('拆解目标: 获取到${childGoals.length}个子目标');

                  // 导航到子目标页面
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalPage(
                        parentGoal: currentGoal,
                        onGoalTreeChanged: _refreshGoalTree,
                      ),
                    ),
                  );

                  // 返回时刷新父页面数据
                  _refreshGoalTree();
                } catch (e) {
                  print('拆解目标出错: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('获取子目标失败: $e')),
                  );
                }
              },
              child: Container(
                width: 43,
                height: 43,
                child: Stack(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: ShapeDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: const OvalBorder(),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Image.asset(
                          'assets/icons/subgoal.png',
                          width: 24,
                          height: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // 倒计时显示区域 - 居中显示
        if (currentGoal != null)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2, // 垂直方向约在屏幕1/5处
            left: 0,
            right: 0,
            child: Center(
              child: GoalStatusWidget(
                goal: currentGoal!,
                showCountdown: _showCountdown,
              ),
            ),
          ),
      ],
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
  void _saveTitle() {
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
                        '删除目标',
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
                        '删除目标',
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
    DateTime? selectedDate;
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
                            widget.parentGoal != null ? '新建子目标' : '新建目标',
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
                              '目标标题',
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
                              hintText: '输入目标标题',
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
                          '目标描述',
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
                              hintText: '输入目标描述',
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
                            // 日期选择按钮
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // 显示日期选择器
                                  final DateTime now = DateTime.now();
                                  final DateTime? picked =
                                      await _showCustomDatePicker(
                                    context,
                                    selectedDate ?? now,
                                    '选择完成日期',
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedDate = picked;
                                    });
                                  }
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
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedDate == null
                                            ? '选择日期'
                                            : DateFormat('yyyy-MM-dd')
                                                .format(selectedDate!),
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
                            const SizedBox(width: 12),
                            // 图片选择按钮，修改为调用_showImagePickerForNewGoal
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // 显示选择愿望配图弹窗
                                  _showImagePickerForNewGoal(
                                      (selectedImagePath) {
                                    // 使用StatefulBuilder的setState刷新弹窗UI
                                    setDialogState(() {
                                      imagePath = selectedImagePath;
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
                                        imagePath == null ? '选择配图' : '已选择配图',
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
                        final newGoal = Goal(
                          title: titleController.text,
                          description: descriptionController.text,
                          imagePath:
                              imagePath ?? 'assets/images/default/default.jpg',
                          createdTime: DateTime.now(),
                          targetDate: selectedDate,
                          parentId: widget.parentGoal?.id,
                        );

                        // 先关闭弹窗
                        Navigator.pop(context);

                        // 添加新目标
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
                      widget.parentGoal != null ? '创建子目标' : '创建目标',
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
      Function(String) onImageSelected) async {
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
      onImageSelected: (imagePath) async {
        // 更新当前目标的图片
        final updatedGoal = currentGoal!.copyWith(
          imagePath: imagePath,
        );
        await _updateGoal(updatedGoal);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已更新图片')),
        );
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
}
