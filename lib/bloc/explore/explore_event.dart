import 'package:equatable/equatable.dart';
import '../../models/explore_card.dart';

// 视图模式枚举
enum ViewMode { fullScreen, grid }

// 探索事件基类
abstract class ExploreEvent extends Equatable {
  const ExploreEvent();
  
  @override
  List<Object?> get props => [];
}

// 获取探索卡片事件
class FetchExploreCards extends ExploreEvent {}

// 切换视图模式事件
class ChangeViewMode extends ExploreEvent {
  final ViewMode viewMode;
  
  const ChangeViewMode(this.viewMode);
  
  @override
  List<Object?> get props => [viewMode];
}

// 使用卡片事件
class UseCard extends ExploreEvent {
  final ExploreCard card;
  
  const UseCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

// 保存编辑后的卡片事件
class SaveEditedCard extends ExploreEvent {
  final ExploreCard card;
  final String editedText;
  
  const SaveEditedCard({
    required this.card,
    required this.editedText,
  });
  
  @override
  List<Object?> get props => [card, editedText];
}

// 选择卡片事件
class SelectCard extends ExploreEvent {
  final ExploreCard card;
  
  const SelectCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

// 开始使用卡片事件
class StartUsingCard extends ExploreEvent {
  final ExploreCard card;
  
  const StartUsingCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

// 切换分类事件
class ChangeCategory extends ExploreEvent {
  final String category;
  
  const ChangeCategory(this.category);
  
  @override
  List<Object?> get props => [category];
} 