import '../services/storage_service.dart';

/// 设置仓库接口
/// 
/// 提供应用设置的存储和获取功能
abstract class SettingsRepository {
  /// 获取BLoC模式状态
  Future<bool> getUseBlocMode();
  
  /// 设置BLoC模式状态
  Future<bool> setUseBlocMode(bool value);
  
  /// 获取主题模式
  Future<String> getThemeMode();
  
  /// 设置主题模式
  Future<bool> setThemeMode(String value);
  
  /// 获取语言设置
  Future<String> getLanguage();
  
  /// 设置语言
  Future<bool> setLanguage(String value);
  
  /// 获取首页设置
  Future<String> getHomePage();
  
  /// 设置首页
  Future<bool> setHomePage(String value);
  
  /// 获取是否跟随系统主题
  Future<bool> getFollowSystemTheme();
  
  /// 设置是否跟随系统主题
  Future<bool> setFollowSystemTheme(bool value);
  
  /// 获取性能监控状态
  Future<bool> getEnablePerformanceMonitoring();
  
  /// 设置性能监控状态
  Future<bool> setEnablePerformanceMonitoring(bool value);
  
  /// 获取错误日志状态
  Future<bool> getEnableErrorLogging();
  
  /// 设置错误日志状态
  Future<bool> setEnableErrorLogging(bool value);
  
  /// 清除所有设置
  Future<bool> clearAllSettings();
}

/// 设置仓库实现
/// 
/// 使用StorageService存储和获取应用设置
class SettingsRepositoryImpl implements SettingsRepository {
  final StorageService _storageService;
  
  // 设置键名
  static const String _useBlocModeKey = 'use_bloc_mode';
  static const String _themeModeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _homePageKey = 'home_page';
  static const String _followSystemThemeKey = 'follow_system_theme';
  static const String _enablePerformanceMonitoringKey = 'enable_performance_monitoring';
  static const String _enableErrorLoggingKey = 'enable_error_logging';
  
  // 默认值
  static const bool _defaultUseBlocMode = false;
  static const String _defaultThemeMode = 'light';
  static const String _defaultLanguage = 'zh_CN';
  static const String _defaultHomePage = 'first_goal'; // 默认首页为第一条意识条目
  static const bool _defaultFollowSystemTheme = true;
  static const bool _defaultEnablePerformanceMonitoring = true;
  static const bool _defaultEnableErrorLogging = true;
  
  SettingsRepositoryImpl(this._storageService);
  
  @override
  Future<bool> getUseBlocMode() async {
    return await _storageService.getBool(_useBlocModeKey) ?? _defaultUseBlocMode;
  }
  
  @override
  Future<bool> setUseBlocMode(bool value) async {
    return await _storageService.saveBool(_useBlocModeKey, value);
  }
  
  @override
  Future<String> getThemeMode() async {
    return await _storageService.getString(_themeModeKey) ?? _defaultThemeMode;
  }
  
  @override
  Future<bool> setThemeMode(String value) async {
    return await _storageService.saveString(_themeModeKey, value);
  }
  
  @override
  Future<String> getLanguage() async {
    return await _storageService.getString(_languageKey) ?? _defaultLanguage;
  }
  
  @override
  Future<bool> setLanguage(String value) async {
    return await _storageService.saveString(_languageKey, value);
  }
  
  @override
  Future<String> getHomePage() async {
    return await _storageService.getString(_homePageKey) ?? _defaultHomePage;
  }
  
  @override
  Future<bool> setHomePage(String value) async {
    return await _storageService.saveString(_homePageKey, value);
  }
  
  @override
  Future<bool> getFollowSystemTheme() async {
    return await _storageService.getBool(_followSystemThemeKey) ?? _defaultFollowSystemTheme;
  }
  
  @override
  Future<bool> setFollowSystemTheme(bool value) async {
    return await _storageService.saveBool(_followSystemThemeKey, value);
  }
  
  @override
  Future<bool> getEnablePerformanceMonitoring() async {
    return await _storageService.getBool(_enablePerformanceMonitoringKey) ?? _defaultEnablePerformanceMonitoring;
  }
  
  @override
  Future<bool> setEnablePerformanceMonitoring(bool value) async {
    return await _storageService.saveBool(_enablePerformanceMonitoringKey, value);
  }
  
  @override
  Future<bool> getEnableErrorLogging() async {
    return await _storageService.getBool(_enableErrorLoggingKey) ?? _defaultEnableErrorLogging;
  }
  
  @override
  Future<bool> setEnableErrorLogging(bool value) async {
    return await _storageService.saveBool(_enableErrorLoggingKey, value);
  }
  
  @override
  Future<bool> clearAllSettings() async {
    try {
      await _storageService.remove(_useBlocModeKey);
      await _storageService.remove(_themeModeKey);
      await _storageService.remove(_languageKey);
      await _storageService.remove(_homePageKey);
      await _storageService.remove(_followSystemThemeKey);
      await _storageService.remove(_enablePerformanceMonitoringKey);
      await _storageService.remove(_enableErrorLoggingKey);
      return true;
    } catch (e) {
      return false;
    }
  }
} 