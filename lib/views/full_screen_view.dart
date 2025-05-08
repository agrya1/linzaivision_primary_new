import 'package:flutter/material.dart';
import 'dart:io';
import '../models/goal.dart';
import 'package:intl/intl.dart';

class FullScreenView extends StatefulWidget {
  final Goal? currentGoal;
  final List<Goal> goals;
  final bool isEditingTitle;
  final TextEditingController titleController;
  final VoidCallback onTitleEdit;
  final VoidCallback onTitleSave;
  final VoidCallback onDescriptionEdit;
  final Function(Goal, String)? onSaveDescription;
  final VoidCallback onImagePick;
  final Function(Goal) onGoalSelect;
  final Function(Goal, bool)? onStatusChange;
  final Future<bool> Function(Goal, DateTime?)? onUpdateDate;
  final VoidCallback onAddGoal;
  final bool showTime;
  final bool showDescription;

  const FullScreenView({
    super.key,
    required this.currentGoal,
    required this.goals,
    required this.isEditingTitle,
    required this.titleController,
    required this.onTitleEdit,
    required this.onTitleSave,
    required this.onDescriptionEdit,
    this.onSaveDescription,
    required this.onImagePick,
    required this.onGoalSelect,
    required this.onAddGoal,
    this.onStatusChange,
    this.onUpdateDate,
    required this.showTime,
    required this.showDescription,
  });

  @override
  State<FullScreenView> createState() => _FullScreenViewState();
}

