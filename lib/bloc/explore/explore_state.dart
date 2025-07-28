import 'package:equatable/equatable.dart';
import '../../models/explore_card.dart';
import 'explore_event.dart'; // 导入包含ViewMode枚举的文件

// 探索状态基类
abstract class ExploreState extends Equatable {
  const ExploreState();
  
  @override
  List<Object?> get props => [];
}

// 初始状态
class ExploreInitial extends ExploreState {}

// 加载中状态
class ExploreLoading extends ExploreState {}

// 加载完成状态
class ExploreLoaded extends ExploreState {
  final List<ExploreCard> cards;
  final ViewMode viewMode;
  final String activeCategory;
  final ExploreCard? selectedCard;
  final bool isEditing;
  
  const ExploreLoaded({
    required this.cards,
    this.viewMode = ViewMode.grid,
    this.activeCategory = '推荐',
    this.selectedCard,
    this.isEditing = false,
  });
  
  @override
  List<Object?> get props => [cards, viewMode, activeCategory, selectedCard, isEditing];
  
  // 创建新状态的便捷方法
  ExploreLoaded copyWith({
    List<ExploreCard>? cards,
    ViewMode? viewMode,
    String? activeCategory,
    ExploreCard? selectedCard,
    bool? isEditing,
  }) {
    return ExploreLoaded(
      cards: cards ?? this.cards,
      viewMode: viewMode ?? this.viewMode,
      activeCategory: activeCategory ?? this.activeCategory,
      selectedCard: selectedCard ?? this.selectedCard,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

// 卡片编辑状态
class CardBeingEdited extends ExploreState {
  final ExploreCard card;
  final List<ExploreCard> allCards;
  final ViewMode viewMode;
  final String editedText;
  
  const CardBeingEdited({
    required this.card,
    required this.allCards,
    this.viewMode = ViewMode.fullScreen,
    this.editedText = '',
  });
  
  @override
  List<Object?> get props => [card, allCards, viewMode, editedText];
  
  // 创建新状态的便捷方法
  CardBeingEdited copyWith({
    ExploreCard? card,
    List<ExploreCard>? allCards,
    ViewMode? viewMode,
    String? editedText,
  }) {
    return CardBeingEdited(
      card: card ?? this.card,
      allCards: allCards ?? this.allCards,
      viewMode: viewMode ?? this.viewMode,
      editedText: editedText ?? this.editedText,
    );
  }
}

// 错误状态
class ExploreError extends ExploreState {
  final String message;
  
  const ExploreError(this.message);
  
  @override
  List<Object?> get props => [message];
} 