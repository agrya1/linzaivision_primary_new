import 'package:flutter/foundation.dart';
import '../repository/goal_repository.dart';
import '../repository/explore_repository.dart';
import '../repository/search_repository.dart';
import '../repository/auth_repository.dart';
import '../repository/settings_repository.dart';
import '../repository/profile_repository.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../database/database_helper.dart';

/// 统一的Repository提供者
///
/// 负责创建和管理所有Repository实例，确保依赖关系正确
/// 并提供统一的访问接口
class AppRepositoryProvider {
  // 单例实例
  static AppRepositoryProvider? _instance;
  static AppRepositoryProvider get instance =>
      _instance ??= AppRepositoryProvider._internal();

  // 私有构造函数
  AppRepositoryProvider._internal();

  // Repository实例缓存
  GoalRepository? _goalRepository;
  ExploreRepository? _exploreRepository;
  SearchRepository? _searchRepository;
  AuthRepository? _authRepository;
  SettingsRepository? _settingsRepository;
  ProfileRepository? _profileRepository;

  // 依赖服务
  DatabaseHelper? _databaseHelper;
  StorageService? _storageService;
  AuthService? _authService;
  ApiService? _apiService;

  /// 初始化Repository提供者
  ///
  /// 必须在使用任何Repository之前调用此方法
  void initialize({
    required DatabaseHelper databaseHelper,
    required StorageService storageService,
    required AuthService authService,
    required ApiService apiService,
  }) {
    _databaseHelper = databaseHelper;
    _storageService = storageService;
    _authService = authService;
    _apiService = apiService;

    if (kDebugMode) {
      print('【RepositoryProvider】已初始化，依赖服务已注入');
    }
  }

  /// 获取目标仓库
  GoalRepository get goalRepository {
    if (_goalRepository == null) {
      _ensureInitialized();
      _goalRepository = GoalRepositoryImpl(_databaseHelper!);
      if (kDebugMode) {
        print('【RepositoryProvider】创建GoalRepository实例');
      }
    }
    return _goalRepository!;
  }

  /// 获取探索仓库
  ExploreRepository get exploreRepository {
    if (_exploreRepository == null) {
      _exploreRepository = ExploreRepositoryImpl();
      if (kDebugMode) {
        print('【RepositoryProvider】创建ExploreRepository实例');
      }
    }
    return _exploreRepository!;
  }

  /// 获取搜索仓库
  SearchRepository get searchRepository {
    if (_searchRepository == null) {
      _ensureInitialized();
      _searchRepository = SearchRepositoryImpl(_databaseHelper!);
      if (kDebugMode) {
        print('【RepositoryProvider】创建SearchRepository实例');
      }
    }
    return _searchRepository!;
  }

  /// 获取认证仓库
  AuthRepository get authRepository {
    if (_authRepository == null) {
      _ensureInitialized();
      _authRepository = AuthRepositoryImpl(_authService!, _storageService!);
      if (kDebugMode) {
        print('【RepositoryProvider】创建AuthRepository实例');
      }
    }
    return _authRepository!;
  }

  /// 获取设置仓库
  SettingsRepository get settingsRepository {
    if (_settingsRepository == null) {
      _ensureInitialized();
      _settingsRepository = SettingsRepositoryImpl(_storageService!);
      if (kDebugMode) {
        print('【RepositoryProvider】创建SettingsRepository实例');
      }
    }
    return _settingsRepository!;
  }

  /// 获取用户资料仓库
  ProfileRepository get profileRepository {
    if (_profileRepository == null) {
      _ensureInitialized();
      _profileRepository = ProfileRepositoryImpl(
        _authService!,
        _storageService!,
        _apiService!,
      );
      if (kDebugMode) {
        print('【RepositoryProvider】创建ProfileRepository实例');
      }
    }
    return _profileRepository!;
  }

  /// 获取所有Repository的健康状态
  Map<String, bool> getHealthStatus() {
    return {
      'goalRepository': _goalRepository != null,
      'exploreRepository': _exploreRepository != null,
      'searchRepository': _searchRepository != null,
      'authRepository': _authRepository != null,
      'settingsRepository': _settingsRepository != null,
      'profileRepository': _profileRepository != null,
      'databaseHelper': _databaseHelper != null,
      'storageService': _storageService != null,
      'authService': _authService != null,
      'apiService': _apiService != null,
    };
  }

  /// 清理所有Repository实例
  ///
  /// 用于测试或重新初始化
  void dispose() {
    _goalRepository = null;
    _exploreRepository = null;
    _searchRepository = null;
    _authRepository = null;
    _settingsRepository = null;
    _profileRepository = null;

    if (kDebugMode) {
      print('【RepositoryProvider】已清理所有Repository实例');
    }
  }

  /// 重置单例实例
  ///
  /// 仅用于测试
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (_databaseHelper == null ||
        _storageService == null ||
        _authService == null ||
        _apiService == null) {
      throw StateError('RepositoryProvider未初始化。请先调用initialize()方法。');
    }
  }

  /// 获取初始化状态
  bool get isInitialized {
    return _databaseHelper != null &&
        _storageService != null &&
        _authService != null &&
        _apiService != null;
  }

  /// 获取依赖服务状态
  Map<String, bool> getDependencyStatus() {
    return {
      'databaseHelper': _databaseHelper != null,
      'storageService': _storageService != null,
      'authService': _authService != null,
      'apiService': _apiService != null,
    };
  }
}

/// Repository提供者异常
class RepositoryProviderException implements Exception {
  final String message;
  final dynamic error;

  RepositoryProviderException(this.message, [this.error]);

  @override
  String toString() =>
      'RepositoryProviderException: $message${error != null ? ' ($error)' : ''}';
}

/// Repository生命周期管理器
///
/// 负责管理Repository的生命周期，包括创建、缓存、清理等
class RepositoryLifecycleManager {
  static final Map<Type, dynamic> _repositoryCache = {};
  static final Map<Type, DateTime> _creationTimes = {};

  /// 注册Repository实例
  static void register<T>(T repository) {
    _repositoryCache[T] = repository;
    _creationTimes[T] = DateTime.now();

    if (kDebugMode) {
      print('【RepositoryLifecycleManager】注册Repository: ${T.toString()}');
    }
  }

  /// 获取Repository实例
  static T? get<T>() {
    return _repositoryCache[T] as T?;
  }

  /// 移除Repository实例
  static void unregister<T>() {
    _repositoryCache.remove(T);
    _creationTimes.remove(T);

    if (kDebugMode) {
      print('【RepositoryLifecycleManager】移除Repository: ${T.toString()}');
    }
  }

  /// 清理所有Repository实例
  static void clear() {
    _repositoryCache.clear();
    _creationTimes.clear();

    if (kDebugMode) {
      print('【RepositoryLifecycleManager】清理所有Repository实例');
    }
  }

  /// 获取Repository统计信息
  static Map<String, dynamic> getStatistics() {
    return {
      'totalRepositories': _repositoryCache.length,
      'repositories':
          _repositoryCache.keys.map((type) => type.toString()).toList(),
      'creationTimes': _creationTimes.map(
          (type, time) => MapEntry(type.toString(), time.toIso8601String())),
    };
  }
}
