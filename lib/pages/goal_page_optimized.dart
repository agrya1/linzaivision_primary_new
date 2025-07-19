// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/goal.dart';
// import '../bloc/goal/goal_bloc.dart';
// import '../views/full_screen_view.dart';
// import '../views/grid_view.dart';
// import '../views/timeline_view.dart';
// import '../views/goal_tree_view.dart';
// import '../views/explore_view.dart';
// import '../widgets/status/goal_status_widget.dart';
// import '../widgets/menus/goal_menus.dart';
// import '../pages/settings_page.dart';
// import '../pages/auth/login_page.dart';
// import '../pages/membership/membership_page.dart';
// import '../widgets/common/share_dialog.dart';
// import '../services/auth_service.dart';
// import '../widgets/pickers/image_picker_dialog.dart';
// import '../widgets/pickers/membership_prompt_dialog.dart';
// import '../utils/error_handler.dart';
// import '../utils/performance_utils.dart';
// import 'dart:io';

// /// 优化后的主页面
// class GoalPageOptimized extends StatefulWidget {
//   final Goal? parentGoal;
//   final VoidCallback? onGoalTreeChanged;

//   const GoalPageOptimized({
//     super.key,
//     this.parentGoal,
//     this.onGoalTreeChanged,
//   });

//   @override
//   GoalPageOptimizedState createState() => GoalPageOptimizedState();
// }

// class GoalPageOptimizedState extends State<GoalPageOptimized> {
//   int currentView = 0; // 视图模式：0 - 全屏视图，1 - 时间轴视图，2 - 网格视图
//   Goal? currentGoal;

//   // 编辑状态控制
//   bool _isEditingTitle = false;
//   final TextEditingController _titleController = TextEditingController();

//   /// 用户会员状态（模拟数据，实际应该从用户系统获取）
//   int _membershipStatus = 0;

//   // 添加倒计时显示状态变量:
//   bool _showCountdown = false; // 默认不显示倒计时
//   // 添加时间显示状态变量:
//   bool _showTime = true; // 默认显示时间
//   // 添加描述显示状态变量:
//   bool _showDescription = true; // 默认显示描述

//   // 添加标题显示状态变量
//   bool _showTitle = true;

//   @override
//   void initState() {
//     super.initState();
//     // 如果是子目标页面，强制显示时间轴视图
//     if (widget.parentGoal != null) {
//       currentView = 1;
//       print('初始化子目标页面: 父目标=${widget.parentGoal!.title}');
//     } else {
//       print('初始化主页面');
//     }

//     // 立即检查用户登录状态
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkLoginStatus();
//     });

//     // 加载数据
//     _loadGoals();

//     // 确保在第一帧渲染后子目标页面始终显示时间轴视图
//     if (widget.parentGoal != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted && currentView != 1) {
//           print('确保子目标页面显示时间轴视图');
//           setState(() {
//             currentView = 1;
//           });
//         }
//       });
//     }
//   }

//   /// 检查用户登录状态
//   Future<void> _checkLoginStatus() async {
//     final authService = Provider.of<AuthService>(context, listen: false);
//     if (authService.isLoggedIn) {
//       // 根据实际会员级别设置状态
//       final prefs = await SharedPreferences.getInstance();
//       // 获取会员级别，如未找到默认为普通用户（级别1）
//       final memberLevel = prefs.getInt('member_level') ?? 1;

//       setState(() {
//         _membershipStatus = memberLevel;
//         print('用户已登录，会员状态: $_membershipStatus'); // 添加日志
//       });
//     } else {
//       setState(() {
//         _membershipStatus = 0; // 未登录状态
//         print('用户未登录，会员状态: 0'); // 添加日志
//       });
//     }
//   }

//   // 加载目标数据
//   Future<void> _loadGoals() async {
//     try {
//       // 使用BLoC加载数据
//       context.read<GoalBloc>().add(LoadGoals(parentId: widget.parentGoal?.id));
//     } catch (e) {
//       ErrorHandler.showErrorSnackBar(context, '加载数据失败: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: BlocConsumer<GoalBloc, GoalState>(
//         listener: (context, state) {
//           if (state is GoalError) {
//             ErrorHandler.showErrorSnackBar(context, state.message);
//           }
//         },
//         builder: (context, state) {
//           if (state is GoalLoading) {
//             return const Center(
//               child: CircularProgressIndicator(
//                 color: Colors.white,
//               ),
//             );
//           }

//           if (state is GoalsLoaded) {
//             final goals = state.goals;
//             final allGoals = state.allGoals;
//             currentGoal = state.currentGoal;

//             return _buildMainContent(goals, allGoals);
//           }

//           return const Center(
//             child: Text(
//               '加载失败，请重试',
//               style: TextStyle(color: Colors.white),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildMainContent(List<Goal> goals, List<Goal> allGoals) {
//     return Stack(
//       children: [
//         // 主内容区域
//         _buildMainContentArea(goals, allGoals),
        
