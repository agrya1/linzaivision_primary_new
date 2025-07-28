import 'package:equatable/equatable.dart';
import '../../models/explore_card.dart';
import '../../models/goal.dart';

// 使用卡片事件基类
abstract class UseCardEvent extends Equatable {
  const UseCardEvent();
  
  @override
  List<Object?> get props => [];
}

// 开始使用卡片事件
class StartUseCard extends UseCardEvent {
  final ExploreCard card;
  
  const StartUseCard(this.card);
  
  @override
  List<Object?> get props => [card];
}

// 编辑卡片文本事件
class EditCardText extends UseCardEvent {
  final String text;
  
  const EditCardText(this.text);
  
  @override
  List<Object?> get props => [text];
}

// 选择插入位置事件
class SelectInsertLocation extends UseCardEvent {
  final Goal targetGoal;
  
  const SelectInsertLocation(this.targetGoal);
  
  @override
  List<Object?> get props => [targetGoal];
}

// 确认使用卡片事件
class ConfirmCardUse extends UseCardEvent {
  const ConfirmCardUse();
}

// 取消使用卡片事件
class CancelCardUse extends UseCardEvent {
  const CancelCardUse();
} 