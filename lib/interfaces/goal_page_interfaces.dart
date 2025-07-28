import 'package:flutter/material.dart';
import '../bloc/goal/goal_state.dart';

/// GoalPage状态接口
/// 
/// 定义GoalPage状态对象需要实现的接口方法，
/// 用于解决GoalPageBlocAdapter和GoalPage之间的循环依赖问题
abstract class GoalPageStateInterface {
  /// 从BLoC状态同步到本地状态的方法
  void syncStateFromBloc(GoalsLoaded state);
  
  /// 获取当前BuildContext
  BuildContext get context;
  
  /// 设置状态的方法
  void setState(VoidCallback fn);
} 