// 全屏视图状态类
class _FullScreenViewState extends State<FullScreenView>
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

  @override
  void initState() {
    super.initState();

    // 初始化当前索引
    if (widget.currentGoal != null && widget.goals.isNotEmpty) {
      _currentIndex = widget.goals.indexOf(widget.currentGoal!);
      if (_currentIndex < 0) _currentIndex = 0;
    }

    // 初始化页面控制器
    _pageController = PageController(initialPage: _currentIndex);

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 滚动缩略图到选中位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedThumbnail();
    });
  }

  // 组件更新时处理
  @override
  void didUpdateWidget(FullScreenView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果当前目标变化，更新页面控制器
    if (widget.currentGoal != oldWidget.currentGoal &&
        widget.currentGoal != null) {
      final newIndex = widget.goals.indexOf(widget.currentGoal!);
      if (newIndex >= 0 && newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _scrollToSelectedThumbnail();
      }
    }
  }

  // 组件销毁时处理
  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _animationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 滚动缩略图到选中位置
  void _scrollToSelectedThumbnail() {
    if (widget.goals.length <= 6) return; // 如果目标数量少于6个，不需要滚动

    if (_thumbnailScrollController.hasClients) {
      // 计算需要滚动到的位置
      final thumbnailWidth = 49.0; // 41 + 4*2 (宽度+边距)
      final offset = _currentIndex * thumbnailWidth;

      // 滚动到居中位置
      final screenWidth = MediaQuery.of(context).size.width;
      final centerPosition = offset - (screenWidth / 2) + (thumbnailWidth / 2);

      // 确保不滚动到负值或超出范围
      final maxScrollExtent =
          _thumbnailScrollController.position.maxScrollExtent;
      final scrollOffset = centerPosition.clamp(0.0, maxScrollExtent);

      _thumbnailScrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 切换到下一个目标
  void _nextGoal() {
    if (_isAnimating || widget.goals.isEmpty) return;

    if (_currentIndex < widget.goals.length - 1) {
      _animateToPage(_currentIndex + 1);
    }
  }

  // 切换到上一个目标
  void _previousGoal() {
    if (_isAnimating || widget.goals.isEmpty) return;

    if (_currentIndex > 0) {
      _animateToPage(_currentIndex - 1);
    }
  }

  // 动画切换到指定页面
  void _animateToPage(int page) {
    setState(() {
      _isAnimating = true;
    });

    _pageController
        .animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    )
        .then((_) {
      setState(() {
        _isAnimating = false;
      });
    });
  }

  // 处理页面切换
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // 滚动缩略图到选中位置
    _scrollToSelectedThumbnail();

    // 调用回调函数
    if (index >= 0 && index < widget.goals.length) {
      widget.onGoalSelect(widget.goals[index]);
    }
  }

  // 构建组件
  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) {
      return _buildEmptyState(context);
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isEditing = widget.isEditingTitle || _isEditingDescription;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: _buildContent(context),
        ),
        if (!(isKeyboardOpen && isEditing))
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: _buildBottomIndicatorsContentOnly(),
          ),
      ],
    );
  }

  // 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/default/default3.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/default/default.jpg',
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.2),
          ),
        ),
        Center(
          child: Text(
            "在這裏寫下心願，開啓您的願景顯化~",
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3.0,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建内容
  Widget _buildContent(BuildContext context) {
    return Stack(
      children: [
        // 使用PageView替换原来的单一视图，以实现左右滑动
        PageView.builder(
          controller: _pageController,
          itemCount: widget.goals.length,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), // 添加反弹效果
          itemBuilder: (context, index) {
            final goal = widget.goals[index];
            return GestureDetector(
              onTap: widget.onImagePick,
              child: Stack(
                children: [
                  _buildBackgroundImage(goal),
                  _buildOverlay(),
                  _buildCenterContent(goal),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

// 构建背景图片
  Widget _buildBackgroundImage(Goal goal) {
    return Positioned.fill(
      child: Builder(
        builder: (context) {
          try {
            if (goal.imagePath.startsWith('assets/')) {
              return Image.asset(
                goal.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/default/default.jpg',
                    fit: BoxFit.cover,
                  );
                },
              );
            } else {
              return Image.file(
                File(goal.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/default/default.jpg',
                    fit: BoxFit.cover,
                  );
                },
              );
            }
          } catch (e) {
            return Image.asset(
              'assets/images/default/default.jpg',
              fit: BoxFit.cover,
            );
          }
        },
      ),
    );
  }

  // 构建叠加层
  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.2),
      ),
    );
  }

  // 构建中心内容
  Widget _buildCenterContent(Goal goal) {
    // 当前目标变化时更新描述控制器内容
    if (goal.id == widget.currentGoal?.id) {
      _descriptionController.text = goal.description ?? '';
    }

    return Builder(
      builder: (BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
                height:
                    MediaQuery.of(context).size.height * 0.4), // 从顶部开始留30%的空间
            Stack(
              alignment: Alignment.center,
              children: [
                // 标题部分
                if (widget.isEditingTitle && goal.id == widget.currentGoal?.id)
                  _buildTitleEditor(goal)
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(right: 24),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: GestureDetector(
                          onTap: goal.id == widget.currentGoal?.id
                              ? widget.onTitleEdit
                              : null,
                          child: Text(
                            goal.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: 'STZhongsong',
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            maxLines: null,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // 日期部分 - 放在标题Stack外部，确保在标题下方显示
            if (widget.showTime && goal.targetDate != null) ...[
              const SizedBox(height: 14), // 增加与标题的间距
              GestureDetector(
                onTap: goal.id == widget.currentGoal?.id
                    ? () => _showDatePicker(context, goal)
                    : null,
                child: Text(
                  '${DateFormat('yyyy.MM.dd').format(goal.createdTime)} — ${DateFormat('yyyy.MM.dd').format(goal.targetDate!)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    decoration: goal.id == widget.currentGoal?.id
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: Colors.white.withOpacity(0.7),
                    decorationThickness: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 添加描述显示区域
            if (widget.showDescription &&
                goal.id == widget.currentGoal?.id) ...[
              const SizedBox(height: 12),
              _buildDescriptionEditor(goal),
            ],
          ],
        ),
      ),
    );
  }

  // 构建底部指示器
  Widget _buildBottomIndicatorsContentOnly() {
    return Column(
      children: [
        // 目标缩略图行
        SizedBox(
          height: 41,
          child: ListView(
            controller: _thumbnailScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(
                      widget.goals.length,
                      (index) => _buildThumbnailItem(index),
                    ),
                    // 添加按钮
                    GestureDetector(
                      onTap: widget.onAddGoal,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 41,
                        height: 41,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建缩略图项
  Widget _buildThumbnailItem(int index) {
    final goal = widget.goals[index];
    final isSelected = index == _currentIndex;

    return GestureDetector(
      onTap: () {
        // 切换到选中的目标
        _animateToPage(index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 41,
        height: 41,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: _buildGoalThumbnail(goal),
        ),
      ),
    );
  }

  Widget _buildTitleEditor(Goal goal) {
    return Builder(
      builder: (BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            alignment: Alignment.center,
            child: TextField(
              controller: widget.titleController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'STZhongsong',
                fontWeight: FontWeight.w400,
              ),
              maxLines: null,
              textAlign: TextAlign.left,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
              ),
              autofocus: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: widget.onTitleSave,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalThumbnail(Goal goal) {
    return Builder(
      builder: (context) {
        try {
          if (goal.imagePath.startsWith('assets/')) {
            return Image.asset(
              goal.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/default/default.jpg',
                  fit: BoxFit.cover,
                );
              },
            );
          } else {
            return Image.file(
              File(goal.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/default/default.jpg',
                  fit: BoxFit.cover,
                );
              },
            );
          }
        } catch (e) {
          return Image.asset(
            'assets/images/default/default.jpg',
            fit: BoxFit.cover,
          );
        }
      },
    );
  }

  // 构建描述编辑器
  Widget _buildDescriptionEditor(Goal goal) {
    // 确保描述控制器始终有最新内容
    if (_descriptionController.text != goal.description) {
      _descriptionController.text = goal.description ?? '';
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      child: _isEditingDescription
          // 编辑模式
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _descriptionController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '添加描述...',
                      hintStyle: TextStyle(
                        color: Colors.white70,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    autofocus: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: () {
                    if (widget.currentGoal != null &&
                        widget.onSaveDescription != null) {
                      // 使用回调保存描述
                      widget.onSaveDescription!(
                        widget.currentGoal!,
                        _descriptionController.text,
                      );
                      // 退出编辑模式
                      setState(() {
                        _isEditingDescription = false;
                      });
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          // 显示模式 - 居中并移除关闭按钮
          : GestureDetector(
              onTap: () {
                // 点击开始编辑
                setState(() {
                  _isEditingDescription = true;
                });
              },
              child: Text(
                _descriptionController.text.isEmpty
                    ? '点击添加描述...'
                    : _descriptionController.text,
                style: TextStyle(
                  color: _descriptionController.text.isEmpty
                      ? Colors.white70
                      : Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  // 显示日期选择器对话框
  Future<void> _showDatePicker(BuildContext context, Goal goal) async {
    if (widget.onUpdateDate == null) return;

    // 获取当前日期
    final DateTime initialDate = goal.targetDate ?? goal.createdTime;

    DateTime? newDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime tempSelectedDate = initialDate;

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

    if (newDate != null) {
      // 实际更新目标日期
      try {
        // 在UI上临时更新目标日期，这样即使回调延迟也能立即看到变化
        setState(() {
          goal.targetDate = newDate;
        });

        // 调用父组件回调进行持久化存储
        final success = await widget.onUpdateDate!(goal, newDate);

        // 显示日期修改成功消息，并明确显示选择的日期
        final formattedDate = _formatDateChinese(newDate);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '目标"${goal.title}"的日期已更新为$formattedDate'
                : '目标"${goal.title}"的日期更新失败，请重试'),
            backgroundColor: success ? null : Colors.amber,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
          ),
        );
      } catch (e) {
        // 处理可能的错误
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新日期出错：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 如果返回null，说明用户可能点击了清除日期按钮
      try {
        // 在UI上临时更新目标日期
        setState(() {
          goal.targetDate = null;
        });

        // 调用回调进行持久化
        final success = await widget.onUpdateDate!(goal, null);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '"${goal.title}"的截止日期已清除'
                : '"${goal.title}"的截止日期清除失败'),
            backgroundColor: success ? null : Colors.amber,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除日期出错：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 格式化日期为中文显示
  String _formatDateChinese(DateTime date) {
    String year = date.year.toString();
    String month = date.month.toString();
    String day = date.day.toString();
    return "$year年$month月$day日";
  }
}
