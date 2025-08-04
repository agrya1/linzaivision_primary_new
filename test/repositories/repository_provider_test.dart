import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:linzaivision_primary/repositories/repository_provider.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/services/api_service.dart';
import 'package:linzaivision_primary/services/storage_service.dart';
import 'package:linzaivision_primary/database/database_helper.dart';

// 生成Mock类
@GenerateMocks([AuthService, ApiService, StorageService, DatabaseHelper])
import 'repository_provider_test.mocks.dart';

void main() {
  group('AppRepositoryProvider', () {
    late MockAuthService mockAuthService;
    late MockApiService mockApiService;
    late MockStorageService mockStorageService;
    late MockDatabaseHelper mockDatabaseHelper;

    setUp(() {
      mockAuthService = MockAuthService();
      mockApiService = MockApiService();
      mockStorageService = MockStorageService();
      mockDatabaseHelper = MockDatabaseHelper();
      
      // 重置单例实例
      AppRepositoryProvider.resetInstance();
    });

    tearDown(() {
      AppRepositoryProvider.resetInstance();
    });

    test('应该是单例模式', () {
      final instance1 = AppRepositoryProvider.instance;
      final instance2 = AppRepositoryProvider.instance;
      
      expect(instance1, same(instance2));
    });

    test('初始化前应该抛出异常', () {
      final provider = AppRepositoryProvider.instance;
      
      expect(() => provider.goalRepository, throwsStateError);
    });

    test('初始化后应该能正常工作', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      expect(provider.isInitialized, isTrue);
    });

    test('应该能创建所有Repository实例', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      // 测试所有Repository都能正常创建
      expect(provider.goalRepository, isNotNull);
      expect(provider.exploreRepository, isNotNull);
      expect(provider.searchRepository, isNotNull);
      expect(provider.authRepository, isNotNull);
      expect(provider.settingsRepository, isNotNull);
      expect(provider.profileRepository, isNotNull);
    });

    test('Repository实例应该被缓存', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      // 多次获取应该返回同一实例
      final goalRepo1 = provider.goalRepository;
      final goalRepo2 = provider.goalRepository;
      
      expect(goalRepo1, same(goalRepo2));
    });

    test('应该能获取健康状态', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      // 触发Repository创建
      provider.goalRepository;
      provider.authRepository;
      
      final healthStatus = provider.getHealthStatus();
      
      expect(healthStatus['goalRepository'], isTrue);
      expect(healthStatus['authRepository'], isTrue);
      expect(healthStatus['databaseHelper'], isTrue);
      expect(healthStatus['storageService'], isTrue);
      expect(healthStatus['authService'], isTrue);
      expect(healthStatus['apiService'], isTrue);
    });

    test('应该能获取依赖状态', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      final dependencyStatus = provider.getDependencyStatus();
      
      expect(dependencyStatus['databaseHelper'], isTrue);
      expect(dependencyStatus['storageService'], isTrue);
      expect(dependencyStatus['authService'], isTrue);
      expect(dependencyStatus['apiService'], isTrue);
    });

    test('dispose应该清理所有Repository实例', () {
      final provider = AppRepositoryProvider.instance;
      
      provider.initialize(
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        apiService: mockApiService,
      );
      
      // 创建一些Repository实例
      provider.goalRepository;
      provider.authRepository;
      
      // 验证实例已创建
      var healthStatus = provider.getHealthStatus();
      expect(healthStatus['goalRepository'], isTrue);
      expect(healthStatus['authRepository'], isTrue);
      
      // 清理
      provider.dispose();
      
      // 验证实例已清理
      healthStatus = provider.getHealthStatus();
      expect(healthStatus['goalRepository'], isFalse);
      expect(healthStatus['authRepository'], isFalse);
    });
  });

  group('RepositoryLifecycleManager', () {
    setUp(() {
      RepositoryLifecycleManager.clear();
    });

    tearDown(() {
      RepositoryLifecycleManager.clear();
    });

    test('应该能注册和获取Repository', () {
      const testRepo = 'test_repository';
      
      RepositoryLifecycleManager.register<String>(testRepo);
      
      final retrieved = RepositoryLifecycleManager.get<String>();
      expect(retrieved, equals(testRepo));
    });

    test('应该能移除Repository', () {
      const testRepo = 'test_repository';
      
      RepositoryLifecycleManager.register<String>(testRepo);
      expect(RepositoryLifecycleManager.get<String>(), isNotNull);
      
      RepositoryLifecycleManager.unregister<String>();
      expect(RepositoryLifecycleManager.get<String>(), isNull);
    });

    test('应该能获取统计信息', () {
      const testRepo1 = 'test_repository_1';
      const testRepo2 = 42;
      
      RepositoryLifecycleManager.register<String>(testRepo1);
      RepositoryLifecycleManager.register<int>(testRepo2);
      
      final stats = RepositoryLifecycleManager.getStatistics();
      
      expect(stats['totalRepositories'], equals(2));
      expect(stats['repositories'], contains('String'));
      expect(stats['repositories'], contains('int'));
      expect(stats['creationTimes'], isA<Map>());
    });

    test('clear应该清理所有Repository', () {
      const testRepo1 = 'test_repository_1';
      const testRepo2 = 42;
      
      RepositoryLifecycleManager.register<String>(testRepo1);
      RepositoryLifecycleManager.register<int>(testRepo2);
      
      var stats = RepositoryLifecycleManager.getStatistics();
      expect(stats['totalRepositories'], equals(2));
      
      RepositoryLifecycleManager.clear();
      
      stats = RepositoryLifecycleManager.getStatistics();
      expect(stats['totalRepositories'], equals(0));
    });
  });
}
