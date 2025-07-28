import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings/settings_bloc.dart';
import '../pages/goal_page.dart';
import '../pages/explore_page.dart'; // 导入ExplorePage

/// 首页路由决策组件
/// 
/// 根据用户设置决定显示哪个页面作为首页
class HomePageRouter extends StatelessWidget {
  const HomePageRouter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoaded) {
          // 根据用户设置决定首页
          switch (state.homePage) {
            case 'explore':
              return const ExplorePage(); // 使用实际的ExplorePage
            case 'first_goal':
              return const GoalPage();
            default:
              return const GoalPage(); // 默认为第一条意识条目页面
          }
        }
        
        // 加载中或错误状态显示加载页面
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
} 