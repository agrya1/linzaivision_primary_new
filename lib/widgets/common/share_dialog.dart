import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class ShareDialog extends StatefulWidget {
  final String title;
  final String backgroundImagePath;

  const ShareDialog({
    Key? key,
    required this.title,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  // 保存图片到相册
  Future<void> _saveImageToGallery() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 捕获图片
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0, // 提高截图质量
      );

      if (imageBytes != null) {
        // 保存到相册
        final result = await ImageGallerySaver.saveImage(
          imageBytes,
          name: 'share_${DateTime.now().millisecondsSinceEpoch}',
          quality: 100,
        );

        if (!mounted) return;

        if (result['isSuccess']) {
          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片已保存到相册')),
          );
          // 关闭对话框
          Navigator.of(context).pop();
        } else {
          throw Exception('保存失败');
        }
      }
    } catch (e) {
      if (!mounted) return;

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽高和安全区域
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // 按照16:9的比例计算合适的图片高度
    final imageWidth = screenWidth * 0.9; // 图片宽度为屏幕宽度的90%
    final imageHeight = imageWidth * 16 / 9; // 保持16:9的比例

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片展示区域
            // 先创建一个Card来显示截图预览，并添加圆角
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Screenshot(
                controller: _screenshotController,
                child: Container(
                  width: imageWidth,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: widget.backgroundImagePath.startsWith('assets/')
                          ? AssetImage(widget.backgroundImagePath)
                              as ImageProvider
                          : FileImage(File(widget.backgroundImagePath)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 底部按钮区
            Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveImageToGallery,
                icon: Icon(_isSaving ? null : Icons.save_alt,
                    color: Colors.black),
                label: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('保存', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
