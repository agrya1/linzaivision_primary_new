import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import '../../models/goal.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final Function(bool)? onStatusChange;
  final double? width;
  final double? height;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onMoreTap,
    this.onStatusChange,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // 获取媒体查询信息
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 104 - 48; // 减去边距空间

    // 计算文本的高度
    final double textHeight = _calculateTextHeight(
        availableWidth: width != null ? width! - 48 : availableWidth);

    // 计算卡片最终高度：文本高度 + 上下padding(64)
    final double contentHeight = textHeight + 64;

    // 取计算高度和最小高度(165)的较大值，或使用传入的固定高度
    final double finalHeight = height ?? max(contentHeight, 165.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: width,
          height: finalHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: _buildBackgroundImage(),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
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
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  goal.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (goal.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      goal.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(179, 248, 248, 248),
                        fontFamily: 'STZhongsong',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 计算文本高度的辅助方法
  double _calculateTextHeight({required double availableWidth}) {
    // 计算标题高度
    final TextStyle titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );

    final TextSpan titleSpan = TextSpan(
      text: goal.title,
      style: titleStyle,
    );

    final TextPainter titlePainter = TextPainter(
      text: titleSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: null, // 允许文本自然换行
    );

    titlePainter.layout(maxWidth: availableWidth);
    double totalHeight = titlePainter.height;

    // 如果有描述文本，计算描述文本高度
    if (goal.description.isNotEmpty) {
      final TextStyle descriptionStyle = const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontFamily: 'STZhongsong',
      );

      final TextSpan descriptionSpan = TextSpan(
        text: goal.description,
        style: descriptionStyle,
      );

      final TextPainter descriptionPainter = TextPainter(
        text: descriptionSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '...',
      );

      descriptionPainter.layout(maxWidth: availableWidth);

      // 加上描述文本高度和间距
      totalHeight += descriptionPainter.height + 8; // 8是标题和描述之间的间距
    }

    return totalHeight;
  }

  DecorationImage _buildBackgroundImage() {
    const String defaultImagePath = 'assets/images/default/default.jpg';

    try {
      if (goal.imagePath.isEmpty) {
        print('警告: goal.imagePath为空');
        return const DecorationImage(
          image: AssetImage(defaultImagePath),
          fit: BoxFit.cover,
        );
      }

      if (goal.imagePath.startsWith('assets/')) {
        print('加载资源图片: ${goal.imagePath}');
        return DecorationImage(
          image: AssetImage(goal.imagePath),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            print('资源图片加载错误: ${goal.imagePath}, 错误: $exception');
          },
        );
      } else {
        print('加载文件图片: ${goal.imagePath}');
        final file = File(goal.imagePath);
        final exists = file.existsSync();
        if (!exists) {
          print('文件不存在: ${goal.imagePath}');
          return const DecorationImage(
            image: AssetImage(defaultImagePath),
            fit: BoxFit.cover,
          );
        }

        return DecorationImage(
          image: FileImage(file),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            print('文件图片加载错误: ${goal.imagePath}, 错误: $exception');
          },
        );
      }
    } catch (e) {
      print('图片加载异常: ${goal.imagePath}, 错误: $e');
      return const DecorationImage(
        image: AssetImage(defaultImagePath),
        fit: BoxFit.cover,
      );
    }
  }
}
