/// BLoC化的FullScreenView组件
///
/// 使用BLoC事件通信机制替代复杂的回调链
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../models/goal.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_state.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/component/component_communication_bloc.dart';
import '../bloc/component/component_communication_events.dart';

/// BLoC化的FullScreenView组件
class FullScreenViewBloc extends StatefulWidget {
  final Goal? currentGoal;
  final List<Goal> goals;

  const FullScreenViewBloc({
    super.key,
    required this.currentGoal,
    required this.goals,
  });

  @override
  State<FullScreenViewBloc> createState() => _FullScreenViewBlocState();
}

class _FullScreenViewBlocState extends State<FullScreenViewBloc>
    with SingleTickerProviderStateMixin {
  // 页面控制器
  late PageController _pageController;

  // 当前页面索引
  int _currentIndex = 0;

  // 缩略图滚动控制器
  final ScrollController _thumbnailScrollController = ScrollController();

  // 动画控制器，用于滑动动画
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // 是否正在切换页面
  bool _isAnimating = false;

  // 添加描述显示和编辑状态变量
  bool _isDescriptionVisible = false;
  bool _isEditingDescription = false;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  // 视频播放器控制器
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();

    // 初始化页面控制器
    _pageController = PageController();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 如果有当前目标，设置初始索引
    if (widget.currentGoal != null) {
      final index =
          widget.goals.indexWhere((goal) => goal.id == widget.currentGoal!.id);
      if (index != -1) {
        _currentIndex = index;
        _pageController = PageController(initialPage: index);
      }
    }

    // 初始化描述控制器
    if (widget.currentGoal != null) {
      _descriptionController.text = widget.currentGoal!.description;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _animationController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 监听组件通信状态
        BlocListener<ComponentCommunicationBloc, ComponentCommunicationState>(
          listener: (context, state) {
            if (state is DialogRequested) {
              _handleDialogRequest(context, state);
            } else if (state is MessageRequested) {
              _showMessage(context, state);
            } else if (state is NavigationRequested) {
              _handleNavigation(context, state);
            }
          },
        ),
      ],
      child: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, goalState) {
          // 只在GoalsLoaded状态下显示内容
          if (goalState is! GoalsLoaded) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.black,
            body: _buildBody(context, goalState),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, GoalsLoaded goalState) {
    if (widget.goals.isEmpty) {
      return const Center(
        child: Text(
          '暂无目标',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return Stack(
      children: [
        // 主要内容区域
        _buildMainContent(context, goalState),

        // 顶部工具栏
        _buildTopToolbar(context, goalState),

        // 底部缩略图
        _buildBottomThumbnails(context),

        // 描述编辑区域
        if (_isDescriptionVisible) _buildDescriptionEditor(context, goalState),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, GoalsLoaded goalState) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });

        // 通知GoalBloc选择新目标
        final selectedGoal = widget.goals[index];
        context.read<GoalBloc>().add(SelectGoal(selectedGoal));
      },
      itemCount: widget.goals.length,
      itemBuilder: (context, index) {
        final goal = widget.goals[index];
        return _buildGoalContent(context, goal, goalState);
      },
    );
  }

  Widget _buildGoalContent(
      BuildContext context, Goal goal, GoalsLoaded goalState) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // 背景图片或视频
          _buildMediaBackground(goal),

          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // 目标信息
          _buildGoalInfo(context, goal, goalState),
        ],
      ),
    );
  }

  Widget _buildMediaBackground(Goal goal) {
    if (goal.imagePath.isNotEmpty && File(goal.imagePath).existsSync()) {
      return Image.file(
        File(goal.imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // 默认背景
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.image,
          size: 100,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildGoalInfo(
      BuildContext context, Goal goal, GoalsLoaded goalState) {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          if (goalState.showTitle) _buildTitle(context, goal, goalState),

          const SizedBox(height: 16),

          // 描述
          if (goalState.showDescription) _buildDescription(context, goal),

          const SizedBox(height: 16),

          // 时间信息
          if (goalState.showTime) _buildTimeInfo(context, goal),

          const SizedBox(height: 16),

          // 操作按钮
          _buildActionButtons(context, goal),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context, Goal goal, GoalsLoaded goalState) {
    if (goalState.isEditingTitle && goal.id == goalState.currentGoal?.id) {
      // 同步编辑文本
      if (_titleController.text != (goalState.editingTitleText ?? goal.title)) {
        _titleController.text = goalState.editingTitleText ?? goal.title;
      }

      return TextField(
        controller: _titleController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '输入目标标题',
          hintStyle: TextStyle(color: Colors.white54),
        ),
        autofocus: true,
        onSubmitted: (_) {
          context.read<GoalBloc>().add(SaveTitle(_titleController.text));
        },
      );
    }

    return GestureDetector(
      onTap: () {
        context.read<GoalBloc>().add(StartEditingTitle());
      },
      child: Text(
        goal.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context, Goal goal) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDescriptionVisible = true;
          _descriptionController.text = goal.description;
        });
      },
      child: Text(
        goal.description.isEmpty ? '点击添加描述' : goal.description,
        style: TextStyle(
          color: goal.description.isEmpty ? Colors.white54 : Colors.white,
          fontSize: 16,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context, Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(goal.createdTime)}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        if (goal.targetDate != null)
          Text(
            '目标日期: ${DateFormat('yyyy-MM-dd').format(goal.targetDate!)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Goal goal) {
    return Row(
      children: [
        // 图片选择按钮
        IconButton(
          onPressed: () {
            context
                .read<ComponentCommunicationBloc>()
                .add(ImagePickRequested(goal));
          },
          icon: const Icon(Icons.photo_camera, color: Colors.white),
        ),

        // 视频选择按钮
        IconButton(
          onPressed: () {
            context
                .read<ComponentCommunicationBloc>()
                .add(VideoPickRequested(goal));
          },
          icon: const Icon(Icons.videocam, color: Colors.white),
        ),

        // 日期设置按钮
        IconButton(
          onPressed: () {
            context
                .read<ComponentCommunicationBloc>()
                .add(DeadlineToggleRequested(goal));
          },
          icon: const Icon(Icons.calendar_today, color: Colors.white),
        ),

        // 添加子目标按钮
        IconButton(
          onPressed: () {
            context
                .read<ComponentCommunicationBloc>()
                .add(SubGoalAddRequested(goal));
          },
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildTopToolbar(BuildContext context, GoalsLoaded goalState) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),

          // 显示控制按钮
          Row(
            children: [
              IconButton(
                onPressed: () {
                  context
                      .read<GoalBloc>()
                      .add(ToggleTitleDisplay(!goalState.showTitle));
                },
                icon: Icon(
                  goalState.showTitle ? Icons.title : Icons.title_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  context.read<GoalBloc>().add(
                      ToggleDescriptionDisplay(!goalState.showDescription));
                },
                icon: Icon(
                  goalState.showDescription
                      ? Icons.description
                      : Icons.description_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  context
                      .read<GoalBloc>()
                      .add(ToggleTimeDisplay(!goalState.showTime));
                },
                icon: Icon(
                  goalState.showTime
                      ? Icons.access_time
                      : Icons.access_time_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomThumbnails(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      height: 60,
      child: ListView.builder(
        controller: _thumbnailScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.goals.length,
        itemBuilder: (context, index) {
          final goal = widget.goals[index];
          final isSelected = index == _currentIndex;

          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: goal.imagePath.isNotEmpty &&
                        File(goal.imagePath).existsSync()
                    ? Image.file(
                        File(goal.imagePath),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionEditor(BuildContext context, GoalsLoaded goalState) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '编辑描述',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isDescriptionVisible = false;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 描述输入框
            Expanded(
              child: TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '输入目标描述...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),

            const SizedBox(height: 20),

            // 保存按钮
            ElevatedButton(
              onPressed: () {
                final currentGoal = widget.goals[_currentIndex];
                final updatedGoal = currentGoal.copyWith(
                  description: _descriptionController.text,
                );

                context.read<GoalBloc>().add(UpdateGoal(updatedGoal));

                setState(() {
                  _isDescriptionVisible = false;
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDialogRequest(BuildContext context, DialogRequested state) {
    switch (state.type) {
      case 'image_picker':
        _showImagePicker(context, state.data['goal'] as Goal);
        break;
      case 'video_picker':
        _showVideoPicker(context, state.data['goal'] as Goal);
        break;
      case 'date_picker':
        _showDatePicker(context, state.data['goal'] as Goal);
        break;
    }
  }

  void _showImagePicker(BuildContext context, Goal goal) {
    // 这里应该实现图片选择逻辑
    // 暂时显示一个简单的对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片'),
        content: const Text('图片选择功能待实现'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showVideoPicker(BuildContext context, Goal goal) {
    // 这里应该实现视频选择逻辑
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择视频'),
        content: const Text('视频选择功能待实现'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context, Goal goal) {
    showDatePicker(
      context: context,
      initialDate: goal.targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    ).then((selectedDate) {
      if (selectedDate != null) {
        context.read<ComponentCommunicationBloc>().add(
              GoalDateUpdateRequested(goal, selectedDate),
            );
      }
    });
  }

  void _showMessage(BuildContext context, MessageRequested state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: state.type == 'error' ? Colors.red : Colors.green,
        duration: state.duration ?? const Duration(seconds: 3),
      ),
    );
  }

  void _handleNavigation(BuildContext context, NavigationRequested state) {
    if (state.routeName == 'back') {
      Navigator.pop(context, state.arguments?['result']);
    } else {
      Navigator.pushNamed(context, state.routeName, arguments: state.arguments);
    }
  }
}
