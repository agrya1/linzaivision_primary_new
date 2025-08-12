import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'database/database_init.dart';
import 'pages/goal_page.dart';
import 'package:linzaivision_primary/theme/app_theme.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/services/api_service.dart';
import 'package:linzaivision_primary/services/storage_service.dart';
import 'package:linzaivision_primary/services/shared_prefs_storage_service.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/app/app_bloc.dart';
import 'package:linzaivision_primary/bloc/app/app_event.dart';
import 'package:linzaivision_primary/repository/goal_repository.dart';
import 'package:linzaivision_primary/database/database_helper.dart';
import 'package:linzaivision_primary/utils/error_handler.dart';
import 'package:linzaivision_primary/repositories/repository_provider.dart';
import 'repository/explore_repository.dart';
import 'repository/search_repository.dart';
import 'repository/auth_repository.dart';
import 'repository/settings_repository.dart';
import 'repository/profile_repository.dart';
import 'bloc/explore/explore_bloc.dart';
import 'bloc/search/search_bloc.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/settings/settings_bloc.dart';
import 'bloc/profile/profile_bloc.dart';
import 'bloc/profile/profile_event.dart';
import 'bloc/component/component_communication_bloc.dart';
import 'routes/app_routes.dart';
import 'routes/app_router.dart';
import 'routes/route_observer.dart';
import 'routes/route_middleware.dart';
import 'routes/route_analytics.dart';
import 'routes/analytics_middleware.dart';
import 'routes/route_params_middleware.dart';
import 'routes/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/use_card/use_card_bloc.dart';

