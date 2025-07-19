import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/goal.dart';
import '../../repository/goal_repository.dart';
import '../../models/explore_card.dart';
import '../../repository/explore_repository.dart';

// 视图模式枚举
enum ViewMode { fullScreen, grid }

// 探索事件
abstract class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

class FetchExploreCards extends ExploreEvent {}

class ChangeViewMode extends ExploreEvent {
  final ViewMode viewMode;
  
  const ChangeViewMode(this.viewMode);
  
  @override
  List<Object?> get props => [viewMode];
}

class UseCard extends ExploreEvent {
  final ExploreCard card;
  
  const UseCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

class SaveEditedCard extends ExploreEvent {
  final ExploreCard card;
  
  const SaveEditedCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

// 探索状态
abstract class ExploreState extends Equatable {
  const ExploreState();
  
  @override
  List<Object?> get props => [];
}

class ExploreInitial extends ExploreState {}

class ExploreLoading extends ExploreState {}

class ExploreLoaded extends ExploreState {
  final List<ExploreCard> cards;
  final ViewMode viewMode;
  
  const ExploreLoaded({
    required this.cards,
    required this.viewMode,
  });
  
  @override
  List<Object?> get props => [cards, viewMode];
}

class ExploreError extends ExploreState {
  final String message;
  
  const ExploreError(this.message);
  
  @override
  List<Object?> get props => [message];
}

class CardBeingEdited extends ExploreState {
  final ExploreCard card;
  final List<ExploreCard> allCards;
  final ViewMode viewMode;
  
  const CardBeingEdited({
    required this.card,
    required this.allCards,
    required this.viewMode,
  });
  
  @override
  List<Object?> get props => [card, allCards, viewMode];
}

class CardReadyToSave extends ExploreState {
  final ExploreCard editedCard;
  final List<Goal> availableParents;
  
  const CardReadyToSave({
    required this.editedCard,
    required this.availableParents,
  });
  
  @override
  List<Object?> get props => [editedCard, availableParents];
}

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
      emit(ExploreLoaded(
        cards: currentState.cards,
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
      // 获取可用的父目标列表
      final availableParents = await goalRepository.getGoals(parentId: null);
      
      emit(CardReadyToSave(
        editedCard: event.card,
        availableParents: availableParents,
      ));
    } catch (e) {
      emit(ExploreError('准备保存卡片失败: $e'));
    }
  }
} 