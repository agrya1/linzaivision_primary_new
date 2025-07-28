import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/goal.dart';
import '../../repository/goal_repository.dart';
import '../../repository/explore_repository.dart';
import 'explore_event.dart';
import 'explore_state.dart';

// 探索BLoC
class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  final ExploreRepository exploreRepository;
  final GoalRepository goalRepository;
  
  ExploreBloc({
    required this.exploreRepository,
    required this.goalRepository,
  }) : super(ExploreInitial()) {
    on<FetchExploreCards>(_onFetchExploreCards);
    on<ChangeViewMode>(_onChangeViewMode);
    on<UseCard>(_onUseCard);
    on<SaveEditedCard>(_onSaveEditedCard);
    on<SelectCard>(_onSelectCard);
    on<StartUsingCard>(_onStartUsingCard);
    on<ChangeCategory>(_onChangeCategory);
  }
  
  Future<void> _onFetchExploreCards(FetchExploreCards event, Emitter<ExploreState> emit) async {
    emit(ExploreLoading());
    try {
      final cards = await exploreRepository.getExploreCards();
      emit(ExploreLoaded(
        cards: cards,
        viewMode: ViewMode.grid, // 默认网格视图
      ));
    } catch (e) {
      emit(ExploreError('加载探索卡片失败: $e'));
    }
  }
  
  void _onChangeViewMode(ChangeViewMode event, Emitter<ExploreState> emit) {
    if (state is ExploreLoaded) {
      final currentState = state as ExploreLoaded;
      emit(currentState.copyWith(
        viewMode: event.viewMode,
      ));
    }
  }
  
  void _onUseCard(UseCard event, Emitter<ExploreState> emit) {
    if (state is ExploreLoaded) {
      final currentState = state as ExploreLoaded;
      emit(CardBeingEdited(
        card: event.card,
        allCards: currentState.cards,
        viewMode: currentState.viewMode,
      ));
    }
  }
  
  Future<void> _onSaveEditedCard(SaveEditedCard event, Emitter<ExploreState> emit) async {
    try {
      // 创建一个新目标
      final goal = Goal(
        title: event.card.title,
        description: event.editedText,
        imagePath: event.card.imagePath,
        createdTime: DateTime.now(),
      );
      
      // 保存到数据库
      await goalRepository.insertGoal(goal);
      
      // 返回到浏览状态
      if (state is CardBeingEdited) {
        final currentState = state as CardBeingEdited;
        emit(ExploreLoaded(
          cards: currentState.allCards,
          viewMode: currentState.viewMode,
        ));
      }
    } catch (e) {
      emit(ExploreError('保存卡片失败: $e'));
    }
  }
  
  void _onSelectCard(SelectCard event, Emitter<ExploreState> emit) {
    if (state is ExploreLoaded) {
      final currentState = state as ExploreLoaded;
      emit(currentState.copyWith(
        selectedCard: event.card,
      ));
    }
  }
  
  void _onStartUsingCard(StartUsingCard event, Emitter<ExploreState> emit) {
    if (state is ExploreLoaded) {
      final currentState = state as ExploreLoaded;
      emit(CardBeingEdited(
        card: event.card,
        allCards: currentState.cards,
        viewMode: ViewMode.fullScreen,
      ));
    }
  }
  
  void _onChangeCategory(ChangeCategory event, Emitter<ExploreState> emit) {
    if (state is ExploreLoaded) {
      final currentState = state as ExploreLoaded;
      emit(currentState.copyWith(
        activeCategory: event.category,
      ));
      
      // 在实际应用中，可能需要根据分类重新加载卡片
      add(FetchExploreCards());
    }
  }
} 