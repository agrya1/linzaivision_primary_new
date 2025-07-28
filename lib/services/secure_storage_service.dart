import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';

/// 安全存储服务实现
/// 
/// 使用flutter_secure_storage存储敏感数据，如认证令牌等
/// 
/// 适用于存储敏感数据，如密码、令牌、API密钥等
/// 数据将以加密形式存储在设备上，提供更高的安全性
/// 
/// Android: 使用KeyStore系统
/// iOS: 使用Keychain
/// 
/// 使用方式:
/// ```dart
/// // 方式1: 通过依赖注入获取
/// final secureStorage = context.read<SecureStorageService>();
/// 
/// // 方式2: 使用静态工厂方法创建
/// final secureStorage = await SecureStorageService.create();
/// 
/// // 存储敏感数据
/// await secureStorage.saveString('api_token', 'your_secret_token');
/// 
/// // 获取敏感数据
/// final token = await secureStorage.getString('api_token');
/// 
/// // 删除敏感数据
/// await secureStorage.remove('api_token');
/// ```
/// 
/// 注意: 使用此服务前需要添加flutter_secure_storage依赖
class SecureStorageService implements StorageService {
  // FlutterSecureStorage实例
  final FlutterSecureStorage _storage;
  
  // 内存缓存
  final Map<String, dynamic> _cache = {};
  
  // 是否启用缓存
  final bool _useCache;
  
  // 构造函数
  SecureStorageService(this._storage, {bool useCache = true}) : _useCache = useCache {
    // 初始化缓存
    if (_useCache) {
      _initCache();
    }
  }
  
  // 静态工厂方法，用于创建实例
  static Future<SecureStorageService> create({
    bool useCache = true,
  }) async {
    final storage = FlutterSecureStorage();
    final service = SecureStorageService(storage, useCache: useCache);
    
    // 初始化缓存
    if (useCache) {
      await service._initCache();
    }
    
    return service;
  }
  
  // 初始化缓存
  Future<void> _initCache() async {
    try {
      final allValues = await _storage.readAll();
      _cache.addAll(allValues);
      debugPrint('安全存储服务缓存初始化完成，共${allValues.length}个键');
    } catch (e) {
      debugPrint('安全存储服务缓存初始化失败: $e');
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
      await _storage.write(key: key, value: value);
      _updateCache(key, value);
      return true;
    } catch (e) {
      debugPrint('安全保存字符串失败: $e');
      throw StorageException('安全保存字符串失败', e);
    }
  }
  
  @override
  Future<String?> getString(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null) {
        return cachedValue;
      }
      
