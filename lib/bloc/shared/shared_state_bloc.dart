import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/goal.dart';
import '../../models/explore_card.dart';
import '../../repository/goal_repository.dart';
import '../../repository/explore_repository.dart';

// 共享状态事件
abstract class SharedStateEvent extends Equatable {
  const SharedStateEvent();
  
  @override
  List<Object?> get props => [];
}

// 初始化共享状态
class InitializeSharedState extends SharedStateEvent {
  const InitializeSharedState();
}

// 同步目标数据
class SyncGoalData extends SharedStateEvent {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  
  const SyncGoalData({
    required this.goals,
    required this.allGoals,
    this.currentGoal,
  });
  
  @override
  List<Object?> get props => [goals, allGoals, currentGoal];
}

// 同步探索卡片数据
class SyncExploreData extends SharedStateEvent {
  final List<ExploreCard> cards;
  final ExploreCard? selectedCard;
  
  const SyncExploreData({
    required this.cards,
    this.selectedCard,
  });
  
  @override
  List<Object?> get props => [cards, selectedCard];
}

// 跨页面目标创建
class CrossPageGoalCreated extends SharedStateEvent {
  final Goal goal;
  final String sourcePage; // 'explore' 或 'goal'
  
  const CrossPageGoalCreated({
    required this.goal,
    required this.sourcePage,
  });
  
  @override
  List<Object?> get props => [goal, sourcePage];
}

// 跨页面目标更新
class CrossPageGoalUpdated extends SharedStateEvent {
  final Goal goal;
  final String sourcePage;
  
  const CrossPageGoalUpdated({
    required this.goal,
    required this.sourcePage,
  });
  
  @override
  List<Object?> get props => [goal, sourcePage];
}

// 跨页面目标删除
class CrossPageGoalDeleted extends SharedStateEvent {
  final int goalId;
  final String sourcePage;
  
  const CrossPageGoalDeleted({
    required this.goalId,
    required this.sourcePage,
  });
  
  @override
  List<Object?> get props => [goalId, sourcePage];
}

// 请求数据刷新
class RequestDataRefresh extends SharedStateEvent {
  final String requestingPage; // 请求刷新的页面
  final List<String> dataTypes; // ['goals', 'explore', 'all']
  
  const RequestDataRefresh({
    required this.requestingPage,
    required this.dataTypes,
  });
  
  @override
  List<Object?> get props => [requestingPage, dataTypes];
}

// 共享状态
abstract class SharedState extends Equatable {
  const SharedState();
  
  @override
  List<Object?> get props => [];
}

// 初始状态
class SharedStateInitial extends SharedState {}

// 加载中状态
class SharedStateLoading extends SharedState {}

// 已加载状态
class SharedStateLoaded extends SharedState {
  final List<Goal> goals;
  final List<Goal> allGoals;
  final Goal? currentGoal;
  final List<ExploreCard> exploreCards;
  final ExploreCard? selectedCard;
  final DateTime lastSyncTime;
  final Map<String, DateTime> pageLastUpdateTime; // 记录各页面最后更新时间
  
  const SharedStateLoaded({
    required this.goals,
    required this.allGoals,
    this.currentGoal,
    required this.exploreCards,
    this.selectedCard,
    required this.lastSyncTime,
    required this.pageLastUpdateTime,
  });
  
  @override
  List<Object?> get props => [
    goals,
    allGoals,
    currentGoal,
    exploreCards,
    selectedCard,
    lastSyncTime,
    pageLastUpdateTime,
  ];
  
  SharedStateLoaded copyWith({
    List<Goal>? goals,
    List<Goal>? allGoals,
    Goal? currentGoal,
    List<ExploreCard>? exploreCards,
    ExploreCard? selectedCard,
    DateTime? lastSyncTime,
    Map<String, DateTime>? pageLastUpdateTime,
  }) {
    return SharedStateLoaded(
      goals: goals ?? this.goals,
      allGoals: allGoals ?? this.allGoals,
      currentGoal: currentGoal ?? this.currentGoal,
      exploreCards: exploreCards ?? this.exploreCards,
      selectedCard: selectedCard ?? this.selectedCard,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pageLastUpdateTime: pageLastUpdateTime ?? this.pageLastUpdateTime,
    );
  }
}

// 错误状态
class SharedStateError extends SharedState {
  final String message;
  
  const SharedStateError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// 共享状态BLoC
class SharedStateBloc extends Bloc<SharedStateEvent, SharedState> {
  final GoalRepository goalRepository;
  final ExploreRepository exploreRepository;
  
  SharedStateBloc({
    required this.goalRepository,
    required this.exploreRepository,
  }) : super(SharedStateInitial()) {
    on<InitializeSharedState>(_onInitializeSharedState);
    on<SyncGoalData>(_onSyncGoalData);
    on<SyncExploreData>(_onSyncExploreData);
    on<CrossPageGoalCreated>(_onCrossPageGoalCreated);
    on<CrossPageGoalUpdated>(_onCrossPageGoalUpdated);
    on<CrossPageGoalDeleted>(_onCrossPageGoalDeleted);
    on<RequestDataRefresh>(_onRequestDataRefresh);
  }
  
