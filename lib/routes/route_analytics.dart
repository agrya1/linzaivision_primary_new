import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

/// 路由分析服务
/// 
/// 用于收集和分析用户导航行为
class RouteAnalytics {
  static final RouteAnalytics _instance = RouteAnalytics._internal();
  
  /// 存储服务，用于持久化导航数据
  StorageService? _storageService;
  
  /// 是否启用分析
  bool _enabled = true;
  
  /// 用户访问的页面历史
  final List<PageVisit> _pageVisits = [];
  
  /// 获取单例实例
  factory RouteAnalytics() {
    return _instance;
  }
  
  RouteAnalytics._internal();
  
  /// 初始化分析服务
  void init(StorageService storageService) {
    _storageService = storageService;
    _loadPageVisits();
  }
  
  /// 设置是否启用分析
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  /// 记录页面访问
  void recordPageVisit(String routeName, {Map<String, dynamic>? parameters}) {
    if (!_enabled) return;
    
    final visit = PageVisit(
      routeName: routeName,
      timestamp: DateTime.now(),
      parameters: parameters,
    );
    
    _pageVisits.add(visit);
    _savePageVisits();
    
    // 输出日志
    debugPrint('记录页面访问: $routeName - ${visit.timestamp}');
  }
  
  /// 获取用户访问历史
  List<PageVisit> getPageVisits() {
    return List.unmodifiable(_pageVisits);
  }
  
  /// 获取最常访问的页面
  List<PageVisitCount> getMostVisitedPages({int limit = 5}) {
    final Map<String, int> counts = {};
    
    for (final visit in _pageVisits) {
      counts[visit.routeName] = (counts[visit.routeName] ?? 0) + 1;
    }
    
    final List<PageVisitCount> result = counts.entries
        .map((entry) => PageVisitCount(routeName: entry.key, count: entry.value))
        .toList();
    
    result.sort((a, b) => b.count.compareTo(a.count));
    
    return result.take(limit).toList();
  }
  
  /// 清除访问历史
  void clearPageVisits() {
    _pageVisits.clear();
    _savePageVisits();
  }
  
  /// 加载页面访问历史
  Future<void> _loadPageVisits() async {
    if (_storageService == null) return;
    
    try {
      final data = await _storageService!.getObject<Map<String, dynamic>>(
        'page_visits',
        (json) => json,
      );
      
      if (data != null && data['visits'] is List) {
        final List<dynamic> visits = data['visits'] as List<dynamic>;
        _pageVisits.clear();
        for (final item in visits) {
          if (item is Map<String, dynamic>) {
            _pageVisits.add(PageVisit.fromJson(item));
          }
        }
      }
    } catch (e) {
      debugPrint('加载页面访问历史失败: $e');
    }
  }
  
  /// 保存页面访问历史
  Future<void> _savePageVisits() async {
    if (_storageService == null) return;
    
    try {
      final List<Map<String, dynamic>> data = _pageVisits.map((visit) => visit.toJson()).toList();
      await _storageService!.saveObject('page_visits', {'visits': data});
    } catch (e) {
      debugPrint('保存页面访问历史失败: $e');
    }
  }
}

/// 页面访问记录
class PageVisit {
  /// 路由名称
  final String routeName;
  
  /// 访问时间
  final DateTime timestamp;
  
  /// 路由参数
  final Map<String, dynamic>? parameters;
  
  PageVisit({
    required this.routeName,
    required this.timestamp,
    this.parameters,
  });
  
  /// 从JSON创建页面访问记录
  factory PageVisit.fromJson(Map<String, dynamic> json) {
    return PageVisit(
      routeName: json['routeName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      parameters: json['parameters'] as Map<String, dynamic>?,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'routeName': routeName,
      'timestamp': timestamp.toIso8601String(),
      'parameters': parameters,
    };
  }
}

/// 页面访问次数
class PageVisitCount {
  /// 路由名称
  final String routeName;
  
  /// 访问次数
  final int count;
  
  PageVisitCount({
    required this.routeName,
    required this.count,
  });
} 