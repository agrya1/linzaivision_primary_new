import 'package:equatable/equatable.dart';
import '../../models/explore_card.dart';
import '../../models/goal.dart';

// 使用卡片状态基类
abstract class UseCardState extends Equatable {
  const UseCardState();
  
  @override
  List<Object?> get props => [];
}

// 初始状态
class UseCardInitial extends UseCardState {}

// 编辑卡片文本状态
class EditingCardText extends UseCardState {
  final ExploreCard card;
  final String text;
  
  const EditingCardText({
    required this.card,
    this.text = '',
  });
  
  @override
  List<Object?> get props => [card, text];
  
  EditingCardText copyWith({
    ExploreCard? card,
    String? text,
  }) {
    return EditingCardText(
      card: card ?? this.card,
      text: text ?? this.text,
    );
  }
}

// 选择插入位置状态
class SelectingInsertLocation extends UseCardState {
  final ExploreCard card;
  final String editedText;
  final List<Goal> availableGoals;
  
  const SelectingInsertLocation({
    required this.card,
    required this.editedText,
    required this.availableGoals,
  });
  
  @override
  List<Object?> get props => [card, editedText, availableGoals];
}

// 卡片使用完成状态
class CardUseCompleted extends UseCardState {
  final Goal createdGoal;
  final Goal parentGoal;
  
  const CardUseCompleted({
    required this.createdGoal,
    required this.parentGoal,
  });
  
  @override
  List<Object?> get props => [createdGoal, parentGoal];
}

// 错误状态
class UseCardError extends UseCardState {
  final String message;
  
  const UseCardError(this.message);
  
  @override
  List<Object?> get props => [message];
} 