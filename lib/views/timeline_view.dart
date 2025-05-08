import 'package:flutter/material.dart';
import 'package:linzaivision_primary/models/goal.dart';
import 'package:linzaivision_primary/widgets/common/goal_card.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:path/path.dart';

class TimelineView extends StatefulWidget {
  final List<Goal> goals;
  final Function(Goal) onGoalSelect;
  final Function(Goal, bool)? onStatusChange;
  final VoidCallback onAddGoal;
  final Function(String title, String description, String? imagePath,
      DateTime? targetDate)? onSaveNewGoal;
  final Future<bool> Function(Goal, DateTime?)? onUpdateGoalDate;

  const TimelineView({
    super.key,
    required this.goals,
    required this.onGoalSelect,
    required this.onAddGoal,
    this.onStatusChange,
    this.onSaveNewGoal,
    this.onUpdateGoalDate,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? selectedImagePath;
  DateTime? selectedGoalDate;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedGoals = List<Goal>.from(widget.goals)
      ..sort((a, b) => (a.targetDate ?? a.createdTime)
          .compareTo(b.targetDate ?? b.createdTime));

    // 添加调试输出，了解子目标页中widget.goals的状态
    print('TimelineView.build - Goals count: ${widget.goals.length}');
    if (widget.goals.isNotEmpty) {
      print('First goal title: ${widget.goals.first.title}');
    }

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        children: [
          if (sortedGoals.isNotEmpty) ..._buildTimelineItems(sortedGoals),

          // 始终添加新目标项，无论是否有现有目标
          _buildAddGoalItem(),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineItems(List<Goal> sortedGoals) {
    final items = <Widget>[];
    DateTime? lastYear;

    for (int i = 0; i < sortedGoals.length; i++) {
      final goal = sortedGoals[i];
      final goalDate = goal.targetDate ?? goal.createdTime;
      final currentYear = DateTime(goalDate.year);

      // 移除年份分隔标题显示
      if (lastYear == null || currentYear != lastYear) {
        // 不再添加额外空间，确保时间线连续
        lastYear = currentYear;
      }

      // 移除顶部padding，确保时间线连续
      items.add(_buildTimelineItem(goal));
    }

    return items;
  }

  Widget _buildTimelineItem(Goal goal) {
    final monthFormat = DateFormat('MMM', 'en_US');
    final dayFormat = DateFormat('dd');
    final yearFormat = DateFormat('yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧时间轴 - 添加点击功能
        GestureDetector(
          onTap: () => _showDatePicker(this.context, goal),
          child: SizedBox(
            width: 64,
            child: goal.targetDate == null
                // 如果没有设置目标日期，显示日历图标
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.0),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.event,
                              size: 24,
                              color: Color(0xD6464242),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Text(
                        //   '待设定',
                        //   style: TextStyle(
                        //     color: Colors.grey,
                        //     fontSize: 12,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                      ],
                    ),
                  )
                // 如果有设置目标日期，显示日期
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        yearFormat.format(goal.targetDate!),
                        style: const TextStyle(
                          color: Color(0xD6464242),
                          fontSize: 16,
                          fontFamily: 'Abhaya Libre ExtraBold',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        monthFormat.format(goal.targetDate!),
                        style: const TextStyle(
                          color: Color(0xD6464242),
                          fontSize: 16,
                          fontFamily: 'Abhaya Libre ExtraBold',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        dayFormat.format(goal.targetDate!),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontFamily: 'Abhaya Libre ExtraBold',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        // 中间的时间线
        SizedBox(
          width: 24,
          child: Column(
            children: [
              // 无顶部间隔的连接线
              Container(
                width: 1,
                height: 42,
                color: Colors.black,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  // 白色背景形成圆点周围8px的间距
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 中间的黑色小圆点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
              // 使用SizedBox而非Container设置高度能更好地适应可变高度
              SizedBox(
                width: 1,
                height: 132, // 使用固定值，但足够容纳大多数卡片
                child: Container(color: Colors.black),
              ),
            ],
          ),
        ),
        // 右侧卡片
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 24, bottom: 12),
            child: GoalCard(
              goal: goal,
              onTap: () => widget.onGoalSelect(goal),
              onStatusChange: widget.onStatusChange != null
                  ? (value) => widget.onStatusChange!(goal, value)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddGoalItem() {
    // 添加调试输出
    print('TimelineView._buildAddGoalItem called');

    // 创建一个Key来测量卡片高度
    final GlobalKey cardKey = GlobalKey();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧时间轴改为日历图标，添加点击功能
        GestureDetector(
          onTap: () => _showDatePickerForNewGoal(this.context),
          child: Container(
            width: 64,
            padding: const EdgeInsets.only(top: 8), // 调整上方对齐卡片
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    // 添加轻微阴影
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.event,
                      size: 24,
                      color: Color(0xD6464242),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 中间的时间线 - 调整上下对齐
        Container(
          width: 24,
          child: Column(
            children: [
              // 上方的连接线 - 更短以对齐卡片上方
              Container(
                width: 1,
                height: 8, // 减少高度使顶部对齐卡片
                color: Colors.black,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  // 白色背景形成圆点周围8px的间距
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 中间的黑色小圆点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
              // 下方连接线 - 使用占位而非固定高度
              Container(
                width: 1,
                color: Colors.black,
                // 最小高度确保视觉连续性，但允许自适应更长内容
                constraints: BoxConstraints(
                  minHeight: 100,
                ),
              ),
            ],
          ),
        ),

        // 右侧添加卡片，使用GlobalKey来测量高度
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 24, bottom: 24),
            child: Container(
              key: cardKey,
              child: _buildAddCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddCard() {
    print('_buildAddCard 被调用');
    // 使用真正的状态管理而不是StatefulBuilder，并传递日期数据
    return _AddCardWidget(
      titleController: titleController,
      descriptionController: descriptionController,
      selectedImagePath: selectedImagePath,
      selectedDate: selectedGoalDate, // 传递选择的日期
      onImageSelected: (path) {
        setState(() {
          selectedImagePath = path;
        });
      },
      onSaveGoal: (title, description) {
        if (widget.onSaveNewGoal != null) {
          // 同时保存选定的日期，实现完整的数据流
          widget.onSaveNewGoal!(
            title,
            description,
            selectedImagePath ?? 'assets/images/default/default.jpg',
            selectedGoalDate, // 传递选定的日期
          );

          // 清空输入
          titleController.clear();
          descriptionController.clear();
          setState(() {
            selectedImagePath = null;
            selectedGoalDate = null; // 清空日期选择
          });
        } else {
          widget.onAddGoal();
        }
      },
    );
  }

  // 为已有目标显示日期选择器
  Future<void> _showDatePicker(BuildContext context, Goal goal) async {
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
      if (widget.onUpdateGoalDate != null) {
        try {
          // 在UI上临时更新目标日期，这样即使回调延迟也能立即看到变化
          goal.targetDate = newDate;

          // 刷新UI立即显示变化
          setState(() {});

          // 调用父组件回调进行持久化存储
          final success = await widget.onUpdateGoalDate!(goal, newDate);

          // 显示日期修改成功消息，并明确显示选择的日期
          final formattedDate = _formatDateChinese(newDate);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? '目标"${goal.title}"的日期已更新为$formattedDate'
                  : '目标"${goal.title}"的日期更新失败，请重试'),
              backgroundColor: success ? null : Colors.amber,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(8),
            ),
          );
        } catch (e) {
          // 处理可能的错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新日期出错：$e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // 如果返回null，说明用户可能点击了清除日期按钮
      if (widget.onUpdateGoalDate != null) {
        try {
          // 在UI上临时更新目标日期
          goal.targetDate = null;

          // 刷新UI立即显示变化
          setState(() {});

          // 调用回调进行持久化
          final success = await widget.onUpdateGoalDate!(goal, null);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? '"${goal.title}"的截止日期已清除'
                  : '"${goal.title}"的截止日期清除失败'),
              backgroundColor: success ? null : Colors.amber,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(8),
            ),
          );
        } catch (e) {
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
  }

  // 为新目标显示日期选择器
  Future<void> _showDatePickerForNewGoal(BuildContext context) async {
    // 我们需要使用StatefulBuilder来实时更新日期选择
    final DateTime initialDate = selectedGoalDate ?? DateTime.now();

    DateTime? selectedDate = await showDialog<DateTime>(
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

    if (selectedDate != null) {
      // 更新选择的日期
      setState(() {
        selectedGoalDate = selectedDate;

        // 显示日期选择成功消息，并明确显示选择的日期
        final formattedDate = _formatDateChinese(selectedDate);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('目标日期已设为$formattedDate'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
          ),
        );
      });
    }
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

  // 构建日期选择按钮
  Widget _buildDateOptionButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black.withOpacity(0.8),
            fontFamily: 'STZhongsong',
          ),
        ),
      ),
    );
  }

  // 更新目标日期
  void _updateGoalDate(Goal goal, DateTime? date) {
    // 这里假设 Goal 类有更新日期的方法或者可以直接修改属性
    // 由于没有看到完整的 Goal 类，所以这里只是一个示例
    // 实际上应该调用父组件传入的回调函数来更新 Goal
    setState(() {
      // 假设这里有一个回调函数可以更新目标日期
      // 例如：widget.onUpdateGoalDate(goal, date);
    });
  }
}

// 添加一个自定义的年份选择器
class _YearPicker extends StatefulWidget {
  final DateTime initialDate;

  const _YearPicker({
    required this.initialDate,
  });

  @override
  _YearPickerState createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  late int _selectedYear;
  final int _startYear = 2000;
  final int _endYear = 2100;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '选择年份',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.9),
                fontFamily: 'STZhongsong',
              ),
            ),
            const SizedBox(height: 20),

            // 年份列表
            Expanded(
              child: ListView.builder(
                itemCount: _endYear - _startYear + 1,
                itemBuilder: (context, index) {
                  final year = _startYear + index;
                  final isSelected = year == _selectedYear;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedYear = year;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          year.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.blue : Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 底部按钮
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      DateTime(_selectedYear, 1, 1),
                    );
                  },
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 添加一个专门的可编辑卡片组件，用于更好地管理状态
class _AddCardWidget extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String? selectedImagePath;
  final DateTime? selectedDate; // 添加日期字段
  final Function(String) onImageSelected;
  final Function(String, String) onSaveGoal;

  const _AddCardWidget({
    required this.titleController,
    required this.descriptionController,
    required this.selectedImagePath,
    this.selectedDate, // 日期可为空
    required this.onImageSelected,
    required this.onSaveGoal,
  });

  @override
  _AddCardWidgetState createState() => _AddCardWidgetState();
}

class _AddCardWidgetState extends State<_AddCardWidget> {
  bool isTitleEditing = false;
  bool isDescriptionEditing = false;

  // 格式化日期显示
  String _formatDate(DateTime date) {
    // 只显示年份
    if (date.month == 1 && date.day == 1) {
      return '${date.year}';
    }
    // 显示年月
    else if (date.day == 1) {
      return '${date.year}/${date.month}';
    }
    // 显示完整日期
    else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContent = widget.titleController.text.isNotEmpty ||
        widget.descriptionController.text.isNotEmpty;

    return Stack(
      children: [
        Container(
          // 移除固定高度，使卡片自适应内容
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            // 如果选择了背景图片，显示背景
            image: widget.selectedImagePath != null
                ? DecorationImage(
                    image: AssetImage(widget.selectedImagePath!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.2),
                      BlendMode.darken,
                    ),
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题部分 - 失焦自动保存
              Row(
                children: [
                  Expanded(
                    child: isTitleEditing
                        // 标题编辑状态
                        ? TextField(
                            controller: widget.titleController,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 20,
                              color: widget.selectedImagePath != null
                                  ? Colors.white
                                  : Colors.black,
                              fontFamily: 'STZhongsong',
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: '新建目标',
                              hintStyle: TextStyle(
                                color: widget.selectedImagePath != null
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.black.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onEditingComplete: () {
                              setState(() {
                                isTitleEditing = false;
                              });
                            },
                            onTapOutside: (_) {
                              setState(() {
                                isTitleEditing = false;
                              });
                            },
                          )
                        // 标题非编辑状态
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                isTitleEditing = true;
                              });
                            },
                            child: Text(
                              widget.titleController.text.isEmpty
                                  ? '新建目标'
                                  : widget.titleController.text,
                              style: TextStyle(
                                fontSize: 20,
                                color: widget.selectedImagePath != null
                                    ? Colors.white
                                    : Colors.black,
                                fontFamily: 'STZhongsong',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                  // 显示已选择的日期
                  if (widget.selectedDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.selectedImagePath != null
                            ? Colors.white.withOpacity(0.3)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDate(widget.selectedDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.selectedImagePath != null
                              ? Colors.white
                              : Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              // 描述部分 - 失焦自动保存
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isDescriptionEditing = true;
                    });
                  },
                  child: isDescriptionEditing
                      // 描述编辑状态
                      ? TextField(
                          controller: widget.descriptionController,
                          autofocus: true,
                          maxLines: 2, // 减少最大行数
                          minLines: 1, // 设置最小行数为1
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.3, // 添加行高调整
                            color: widget.selectedImagePath != null
                                ? Colors.white
                                : Colors.black,
                            fontFamily: 'STZhongsong',
                            fontWeight: FontWeight.normal,
                          ),
                          decoration: InputDecoration(
                            hintText: '输入目标描述',
                            hintStyle: TextStyle(
                              color: widget.selectedImagePath != null
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true, // 使文本框更紧凑
                          ),
                          onEditingComplete: () {
                            setState(() {
                              isDescriptionEditing = false;
                            });
                          },
                          onTapOutside: (_) {
                            setState(() {
                              isDescriptionEditing = false;
                            });
                          },
                        )
                      // 描述非编辑状态
                      : Text(
                          widget.descriptionController.text.isEmpty
                              ? '输入目标描述'
                              : widget.descriptionController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.selectedImagePath != null
                                ? Colors.white.withOpacity(0.7)
                                : widget.descriptionController.text.isEmpty
                                    ? Colors.black.withOpacity(0.56)
                                    : Colors.black,
                            fontFamily: 'STZhongsong',
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                ),
              ),

              // 底部区域 - 仅保留背景选择按钮
              Padding(
                padding: const EdgeInsets.only(top: 8), // 减少顶部间距
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 背景选择按钮
                    IconButton(
                      icon: Icon(
                        Icons.palette,
                        color: widget.selectedImagePath != null
                            ? Colors.white
                            : const Color.fromRGBO(166, 166, 166, 1),
                      ),
                      padding: EdgeInsets.zero, // 减少内边距
                      constraints: BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        // 显示图片选择器
                        _showSimpleImagePicker(context);
                      },
                      tooltip: '选择背景图片',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 右上角添加保存按钮 - 只有当有内容时才显示
        if (hasContent)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.save, color: Colors.white, size: 20),
                onPressed: () {
                  if (widget.titleController.text.trim().isEmpty) {
                    // 显示错误提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('标题不能为空')),
                    );
                    return;
                  }

                  widget.onSaveGoal(
                    widget.titleController.text.trim(),
                    widget.descriptionController.text.trim(),
                  );

                  setState(() {
                    isTitleEditing = false;
                    isDescriptionEditing = false;
                  });
                },
                tooltip: '保存愿望',
              ),
            ),
          ),
      ],
    );
  }

  // 简单的图片选择器
  void _showSimpleImagePicker(BuildContext context) async {
    // 用户提供的截图显示这是一个8张图片的网格
    final defaultImages = [
      'assets/images/default/default.jpg',
      'assets/images/default/default2.jpg',
      'assets/images/default/default3.jpg',
      'assets/images/default/default4.png',
      'assets/images/default/default5.png',
      'assets/images/default/default6.png',
      'assets/images/default/default7.png',
      'assets/images/default/default8.png',
    ];

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                      '选择愿望配图',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.9),
                        fontFamily: 'STZhongsong',
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
              // 内容区域 - 网格展示预置图片
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: defaultImages.length,
                    itemBuilder: (context, index) {
                      final imagePath = defaultImages[index];

                      return GestureDetector(
                        onTap: () {
                          widget.onImageSelected(imagePath);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 底部按钮 - 从本地相册选择
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // 无法直接访问原有方法，此处保留按钮但不实现功能
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: const Text(
                    '从相册选择',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'STZhongsong',
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
}
