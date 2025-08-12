import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:linzaivision_primary/bloc/app_init/app_init_bloc.dart';
import 'package:linzaivision_primary/bloc/app_init/app_init_state.dart';
import 'package:linzaivision_primary/bloc/app_init/app_init_event.dart';
import 'package:linzaivision_primary/bloc/loading/loading_bloc.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/services/storage_service.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/repository/explore_repository.dart';
import 'package:linzaivision_primary/repository/settings_repository.dart';
import 'package:linzaivision_primary/repository/profile_repository.dart';
import 'package:linzaivision_primary/repository/auth_repository.dart';

// 测试用的Mock实现
class MockDatabaseHelper implements DatabaseHelper {
  @override
  Future<void> initDatabase() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // 其他方法的简化实现
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageService implements StorageService {
  @override
  Future<void> init() async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthService implements AuthService {
  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 75));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoalRepository implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockExploreRepository implements ExploreRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsRepository implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppInitBloc Tests', () {
    late AppInitBloc appInitBloc;
    late LoadingBloc loadingBloc;
    late MockDatabaseHelper mockDatabaseHelper;
    late MockStorageService mockStorageService;
    late MockAuthService mockAuthService;
    late MockGoalRepository mockGoalRepository;
    late MockExploreRepository mockExploreRepository;
    late MockSettingsRepository mockSettingsRepository;
    late MockProfileRepository mockProfileRepository;
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      // 创建Mock依赖
      mockDatabaseHelper = MockDatabaseHelper();
      mockStorageService = MockStorageService();
      mockAuthService = MockAuthService();
      mockGoalRepository = MockGoalRepository();
      mockExploreRepository = MockExploreRepository();
      mockSettingsRepository = MockSettingsRepository();
      mockProfileRepository = MockProfileRepository();
      mockAuthRepository = MockAuthRepository();

      // 创建LoadingBloc
      loadingBloc = LoadingBloc();

