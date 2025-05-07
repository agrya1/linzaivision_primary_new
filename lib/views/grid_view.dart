import 'package:flutter/material.dart';
import 'dart:io';
import '../models/goal.dart';
import 'package:linzaivision_primary/widgets/common/share_dialog.dart';

class GoalGridView extends StatelessWidget {
  final List<Goal> goals;
  final Function(Goal) onGoalSelect;
  final VoidCallback onAddGoal;
  final Function(BuildContext, Goal)? onShowOperationMenu;

  const GoalGridView({
    super.key,
    required this.goals,
    required this.onGoalSelect,
    required this.onAddGoal,
    this.onShowOperationMenu,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const maxWidth = 1200.0;
    final useWidth = screenWidth > maxWidth ? maxWidth : screenWidth;
    const margin = 24.0;
    const gutter = 24.0;
    final availableWidth = useWidth - (margin * 2);
    final crossAxisCount = (availableWidth / 300).floor().clamp(2, 4);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(margin),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: gutter,
            mainAxisSpacing: gutter,
          ),
          itemCount: goals.length + 1,
          itemBuilder: (context, index) {
            if (index == goals.length) {
              return _buildAddCard();
            }
            return _buildGoalCard(context, goals[index]);
          },
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: onAddGoal,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(
            Icons.add_circle_outline,
            size: 48,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Goal goal) {
    return GestureDetector(
      onTap: () => onGoalSelect(goal),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCardImage(goal),
            _buildCardOverlay(),
            _buildCardContent(context, goal),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(Goal goal) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
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

  Widget _buildCardOverlay() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Goal goal) {
    return Stack(
      children: [
        // 居中标题
        Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              goal.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 右下角操作按钮
        Positioned(
          right: 12,
          bottom: 12,
          child: Builder(
            builder: (innerContext) => GestureDetector(
              onTapUp: (TapUpDetails details) {
                if (onShowOperationMenu != null) {
                  final RenderBox overlay = Overlay.of(innerContext)
                      .context
                      .findRenderObject() as RenderBox;
                  final RenderBox button =
                      innerContext.findRenderObject() as RenderBox;
                  final RelativeRect position = RelativeRect.fromRect(
                    Rect.fromPoints(
                      button.localToGlobal(
                        details.localPosition,
                        ancestor: overlay,
                      ),
                      button.localToGlobal(
                        button.size.bottomRight(Offset.zero),
                        ancestor: overlay,
                      ),
                    ),
                    Offset.zero & overlay.size,
                  );
                  showMenu(
                    context: innerContext,
                    position: position,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    items: [
                      PopupMenuItem(
                        child: ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('删除目标'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () {
                            Navigator.pop(innerContext);
                            _showDeleteDialog(innerContext, goal);
                          },
                        ),
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('分享'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () {
                            Navigator.pop(innerContext);
                            showDialog(
                              context: innerContext,
                              builder: (_) => ShareDialog(
                                title: goal.title,
                                backgroundImagePath: goal.imagePath,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 显示删除确认对话框
  void _showDeleteDialog(BuildContext context, Goal goal) {
    if (onShowOperationMenu != null) {
      onShowOperationMenu!(context, goal);
    }
  }
}