  Future<void> _onInitializeSharedState(
    InitializeSharedState event,
    Emitter<SharedState> emit,
  ) async {
    emit(SharedStateLoading());
    
    try {
      // 并行加载目标数据和探索卡片数据
      final futures = await Future.wait([
        goalRepository.getGoals(),
        goalRepository.getGoalTree(),
        exploreRepository.getExploreCards(),
      ]);
      
      final goals = futures[0] as List<Goal>;
      final allGoals = futures[1] as List<Goal>;
      final exploreCards = futures[2] as List<ExploreCard>;
      
      emit(SharedStateLoaded(
        goals: goals,
        allGoals: allGoals,
        currentGoal: goals.isNotEmpty ? goals.first : null,
        exploreCards: exploreCards,
        selectedCard: null,
        lastSyncTime: DateTime.now(),
        pageLastUpdateTime: {
          'goal': DateTime.now(),
          'explore': DateTime.now(),
        },
      ));
    } catch (e) {
      emit(SharedStateError('初始化共享状态失败: $e'));
    }
  }
  
  void _onSyncGoalData(
    SyncGoalData event,
    Emitter<SharedState> emit,
  ) {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      final now = DateTime.now();
      
      emit(currentState.copyWith(
        goals: event.goals,
        allGoals: event.allGoals,
        currentGoal: event.currentGoal,
        lastSyncTime: now,
        pageLastUpdateTime: {
          ...currentState.pageLastUpdateTime,
          'goal': now,
        },
      ));
    }
  }
  
  void _onSyncExploreData(
    SyncExploreData event,
    Emitter<SharedState> emit,
  ) {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      final now = DateTime.now();
      
      emit(currentState.copyWith(
        exploreCards: event.cards,
        selectedCard: event.selectedCard,
        lastSyncTime: now,
        pageLastUpdateTime: {
          ...currentState.pageLastUpdateTime,
          'explore': now,
        },
      ));
    }
  }
  
  Future<void> _onCrossPageGoalCreated(
    CrossPageGoalCreated event,
    Emitter<SharedState> emit,
  ) async {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      
      try {
        // 重新加载目标数据以确保一致性
        final goals = await goalRepository.getGoals();
        final allGoals = await goalRepository.getGoalTree();
        final now = DateTime.now();
        
        emit(currentState.copyWith(
          goals: goals,
          allGoals: allGoals,
          currentGoal: event.goal,
          lastSyncTime: now,
          pageLastUpdateTime: {
            ...currentState.pageLastUpdateTime,
            event.sourcePage: now,
            // 同时更新其他页面的时间戳，表示需要刷新
            if (event.sourcePage != 'goal') 'goal': now,
            if (event.sourcePage != 'explore') 'explore': now,
          },
        ));
      } catch (e) {
        emit(SharedStateError('跨页面目标创建同步失败: $e'));
      }
    }
  }
  
  Future<void> _onCrossPageGoalUpdated(
    CrossPageGoalUpdated event,
    Emitter<SharedState> emit,
  ) async {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      
      try {
        // 重新加载目标数据以确保一致性
        final goals = await goalRepository.getGoals();
        final allGoals = await goalRepository.getGoalTree();
        final now = DateTime.now();
        
        emit(currentState.copyWith(
          goals: goals,
          allGoals: allGoals,
          lastSyncTime: now,
          pageLastUpdateTime: {
            ...currentState.pageLastUpdateTime,
            event.sourcePage: now,
            // 同时更新其他页面的时间戳，表示需要刷新
            if (event.sourcePage != 'goal') 'goal': now,
            if (event.sourcePage != 'explore') 'explore': now,
          },
        ));
      } catch (e) {
        emit(SharedStateError('跨页面目标更新同步失败: $e'));
      }
    }
  }
  
  Future<void> _onCrossPageGoalDeleted(
    CrossPageGoalDeleted event,
    Emitter<SharedState> emit,
  ) async {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      
      try {
        // 重新加载目标数据以确保一致性
        final goals = await goalRepository.getGoals();
        final allGoals = await goalRepository.getGoalTree();
        final now = DateTime.now();
        
        // 如果删除的是当前目标，选择新的当前目标
        Goal? newCurrentGoal = currentState.currentGoal;
        if (newCurrentGoal?.id == event.goalId) {
          newCurrentGoal = goals.isNotEmpty ? goals.first : null;
        }
        
        emit(currentState.copyWith(
          goals: goals,
          allGoals: allGoals,
          currentGoal: newCurrentGoal,
          lastSyncTime: now,
          pageLastUpdateTime: {
            ...currentState.pageLastUpdateTime,
            event.sourcePage: now,
            // 同时更新其他页面的时间戳，表示需要刷新
            if (event.sourcePage != 'goal') 'goal': now,
            if (event.sourcePage != 'explore') 'explore': now,
          },
        ));
      } catch (e) {
        emit(SharedStateError('跨页面目标删除同步失败: $e'));
      }
    }
  }
  
  Future<void> _onRequestDataRefresh(
    RequestDataRefresh event,
    Emitter<SharedState> emit,
  ) async {
    if (state is SharedStateLoaded) {
      final currentState = state as SharedStateLoaded;
      
      try {
        final now = DateTime.now();
        List<Goal>? goals;
        List<Goal>? allGoals;
        List<ExploreCard>? exploreCards;
        
        // 根据请求的数据类型刷新相应数据
        if (event.dataTypes.contains('goals') || event.dataTypes.contains('all')) {
          goals = await goalRepository.getGoals();
          allGoals = await goalRepository.getGoalTree();
        }
        
        if (event.dataTypes.contains('explore') || event.dataTypes.contains('all')) {
          exploreCards = await exploreRepository.getExploreCards();
        }
        
        emit(currentState.copyWith(
          goals: goals ?? currentState.goals,
          allGoals: allGoals ?? currentState.allGoals,
          exploreCards: exploreCards ?? currentState.exploreCards,
          lastSyncTime: now,
          pageLastUpdateTime: {
            ...currentState.pageLastUpdateTime,
            event.requestingPage: now,
          },
        ));
      } catch (e) {
        emit(SharedStateError('数据刷新失败: $e'));
      }
    }
  }
}