//         // 顶部状态栏
//         _buildTopStatusBar(),
        
//         // 底部菜单栏
//         _buildBottomMenuBar(),
//       ],
//     );
//   }

//   Widget _buildMainContentArea(List<Goal> goals, List<Goal> allGoals) {
//     return Container(
//       margin: const EdgeInsets.only(top: 60, bottom: 80),
//       child: _buildCurrentView(goals, allGoals),
//     );
//   }

//   Widget _buildCurrentView(List<Goal> goals, List<Goal> allGoals) {
//     switch (currentView) {
//       case 0:
//         return FullScreenView(
//           goals: goals,
//           currentGoal: currentGoal,
//           onGoalChanged: (goal) {
//             setState(() {
//               currentGoal = goal;
//             });
//           },
//         );
//       case 1:
//         return TimelineView(
//           goals: goals,
//           currentGoal: currentGoal,
//           onGoalChanged: (goal) {
//             setState(() {
//               currentGoal = goal;
//             });
//           },
//         );
//       case 2:
//         return GridView(
//           goals: goals,
//           currentGoal: currentGoal,
//           onGoalChanged: (goal) {
//             setState(() {
//               currentGoal = goal;
//             });
//           },
//         );
//       case 3:
//         return GoalTreeView(
//           allGoals: allGoals,
//           currentGoal: currentGoal,
//           onGoalChanged: (goal) {
//             setState(() {
//               currentGoal = goal;
//             });
//           },
//         );
//       case 4:
//         return ExploreView(
//           onCardUsed: (card) {
//             // 处理探索卡片使用逻辑
//             _handleExploreCardUsed(card);
//           },
//         );
//       default:
//         return const Center(
//           child: Text(
//             '未知视图模式',
//             style: TextStyle(color: Colors.white),
//           ),
//         );
//     }
//   }

//   Widget _buildTopStatusBar() {
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         height: 60,
//         color: Colors.black.withOpacity(0.8),
//         child: Row(
//           children: [
//             // 返回按钮（仅在子目标页面显示）
//             if (widget.parentGoal != null)
//               IconButton(
//                 icon: const Icon(Icons.arrow_back, color: Colors.white),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
            
//             // 标题
//             Expanded(
//               child: _isEditingTitle
//                   ? TextField(
//                       controller: _titleController,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         hintText: '输入标题',
//                         hintStyle: TextStyle(color: Colors.grey),
//                       ),
//                       onSubmitted: (value) {
//                         setState(() {
//                           _isEditingTitle = false;
//                         });
//                         // 更新目标标题
//                         if (currentGoal != null && value.isNotEmpty) {
//                           _updateGoalTitle(currentGoal!, value);
//                         }
//                       },
//                     )
//                   : Text(
//                       widget.parentGoal?.title ?? '临在意识',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//             ),
            
//             // 设置按钮
//             IconButton(
//               icon: const Icon(Icons.settings, color: Colors.white),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const SettingsPage(),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBottomMenuBar() {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         height: 80,
//         color: Colors.black.withOpacity(0.8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildMenuButton(
//               icon: Icons.view_agenda,
//               label: '全屏',
//               isSelected: currentView == 0,
//               onTap: () => _changeView(0),
//             ),
//             _buildMenuButton(
//               icon: Icons.timeline,
//               label: '时间轴',
//               isSelected: currentView == 1,
//               onTap: () => _changeView(1),
//             ),
//             _buildMenuButton(
//               icon: Icons.grid_view,
//               label: '网格',
//               isSelected: currentView == 2,
//               onTap: () => _changeView(2),
//             ),
//             _buildMenuButton(
//               icon: Icons.account_tree,
//               label: '树视图',
//               isSelected: currentView == 3,
//               onTap: () => _changeView(3),
//             ),
//             _buildMenuButton(
//               icon: Icons.explore,
//               label: '探索',
//               isSelected: currentView == 4,
//               onTap: () => _changeView(4),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMenuButton({
//     required IconData icon,
//     required String label,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             icon,
//             color: isSelected ? Colors.blue : Colors.white,
//             size: 24,
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               color: isSelected ? Colors.blue : Colors.white,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _changeView(int viewIndex) {
//     setState(() {
//       currentView = viewIndex;
//     });
//   }

//   void _updateGoalTitle(Goal goal, String newTitle) {
//     try {
//       final updatedGoal = goal.copyWith(title: newTitle);
//       context.read<GoalBloc>().add(UpdateGoal(updatedGoal));
//       ErrorHandler.showSuccessSnackBar(context, '标题更新成功');
//     } catch (e) {
//       ErrorHandler.showErrorSnackBar(context, '更新标题失败: $e');
//     }
//   }

//   void _handleExploreCardUsed(dynamic card) {
//     // 处理探索卡片使用逻辑
//     print('使用探索卡片: $card');
//     // TODO: 实现探索卡片使用逻辑
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     super.dispose();
//   }
// } 