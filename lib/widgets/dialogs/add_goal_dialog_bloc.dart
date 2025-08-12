/// BLoC化的添加目标对话框组件
///
/// 使用BLoC事件通信机制管理对话框状态
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../models/goal.dart';
import '../../bloc/goal/goal_bloc.dart';
import '../../bloc/goal/goal_event.dart';
import '../../bloc/component/component_communication_bloc.dart';
import '../../bloc/component/component_communication_events.dart';
import '../../services/auth_service.dart';
import '../pickers/image_picker_dialog.dart';
import '../pickers/membership_prompt_dialog.dart';

/// BLoC化的添加目标对话框
class AddGoalDialogBloc extends StatefulWidget {
  final Goal? parentGoal;
  final int membershipStatus;

  const AddGoalDialogBloc({
    super.key,
    this.parentGoal,
    required this.membershipStatus,
  });

  @override
  State<AddGoalDialogBloc> createState() => _AddGoalDialogBlocState();
}

class _AddGoalDialogBlocState extends State<AddGoalDialogBloc> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedImagePath;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            _buildHeader(),

            // 内容区域
            _buildContent(),

            // 操作按钮
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                          ? '${widget.parentGoal!.title.substring(0, 12)}...'
                          : widget.parentGoal!.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题输入
          _buildTitleInput(),

          const SizedBox(height: 20),

          // 描述输入
          _buildDescriptionInput(),

          const SizedBox(height: 20),

          // 图片选择
          _buildImageSelection(),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标题',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          autofocus: true,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: '输入目标标题',
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '描述',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: '输入目标描述（可选）',
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '背景图片',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showImagePicker,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.black.withOpacity(0.1),
              ),
              image: _selectedImagePath != null
                  ? DecorationImage(
                      image: AssetImage(_selectedImagePath!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _selectedImagePath == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '选择背景图片',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          // 取消按钮
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '取消',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 创建按钮
          Expanded(
            child: ElevatedButton(
              onPressed: _canCreateGoal() ? _createGoal : null,
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
    );
  }

  bool _canCreateGoal() {
    return _titleController.text.trim().isNotEmpty;
  }

  void _showImagePicker() {
    showDialog(
      context: context,
      builder: (context) => ImagePickerDialog(
        membershipStatus: widget.membershipStatus,
        onImageSelected: (imagePath, {bool isVideo = false}) {
          setState(() {
            _selectedImagePath = imagePath;
          });
          Navigator.pop(context);
        },
        onMembershipPrompt: () {
          Navigator.pop(context);
          MembershipPromptDialog.showImagePrompt(context);
        },
      ),
    );
  }

  void _createGoal() {
    if (!_canCreateGoal()) return;

    // 创建新的目标对象
    final newGoal = Goal(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imagePath: _selectedImagePath ?? 'assets/images/default/default.jpg',
      createdTime: DateTime.now(),
      targetDate: null, // 不设置默认日期
      parentId: widget.parentGoal?.id,
    );

    // 关闭对话框
    Navigator.pop(context);

    // 使用BLoC事件创建目标
    context.read<GoalBloc>().add(AddGoalWithDetails(
          newGoal,
          setAsCurrent: true,
          insertIndex: 0,
        ));
  }
}

/// BLoC化的确认对话框
class ConfirmationDialogBloc extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;

  const ConfirmationDialogBloc({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, true);
            onConfirm?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
