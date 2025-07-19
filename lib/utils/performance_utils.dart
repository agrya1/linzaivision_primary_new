import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

/// 性能优化工具类
class PerformanceUtils {
  /// 图片缓存管理器
  static final Map<String, ImageProvider> _imageCache = {};
  
  /// 获取缓存的图片
  static ImageProvider getCachedImage(String path) {
    if (!_imageCache.containsKey(path)) {
      if (path.startsWith('http')) {
        _imageCache[path] = NetworkImage(path);
      } else {
        _imageCache[path] = AssetImage(path);
      }
    }
    return _imageCache[path]!;
  }
  
  /// 清理图片缓存
  static void clearImageCache() {
    _imageCache.clear();
  }
  
  /// 在后台线程处理耗时操作
  static Future<T> processInBackground<T>(
    T Function() computation,
  ) async {
    return await compute(_backgroundComputation, computation);
  }
  
  /// 后台计算函数
  static T _backgroundComputation<T>(T Function() computation) {
    return computation();
  }
  
  /// 批量处理数据
  static Future<List<T>> batchProcess<T>(
    List<T> items,
    Future<T> Function(T item) processor, {
    int batchSize = 10,
  }) async {
    final results = <T>[];
    
    for (int i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize);
      final batchResults = await Future.wait(
        batch.map((item) => processor(item)),
      );
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  /// 防抖函数
  static Function debounce(
    Function func,
    Duration delay,
  ) {
    Timer? timer;
    return (dynamic args) {
      timer?.cancel();
      timer = Timer(delay, () => func(args));
    };
  }
  
  /// 节流函数
  static Function throttle(
    Function func,
    Duration delay,
  ) {
    DateTime? lastRun;
    return (dynamic args) {
      final now = DateTime.now();
      if (lastRun == null || now.difference(lastRun!) >= delay) {
        lastRun = now;
        func(args);
      }
    };
  }
}

/// 优化的图片组件
class OptimizedImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  
  const OptimizedImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });
  
  @override
  Widget build(BuildContext context) {
    return Image(
      image: PerformanceUtils.getCachedImage(imagePath),
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? const Center(
          child: CircularProgressIndicator(),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Center(
          child: Icon(Icons.error),
        );
      },
    );
  }
}

/// 异步数据加载组件
class AsyncDataLoader<T> extends StatelessWidget {
  final Future<T> Function() loader;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  
  const AsyncDataLoader({
    super.key,
    required this.loader,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return errorWidget ?? Center(
            child: Text('加载失败: ${snapshot.error}'),
          );
        }
        
        if (snapshot.hasData) {
          return builder(context, snapshot.data!);
        }
        
        return const Center(child: Text('暂无数据'));
      },
    );
  }
} 