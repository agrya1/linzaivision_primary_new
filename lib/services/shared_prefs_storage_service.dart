import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// SharedPreferences实现的存储服务
/// 
/// 使用SharedPreferences存储数据，并提供内存缓存以提高性能
/// 
/// 适用于存储一般的非敏感数据，如用户设置、缓存等
/// 
/// 使用方式:
/// ```dart
/// // 方式1: 通过依赖注入获取
/// final storageService = context.read<StorageService>();
/// 
/// // 方式2: 直接创建实例
/// final prefs = await SharedPreferences.getInstance();
/// final storageService = SharedPrefsStorageService(prefs);
/// 
/// // 方式3: 使用静态工厂方法
/// final storageService = await SharedPrefsStorageService.create();
/// 
/// // 使用方法与StorageService接口一致
/// await storageService.saveString('key', 'value');
/// final value = await storageService.getString('key');
/// ```
class SharedPrefsStorageService implements StorageService {
  // SharedPreferences实例
  final SharedPreferences _prefs;
  
  // 内存缓存
  final Map<String, dynamic> _cache = {};
  
  // 是否启用缓存
  final bool _useCache;
  
  // 构造函数
  SharedPrefsStorageService(this._prefs, {bool useCache = true}) : _useCache = useCache {
    // 初始化缓存
    if (_useCache) {
      _initCache();
    }
  }
  
  // 静态工厂方法，用于创建实例
  static Future<SharedPrefsStorageService> create({bool useCache = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsStorageService(prefs, useCache: useCache);
  }
  
  // 初始化缓存
  void _initCache() {
    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        _cache[key] = _prefs.get(key);
      }
      debugPrint('存储服务缓存初始化完成，共${keys.length}个键');
    } catch (e) {
      debugPrint('存储服务缓存初始化失败: $e');
    }
  }
  
  // 更新缓存
  void _updateCache(String key, dynamic value) {
    if (_useCache) {
      if (value == null) {
        _cache.remove(key);
      } else {
        _cache[key] = value;
      }
    }
  }
  
  // 从缓存获取值
  dynamic _getFromCache(String key) {
    if (_useCache && _cache.containsKey(key)) {
      return _cache[key];
    }
    return null;
  }
  
  @override
  Future<bool> saveString(String key, String value) async {
    try {
      final result = await _prefs.setString(key, value);
      _updateCache(key, value);
      return result;
    } catch (e) {
      debugPrint('保存字符串失败: $e');
      throw StorageException('保存字符串失败', e);
    }
  }
  
  @override
  Future<String?> getString(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null && cachedValue is String) {
        return cachedValue;
      }
      
      // 从SharedPreferences获取
      final value = _prefs.getString(key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('获取字符串失败: $e');
      throw StorageException('获取字符串失败', e);
    }
  }
  
  @override
  Future<bool> saveInt(String key, int value) async {
    try {
      final result = await _prefs.setInt(key, value);
      _updateCache(key, value);
      return result;
    } catch (e) {
      debugPrint('保存整数失败: $e');
      throw StorageException('保存整数失败', e);
    }
  }
  
  @override
  Future<int?> getInt(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null && cachedValue is int) {
        return cachedValue;
      }
      
      // 从SharedPreferences获取
      final value = _prefs.getInt(key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('获取整数失败: $e');
      throw StorageException('获取整数失败', e);
    }
  }
  
  @override
  Future<bool> saveBool(String key, bool value) async {
    try {
      final result = await _prefs.setBool(key, value);
      _updateCache(key, value);
      return result;
    } catch (e) {
      debugPrint('保存布尔值失败: $e');
      throw StorageException('保存布尔值失败', e);
    }
  }
  
  @override
  Future<bool?> getBool(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null && cachedValue is bool) {
        return cachedValue;
      }
      
      // 从SharedPreferences获取
      final value = _prefs.getBool(key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('获取布尔值失败: $e');
      throw StorageException('获取布尔值失败', e);
    }
  }
  
  @override
  Future<bool> saveDouble(String key, double value) async {
    try {
      final result = await _prefs.setDouble(key, value);
      _updateCache(key, value);
      return result;
    } catch (e) {
      debugPrint('保存浮点数失败: $e');
      throw StorageException('保存浮点数失败', e);
    }
  }
  
  @override
  Future<double?> getDouble(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null && cachedValue is double) {
        return cachedValue;
      }
      
      // 从SharedPreferences获取
      final value = _prefs.getDouble(key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('获取浮点数失败: $e');
      throw StorageException('获取浮点数失败', e);
    }
  }
  
  @override
  Future<bool> saveStringList(String key, List<String> value) async {
    try {
      final result = await _prefs.setStringList(key, value);
      _updateCache(key, value);
      return result;
    } catch (e) {
      debugPrint('保存字符串列表失败: $e');
      throw StorageException('保存字符串列表失败', e);
    }
  }
  
  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null && cachedValue is List<String>) {
        return cachedValue;
      }
      
      // 从SharedPreferences获取
      final value = _prefs.getStringList(key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('获取字符串列表失败: $e');
      throw StorageException('获取字符串列表失败', e);
    }
  }
  
  @override
  Future<bool> saveObject<T>(String key, T value) async {
    try {
      // 将对象转换为JSON字符串
      final jsonString = jsonEncode(value);
      final result = await _prefs.setString(key, jsonString);
      _updateCache(key, jsonString);
      return result;
    } catch (e) {
      debugPrint('保存对象失败: $e');
      throw StorageException('保存对象失败', e);
    }
  }
  
  @override
  Future<T?> getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    try {
      // 获取JSON字符串
      final jsonString = await getString(key);
      if (jsonString == null) {
        return null;
      }
      
      // 解析JSON字符串
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(jsonMap);
    } catch (e) {
      debugPrint('获取对象失败: $e');
      throw StorageException('获取对象失败', e);
    }
  }
  
  @override
  Future<bool> containsKey(String key) async {
    try {
      // 先检查缓存
      if (_useCache && _cache.containsKey(key)) {
        return true;
      }
      
      // 检查SharedPreferences
      return _prefs.containsKey(key);
    } catch (e) {
      debugPrint('检查键失败: $e');
      throw StorageException('检查键失败', e);
    }
  }
  
  @override
  Future<bool> remove(String key) async {
    try {
      final result = await _prefs.remove(key);
      _updateCache(key, null);
      return result;
    } catch (e) {
      debugPrint('删除数据失败: $e');
      throw StorageException('删除数据失败', e);
    }
  }
  
  @override
  Future<bool> clear() async {
    try {
      final result = await _prefs.clear();
      if (_useCache) {
        _cache.clear();
      }
      return result;
    } catch (e) {
      debugPrint('清除所有数据失败: $e');
      throw StorageException('清除所有数据失败', e);
    }
  }
  
  @override
  Future<Set<String>> getKeys() async {
    try {
      return _prefs.getKeys();
    } catch (e) {
      debugPrint('获取所有键失败: $e');
      throw StorageException('获取所有键失败', e);
    }
  }
  
  @override
  Future<void> reload() async {
    try {
      await _prefs.reload();
      if (_useCache) {
        _initCache();
      }
    } catch (e) {
      debugPrint('重新加载数据失败: $e');
      throw StorageException('重新加载数据失败', e);
    }
  }
} 