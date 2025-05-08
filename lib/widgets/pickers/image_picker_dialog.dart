import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerDialog extends StatelessWidget {
  final int membershipStatus; // 0-未登录，1-普通用户，2-会员用户
  final Function(String imagePath) onImageSelected;
  final VoidCallback onMembershipPrompt; // 当选择会员图片但用户不是会员时的回调

  const ImagePickerDialog({
    Key? key,
    required this.membershipStatus,
    required this.onImageSelected,
    required this.onMembershipPrompt,
  }) : super(key: key);

  // 获取默认图片列表，区分免费和会员图片
  List<Map<String, dynamic>> _getDefaultImages() {
    // 默认提供的免费图片
    final freeImages = [
      'assets/images/default/default.jpg',
      'assets/images/default/default2.jpg',
      'assets/images/default/default3.jpg',
      'assets/images/default/default4.png',
    ];

    // 预留的会员图片
    final vipImages = [
      'assets/images/default/default5.png',
      'assets/images/default/default6.png',
      'assets/images/default/default7.png',
      'assets/images/default/default8.png',
    ];

    // 转换为包含图片路径和会员状态的Map列表
    List<Map<String, dynamic>> result = [];

    // 添加免费图片
    for (var path in freeImages) {
      result.add({
        'path': path,
        'isVip': false,
      });
    }

    // 添加会员图片
    for (var path in vipImages) {
      result.add({
        'path': path,
        'isVip': true,
      });
    }

    // TODO: 后期这里可以从后端API获取图片列表
    // final apiImages = await _apiService.getBackgroundImages();
    // result.addAll(apiImages);

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // 获取预置图片列表，包括免费和会员图片
    final imagesList = _getDefaultImages();

    return Dialog(
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
            // 内容区域 - 网格展示预置图片 (竖图，每行三个)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 每行三个图片
                    childAspectRatio: 0.7, // 竖图比例
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: imagesList.length,
                  itemBuilder: (context, index) {
                    final imageData = imagesList[index];
                    final imagePath = imageData['path'];
                    final isVip = imageData['isVip'];

                    return GestureDetector(
                      onTap: () {
                        // 检查是否为VIP图片且用户不是会员
                        if (isVip && membershipStatus < 2) {
                          // 关闭当前对话框
                          Navigator.pop(context);
                          // 调用会员提示回调
                          onMembershipPrompt();
                        } else {
                          // 普通图片或用户是会员，直接选择
                          onImageSelected(imagePath);
                          Navigator.pop(context);
                        }
                      },
                      child: Stack(
                        children: [
                          // 图片
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          // VIP标识 (右上角)
                          if (isVip)
                            Positioned(
                              right: 5,
                              top: 5,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.amber[700],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
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
                onPressed: () async {
                  Navigator.pop(context);

                  // 打开系统相册
                  final ImagePicker picker = ImagePicker();
                  try {
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      onImageSelected(image.path);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('选择图片失败，请重试')),
                      );
                    }
                  }
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
    );
  }

  // 显示图片选择器对话框的静态方法
  static Future<void> show({
    required BuildContext context,
    required int membershipStatus,
    required Function(String) onImageSelected,
    required VoidCallback onMembershipPrompt,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) => ImagePickerDialog(
        membershipStatus: membershipStatus,
        onImageSelected: onImageSelected,
        onMembershipPrompt: onMembershipPrompt,
      ),
    );
  }
}