      // 从安全存储获取
      final value = await _storage.read(key: key);
      _updateCache(key, value);
      return value;
    } catch (e) {
      debugPrint('安全获取字符串失败: $e');
      throw StorageException('安全获取字符串失败', e);
    }
  }
  
  @override
  Future<bool> saveInt(String key, int value) async {
    try {
      await _storage.write(key: key, value: value.toString());
      _updateCache(key, value.toString());
      return true;
    } catch (e) {
      debugPrint('安全保存整数失败: $e');
      throw StorageException('安全保存整数失败', e);
    }
  }
  
  @override
  Future<int?> getInt(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null) {
        return int.tryParse(cachedValue);
      }
      
      // 从安全存储获取
      final value = await _storage.read(key: key);
      _updateCache(key, value);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      debugPrint('安全获取整数失败: $e');
      throw StorageException('安全获取整数失败', e);
    }
  }
  
  @override
  Future<bool> saveBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value.toString());
      _updateCache(key, value.toString());
      return true;
    } catch (e) {
      debugPrint('安全保存布尔值失败: $e');
      throw StorageException('安全保存布尔值失败', e);
    }
  }
  
  @override
  Future<bool?> getBool(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null) {
        return cachedValue.toLowerCase() == 'true';
      }
      
      // 从安全存储获取
      final value = await _storage.read(key: key);
      _updateCache(key, value);
      return value != null ? value.toLowerCase() == 'true' : null;
    } catch (e) {
      debugPrint('安全获取布尔值失败: $e');
      throw StorageException('安全获取布尔值失败', e);
    }
  }
  
  @override
  Future<bool> saveDouble(String key, double value) async {
    try {
      await _storage.write(key: key, value: value.toString());
      _updateCache(key, value.toString());
      return true;
    } catch (e) {
      debugPrint('安全保存浮点数失败: $e');
      throw StorageException('安全保存浮点数失败', e);
    }
  }
  
  @override
  Future<double?> getDouble(String key) async {
    try {
      // 先从缓存获取
      final cachedValue = _getFromCache(key);
      if (cachedValue != null) {
        return double.tryParse(cachedValue);
      }
      
      // 从安全存储获取
      final value = await _storage.read(key: key);
      _updateCache(key, value);
      return value != null ? double.tryParse(value) : null;
    } catch (e) {
      debugPrint('安全获取浮点数失败: $e');
      throw StorageException('安全获取浮点数失败', e);
    }
  }
  
  @override
  Future<bool> saveStringList(String key, List<String> value) async {
    try {
      // 将列表转换为JSON字符串
      final jsonString = jsonEncode(value);
      await _storage.write(key: key, value: jsonString);
      _updateCache(key, jsonString);
      return true;
    } catch (e) {
      debugPrint('安全保存字符串列表失败: $e');
      throw StorageException('安全保存字符串列表失败', e);
    }
  }
  
  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      // 获取JSON字符串
      final jsonString = await getString(key);
      if (jsonString == null) {
        return null;
      }
      
      // 解析JSON字符串
      final list = jsonDecode(jsonString) as List;
      return list.map((item) => item.toString()).toList();
    } catch (e) {
      debugPrint('安全获取字符串列表失败: $e');
      throw StorageException('安全获取字符串列表失败', e);
    }
  }
  
  @override
  Future<bool> saveObject<T>(String key, T value) async {
    try {
      // 将对象转换为JSON字符串
      final jsonString = jsonEncode(value);
      await _storage.write(key: key, value: jsonString);
      _updateCache(key, jsonString);
      return true;
    } catch (e) {
      debugPrint('安全保存对象失败: $e');
      throw StorageException('安全保存对象失败', e);
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
      debugPrint('安全获取对象失败: $e');
      throw StorageException('安全获取对象失败', e);
    }
  }
  
  @override
  Future<bool> containsKey(String key) async {
    try {
      // 先检查缓存
      if (_useCache && _cache.containsKey(key)) {
        return true;
      }
      
      // 检查安全存储
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      debugPrint('安全检查键失败: $e');
      throw StorageException('安全检查键失败', e);
    }
  }
  
  @override
  Future<bool> remove(String key) async {
    try {
      await _storage.delete(key: key);
      _updateCache(key, null);
      return true;
    } catch (e) {
      debugPrint('安全删除数据失败: $e');
      throw StorageException('安全删除数据失败', e);
    }
  }
  
  @override
  Future<bool> clear() async {
    try {
      await _storage.deleteAll();
      if (_useCache) {
        _cache.clear();
      }
      return true;
    } catch (e) {
      debugPrint('安全清除所有数据失败: $e');
      throw StorageException('安全清除所有数据失败', e);
    }
  }
  
  @override
  Future<Set<String>> getKeys() async {
    try {
      final allValues = await _storage.readAll();
      return allValues.keys.toSet();
    } catch (e) {
      debugPrint('安全获取所有键失败: $e');
      throw StorageException('安全获取所有键失败', e);
    }
  }
  
  @override
  Future<void> reload() async {
    try {
      if (_useCache) {
        _cache.clear();
        await _initCache();
      }
    } catch (e) {
      debugPrint('安全重新加载数据失败: $e');
      throw StorageException('安全重新加载数据失败', e);
    }
  }
} 