      // 创建AppInitBloc
      appInitBloc = AppInitBloc(
        loadingBloc: loadingBloc,
        databaseHelper: mockDatabaseHelper,
        storageService: mockStorageService,
        authService: mockAuthService,
        goalRepository: mockGoalRepository,
        exploreRepository: mockExploreRepository,
        settingsRepository: mockSettingsRepository,
        profileRepository: mockProfileRepository,
        authRepository: mockAuthRepository,
      );
    });

    tearDown(() {
      appInitBloc.close();
      loadingBloc.close();
    });

    test('初始状态应该是AppInitInitial', () {
      expect(appInitBloc.state, isA<AppInitInitial>());
    });

    blocTest<AppInitBloc, AppInitState>(
      '开始初始化应该发出AppInitInProgress状态',
      build: () => appInitBloc,
      act: (bloc) => bloc.add(const StartAppInitialization()),
      expect: () => [
        isA<AppInitInProgress>(),
      ],
    );

    blocTest<AppInitBloc, AppInitState>(
      '重试初始化应该重新开始初始化流程',
      build: () => appInitBloc,
      act: (bloc) {
        bloc.add(const StartAppInitialization());
        bloc.add(const RetryInitialization());
      },
      expect: () => [
        isA<AppInitInProgress>(),
        isA<AppInitInProgress>(),
      ],
    );

    blocTest<AppInitBloc, AppInitState>(
      '取消初始化应该发出AppInitFailure状态',
      build: () => appInitBloc,
      act: (bloc) {
        bloc.add(const StartAppInitialization());
        bloc.add(const CancelInitialization(reason: '测试取消'));
      },
      expect: () => [
        isA<AppInitInProgress>(),
        isA<AppInitFailure>(),
      ],
    );

    test('AppInitInProgress状态应该包含正确的阶段信息', () {
      final state = AppInitInProgress.now(
        currentPhase: AppInitPhase.infrastructure,
        currentMessage: '初始化基础设施',
        overallProgress: 0.2,
      );

      expect(state.currentPhase, equals(AppInitPhase.infrastructure));
      expect(state.currentMessage, equals('初始化基础设施'));
      expect(state.overallProgress, equals(0.2));
      expect(state.phaseDescription, equals('初始化基础设施...'));
      expect(state.phaseWeight, equals(0.2));
    });

    test('AppInitFailure状态应该包含正确的错误信息', () {
      const state = AppInitFailure(
        error: '测试错误',
        failedPhase: AppInitPhase.coreData,
        failedTask: 'test_task',
        isRetryable: true,
      );

      expect(state.error, equals('测试错误'));
      expect(state.failedPhase, equals(AppInitPhase.coreData));
      expect(state.failedTask, equals('test_task'));
      expect(state.isRetryable, isTrue);
      expect(state.userFriendlyMessage, equals('核心数据加载失败，请检查网络连接'));
      expect(state.severity, isA<ErrorSeverity>());
      expect(state.recoveryActions, isNotEmpty);
    });

    test('AppInitSuccess状态应该包含统计信息', () {
      final state = AppInitSuccess(
        initializationData: {'test': 'data'},
        totalDuration: const Duration(seconds: 5),
        completedTasks: ['task1', 'task2', 'task3'],
        taskDurations: {
          'task1': const Duration(seconds: 1),
          'task2': const Duration(seconds: 2),
          'task3': const Duration(seconds: 2),
        },
      );

      expect(state.initializationData, equals({'test': 'data'}));
      expect(state.totalDuration, equals(const Duration(seconds: 5)));
      expect(state.completedTasks.length, equals(3));
      expect(state.statistics['totalTasks'], equals(3));
      expect(state.statistics['totalDuration'], equals(5000));
      expect(
          state.statistics['averageTaskDuration'], equals(1666.6666666666667));
    });

    test('AppInitRetrying状态应该正确处理重试逻辑', () {
      final retryAt = DateTime.now().add(const Duration(seconds: 3));
      final state = AppInitRetrying(
        retryCount: 2,
        lastError: '连接失败',
        retryPhase: AppInitPhase.userData,
        retryDelay: const Duration(seconds: 3),
        retryAt: retryAt,
      );

      expect(state.retryCount, equals(2));
      expect(state.lastError, equals('连接失败'));
      expect(state.retryPhase, equals(AppInitPhase.userData));
      expect(state.retryDelay, equals(const Duration(seconds: 3)));
      expect(state.retryAt, equals(retryAt));

      // 测试剩余延迟计算
      expect(state.remainingDelay.inSeconds, greaterThanOrEqualTo(0));
    });

    group('AppInitPhase枚举测试', () {
      test('阶段顺序应该正确', () {
        expect(AppInitPhase.notStarted.index, equals(0));
        expect(AppInitPhase.infrastructure.index, equals(1));
        expect(AppInitPhase.coreData.index, equals(2));
        expect(AppInitPhase.userData.index, equals(3));
        expect(AppInitPhase.services.index, equals(4));
        expect(AppInitPhase.completed.index, equals(5));
        expect(AppInitPhase.failed.index, equals(6));
      });
    });

    group('ErrorSeverity枚举测试', () {
      test('错误严重程度应该正确分类', () {
        expect(
            ErrorSeverity.critical.index, lessThan(ErrorSeverity.high.index));
        expect(ErrorSeverity.high.index, lessThan(ErrorSeverity.medium.index));
        expect(ErrorSeverity.medium.index, lessThan(ErrorSeverity.low.index));
      });
    });

    test('事件的props应该正确实现', () {
      const event1 = StartAppInitialization();
      const event2 = StartAppInitialization(forceRestart: true);
      const event3 = RetryInitialization();

      expect(event1.props,
          equals([false, const <String, dynamic>{}, const <String>[]]));
      expect(event2.props,
          equals([true, const <String, dynamic>{}, const <String>[]]));
      expect(event3.props,
          equals([null, const <String, dynamic>{}, const <String>[]]));
    });

    test('状态的props应该正确实现', () {
      const state1 = AppInitInitial();
      const state2 = AppInitInitial();
      final state3 = AppInitInProgress.now(
        currentPhase: AppInitPhase.infrastructure,
        currentMessage: '测试',
        overallProgress: 0.5,
      );

      expect(state1.props, equals(state2.props));
      expect(state1, equals(state2));
      expect(state3.props, isNotEmpty);
    });
  });
}
