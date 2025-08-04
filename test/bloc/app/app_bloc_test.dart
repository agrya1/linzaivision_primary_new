import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:linzaivision_primary/bloc/app/app_bloc.dart';
import 'package:linzaivision_primary/bloc/app/app_event.dart';
import 'package:linzaivision_primary/bloc/app/app_state.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/services/storage_service.dart';

// 生成Mock类
@GenerateMocks([GoalRepository, AuthService, StorageService])
import 'app_bloc_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock PackageInfo
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'Test App',
            'packageName': 'com.test.app',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return null;
      },
    );
  });
  group('AppBloc', () {
    late AppBloc appBloc;
    late MockGoalRepository mockGoalRepository;
    late MockAuthService mockAuthService;
    late MockStorageService mockStorageService;

    setUp(() {
      mockGoalRepository = MockGoalRepository();
      mockAuthService = MockAuthService();
      mockStorageService = MockStorageService();

      // 设置默认的mock返回值
      when(mockStorageService.getString('theme_mode'))
          .thenAnswer((_) async => 'system');
      when(mockStorageService.getString('language_code'))
          .thenAnswer((_) async => 'zh');
      when(mockStorageService.getBool('debug_mode'))
          .thenAnswer((_) async => false);
      when(mockStorageService.saveString(any, any))
          .thenAnswer((_) async => true);
      when(mockStorageService.saveBool(any, any)).thenAnswer((_) async => true);

      appBloc = AppBloc(
        goalRepository: mockGoalRepository,
        authService: mockAuthService,
        storageService: mockStorageService,
      );
    });

    tearDown(() {
      appBloc.close();
    });

    test('初始状态应该是AppInitial', () {
      expect(appBloc.state, equals(const AppInitial()));
    });

    group('InitializeApp', () {
      blocTest<AppBloc, AppState>(
        '应该发出AppLoading然后AppReady状态',
        build: () => appBloc,
        act: (bloc) => bloc.add(const InitializeApp()),
        expect: () => [
          const AppLoading(message: '正在初始化应用...'),
          isA<AppReady>(),
        ],
        verify: (bloc) {
          final state = bloc.state as AppReady;
          expect(state.themeMode, equals('system'));
          expect(state.languageCode, equals('zh'));
          expect(state.isDebugMode, equals(false));
        },
      );
    });

    group('AppResumed', () {
      blocTest<AppBloc, AppState>(
        '当应用处于AppReady状态时，应该更新生命周期状态',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const AppResumed()),
        expect: () => [
          isA<AppReady>().having(
            (state) => state.lifecycleState,
            'lifecycleState',
            AppLifecycleState.resumed,
          ),
        ],
      );
    });

    group('AppPaused', () {
      blocTest<AppBloc, AppState>(
        '当应用处于AppReady状态时，应该更新生命周期状态',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const AppPaused()),
        expect: () => [
          isA<AppReady>().having(
            (state) => state.lifecycleState,
            'lifecycleState',
            AppLifecycleState.paused,
          ),
        ],
      );
    });

    group('NetworkStatusChanged', () {
      blocTest<AppBloc, AppState>(
        '应该更新网络状态',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const NetworkStatusChanged(true)),
        expect: () => [
          isA<AppReady>().having(
            (state) => state.networkState,
            'networkState',
            NetworkState.connected,
          ),
        ],
      );
    });

    group('ThemeModeChanged', () {
      blocTest<AppBloc, AppState>(
        '应该更新主题模式并保存到存储',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const ThemeModeChanged('dark')),
        expect: () => [
          isA<AppReady>().having(
            (state) => state.themeMode,
            'themeMode',
            'dark',
          ),
        ],
        verify: (bloc) {
          verify(mockStorageService.saveString('theme_mode', 'dark')).called(1);
        },
      );
    });

    group('GlobalError', () {
      blocTest<AppBloc, AppState>(
        '应该设置全局错误信息',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const GlobalError('测试错误', code: 'TEST_ERROR')),
        expect: () => [
          isA<AppReady>()
              .having((state) => state.globalError, 'globalError', '测试错误')
              .having((state) => state.globalErrorCode, 'globalErrorCode',
                  'TEST_ERROR'),
        ],
      );
    });

    group('ClearGlobalError', () {
      blocTest<AppBloc, AppState>(
        '应该清除全局错误信息',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
          globalError: '测试错误',
          globalErrorCode: 'TEST_ERROR',
        ),
        act: (bloc) => bloc.add(const ClearGlobalError()),
        expect: () => [
          isA<AppReady>()
              .having((state) => state.globalError, 'globalError', null)
              .having(
                  (state) => state.globalErrorCode, 'globalErrorCode', null),
        ],
      );
    });

    group('ShowGlobalLoading', () {
      blocTest<AppBloc, AppState>(
        '应该显示全局加载指示器',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
        ),
        act: (bloc) => bloc.add(const ShowGlobalLoading(message: '加载中...')),
        expect: () => [
          isA<AppReady>()
              .having((state) => state.isGlobalLoading, 'isGlobalLoading', true)
              .having((state) => state.globalLoadingMessage,
                  'globalLoadingMessage', '加载中...'),
        ],
      );
    });

    group('HideGlobalLoading', () {
      blocTest<AppBloc, AppState>(
        '应该隐藏全局加载指示器',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now(),
          isGlobalLoading: true,
          globalLoadingMessage: '加载中...',
        ),
        act: (bloc) => bloc.add(const HideGlobalLoading()),
        expect: () => [
          isA<AppReady>()
              .having(
                  (state) => state.isGlobalLoading, 'isGlobalLoading', false)
              .having((state) => state.globalLoadingMessage,
                  'globalLoadingMessage', null),
        ],
      );
    });

    group('SyncAllData', () {
      blocTest<AppBloc, AppState>(
        '应该发出同步状态然后更新最后同步时间',
        build: () => appBloc,
        seed: () => AppReady(
          version: '1.0.0',
          buildNumber: '1',
          lastSyncTime: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        act: (bloc) => bloc.add(const SyncAllData()),
        expect: () => [
          const AppSyncing(syncMessage: '正在同步数据...'),
          isA<AppReady>().having(
            (state) => state.lastSyncTime.isAfter(
              DateTime.now().subtract(const Duration(minutes: 1)),
            ),
            'lastSyncTime updated',
            true,
          ),
        ],
      );
    });
  });
}
