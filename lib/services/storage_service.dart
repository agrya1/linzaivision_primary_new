
/// 存储服务接口
/// 
/// 提供统一的存储操作接口，支持不同类型数据的存储和获取
/// 
/// 使用方式:
/// ```dart
/// // 获取StorageService实例
/// final storageService = context.read<StorageService>();
/// 
/// // 保存数据
/// await storageService.saveString('key', 'value');
/// await storageService.saveInt('counter', 42);
/// await storageService.saveBool('is_logged_in', true);
/// 
/// // 获取数据
/// final value = await storageService.getString('key');
/// final counter = await storageService.getInt('counter');
/// final isLoggedIn = await storageService.getBool('is_logged_in');
/// 
/// // 保存对象
/// final user = User(id: 1, name: 'User');
/// await storageService.saveObject('user', user);
/// 
/// // 获取对象
/// final savedUser = await storageService.getObject<User>(
///   'user',
///   (json) => User.fromJson(json),
/// );
/// 
/// // 删除数据
/// await storageService.remove('key');
/// 
/// // 清除所有数据
/// await storageService.clear();
/// ```
/// 
/// 本接口有两个实现:
/// - [SharedPrefsStorageService]: 基于SharedPreferences的实现，用于一般数据
/// - [SecureStorageService]: 基于flutter_secure_storage的实现，用于敏感数据
abstract class StorageService {
  /// 保存字符串
  Future<bool> saveString(String key, String value);
  
  /// 获取字符串
  Future<String?> getString(String key);
  
  /// 保存整数
  Future<bool> saveInt(String key, int value);
  
  /// 获取整数
  Future<int?> getInt(String key);
  
  /// 保存布尔值
  Future<bool> saveBool(String key, bool value);
  
  /// 获取布尔值
  Future<bool?> getBool(String key);
  
  /// 保存双精度浮点数
  Future<bool> saveDouble(String key, double value);
  
  /// 获取双精度浮点数
  Future<double?> getDouble(String key);
  
  /// 保存字符串列表
  Future<bool> saveStringList(String key, List<String> value);
  
  /// 获取字符串列表
  Future<List<String>?> getStringList(String key);
  
  /// 保存对象（将对象转换为JSON字符串存储）
  Future<bool> saveObject<T>(String key, T value);
  
  /// 获取对象（从JSON字符串转换回对象）
  Future<T?> getObject<T>(String key, T Function(Map<String, dynamic>) fromJson);
  
  /// 检查是否包含指定键
  Future<bool> containsKey(String key);
  
  /// 删除指定键的数据
  Future<bool> remove(String key);
  
  /// 清除所有数据
  Future<bool> clear();
  
  /// 获取所有键
  Future<Set<String>> getKeys();
  
  /// 重新加载数据（从持久化存储刷新内存缓存）
  Future<void> reload();
}

/// 存储异常类
class StorageException implements Exception {
  final String message;
  final dynamic error;
  
  StorageException(this.message, [this.error]);
  
  @override
  String toString() => 'StorageException: $message${error != null ? ' ($error)' : ''}';
} 