Future<void> main() async {
  // Ensure Flutter binding initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Fix Windows platform EGL errors: Disable hardware acceleration
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    // Set software rendering mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Initialize database (non-Web platforms only)
  if (!kIsWeb) {
    initializeDatabase();
  }

  // 初始化SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 创建StorageService实例
  final storageService = SharedPrefsStorageService(prefs);

  // 初始化路由分析服务
  final routeAnalytics = RouteAnalytics();
  routeAnalytics.init(storageService);

  // 创建路由参数中间件
  final routeParamsMiddleware = RouteParamsMiddleware();

  // 为目标详情页添加参数验证器
  routeParamsMiddleware.addValidator(AppRoutes.goalDetails, (params) {
    if (params is! Map<String, dynamic> || !params.containsKey('goalId')) {
      return ValidationResult.invalid('目标详情页参数必须包含goalId');
    }
    final goalId = params['goalId'];
    if (goalId is! int || goalId <= 0) {
      return ValidationResult.invalid('goalId必须是大于0的整数');
    }
    return ValidationResult.valid();
  });

  // 添加路由中间件
  AppRouter.addMiddleware(RouteLoggerMiddleware());
  AppRouter.addMiddleware(AnalyticsMiddleware(routeAnalytics));
  AppRouter.addMiddleware(routeParamsMiddleware);

  // 初始化认证服务
  try {
    final authService = AuthService();
    await authService.init();
    debugPrint('认证服务初始化成功');
  } catch (e) {
    debugPrint('认证服务初始化失败: $e');
    // 即使认证服务初始化失败，也继续启动应用
  }

  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;

  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    // 创建API服务实例 - 确保全局单例
    final apiService = ApiService();

    // 创建数据库助手实例
    final databaseHelper = DatabaseHelper(isTest: false);

    // 创建AuthService实例
    final authService = AuthService();

    // 初始化Repository提供者
    AppRepositoryProvider.instance.initialize(
      databaseHelper: databaseHelper,
      storageService: storageService,
      authService: authService,
      apiService: apiService,
    );

    // 从Repository提供者获取仓库实例
    final repositoryProvider = AppRepositoryProvider.instance;
    final goalRepository = repositoryProvider.goalRepository;
    final exploreRepository = repositoryProvider.exploreRepository;
    final searchRepository = repositoryProvider.searchRepository;
    final settingsRepository = repositoryProvider.settingsRepository;

    // 创建路由观察者
    final routeObserver = AppRouteObserver([
      RouteLoggerMiddleware(),
      AnalyticsMiddleware(RouteAnalytics()),
      RouteParamsMiddleware(),
    ]);

    return MultiProvider(
      providers: [
        // 先提供ApiService
        Provider<ApiService>.value(value: apiService),
        // 提供数据库助手
        Provider<DatabaseHelper>.value(value: databaseHelper),
        // 提供StorageService
        Provider<StorageService>.value(value: storageService),
        // 提供目标仓库
        Provider<GoalRepository>.value(value: goalRepository),
        Provider<ExploreRepository>.value(value: exploreRepository),
        Provider<SearchRepository>.value(value: searchRepository),
        // 提供设置仓库
        Provider<SettingsRepository>.value(value: settingsRepository),
        // 提供全局访问AuthService的能力
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        // 提供AuthRepository
        Provider<AuthRepository>.value(
            value: repositoryProvider.authRepository),
        // 提供路由分析服务
        Provider<RouteAnalytics>.value(value: RouteAnalytics()),
        // 提供导航服务
        Provider<NavigationService>.value(value: NavigationService()),
        // 提供GoalBloc
        BlocProvider<GoalBloc>(
          create: (context) => GoalBloc(
            repository: context.read<GoalRepository>(),
          ),
        ),
        BlocProvider<ExploreBloc>(
          create: (context) => ExploreBloc(
            exploreRepository: context.read<ExploreRepository>(),
            goalRepository: context.read<GoalRepository>(),
          ),
        ),
        BlocProvider<SearchBloc>(
          create: (context) =>
              SearchBloc(repository: context.read<SearchRepository>()),
        ),
        // 提供AuthBloc
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: context.read<AuthRepository>(),
          )..add(CheckAuthStatusEvent()), // 应用启动时检查登录状态
        ),
        // 提供SettingsBloc
        BlocProvider<SettingsBloc>(
          create: (context) => SettingsBloc(
            repository: context.read<SettingsRepository>(),
          )..add(LoadSettings()), // 应用启动时加载设置
        ),
        // 提供ProfileRepository
        Provider<ProfileRepository>.value(
            value: repositoryProvider.profileRepository),
        // 提供ProfileBloc
        BlocProvider<ProfileBloc>(
          create: (context) => ProfileBloc(
            repository: context.read<ProfileRepository>(),
          )..add(const LoadProfile()), // 应用启动时加载用户资料
        ),
        BlocProvider<UseCardBloc>(
          create: (context) => UseCardBloc(
            goalRepository: context.read<GoalRepository>(),
          ),
        ),
        // 提供ComponentCommunicationBloc - 组件间通信
        BlocProvider<ComponentCommunicationBloc>(
          create: (context) => ComponentCommunicationBloc(
            databaseHelper: context.read<DatabaseHelper>(),
            goalBloc: context.read<GoalBloc>(),
          ),
        ),
        // 提供AppBloc - 应用级状态管理
        BlocProvider<AppBloc>(
          create: (context) => AppBloc(
            goalRepository: context.read<GoalRepository>(),
            authService: context.read<AuthService>(),
            storageService: context.read<StorageService>(),
          )..add(const InitializeApp()), // 应用启动时初始化
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          // 根据设置状态决定主题
          ThemeMode themeMode = ThemeMode.system;

          if (settingsState is SettingsLoaded) {
            if (settingsState.followSystemTheme) {
              themeMode = ThemeMode.system;
            } else {
              themeMode = settingsState.themeMode == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light;
            }
          }

          return ErrorBoundary(
            child: MaterialApp(
              title: '临在意识',
              theme: AppTheme.createTheme(isDark: false),
              darkTheme: AppTheme.createTheme(isDark: true),
              themeMode: themeMode,
              initialRoute: AppRoutes.home,
              onGenerateRoute: AppRouter.generateRoute,
              navigatorKey: NavigationService().navigatorKey,
              navigatorObservers: [routeObserver],
            ),
          );
        },
      ),
    );
  }
}

// 添加一个包装类，用于添加测试入口
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GoalPage(),
      ],
    );
  }
}
