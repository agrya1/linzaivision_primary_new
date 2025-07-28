import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/goal_repository.dart';
import '../../models/goal.dart';
import 'use_card_event.dart';
import 'use_card_state.dart';

// 使用卡片BLoC
class UseCardBloc extends Bloc<UseCardEvent, UseCardState> {
  final GoalRepository goalRepository;
  
  UseCardBloc({
    required this.goalRepository,
  }) : super(UseCardInitial()) {
    on<StartUseCard>(_onStartUseCard);
    on<EditCardText>(_onEditCardText);
    on<SelectInsertLocation>(_onSelectInsertLocation);
    on<ConfirmCardUse>(_onConfirmCardUse);
    on<CancelCardUse>(_onCancelCardUse);
  }
  
  void _onStartUseCard(StartUseCard event, Emitter<UseCardState> emit) {
    emit(EditingCardText(
      card: event.card,
      text: event.card.description,
    ));
  }
  
  void _onEditCardText(EditCardText event, Emitter<UseCardState> emit) {
    if (state is EditingCardText) {
      final currentState = state as EditingCardText;
      emit(currentState.copyWith(
        text: event.text,
      ));
    }
  }
  
  Future<void> _onSelectInsertLocation(SelectInsertLocation event, Emitter<UseCardState> emit) async {
    if (state is EditingCardText) {
      final currentState = state as EditingCardText;
      
      try {
        // 获取可用的目标列表
        final availableGoals = await goalRepository.getGoalTree();
        
        emit(SelectingInsertLocation(
          card: currentState.card,
          editedText: currentState.text,
          availableGoals: availableGoals,
        ));
      } catch (e) {
        emit(UseCardError('获取目标列表失败: $e'));
      }
    }
  }
  
  Future<void> _onConfirmCardUse(ConfirmCardUse event, Emitter<UseCardState> emit) async {
    if (state is SelectingInsertLocation) {
      final currentState = state as SelectingInsertLocation;
      final targetGoal = currentState.availableGoals.first; // 默认使用第一个目标，实际应用中应该是用户选择的目标
      
      try {
        // 创建新目标
        final newGoal = Goal(
          title: currentState.card.title,
          description: currentState.editedText,
          imagePath: currentState.card.imagePath,
          createdTime: DateTime.now(),
          parentId: targetGoal.id,
        );
        
        // 保存到数据库
        final goalId = await goalRepository.insertGoal(newGoal);
        newGoal.id = goalId;
        
        // 更新状态
        emit(CardUseCompleted(
          createdGoal: newGoal,
          parentGoal: targetGoal,
        ));
      } catch (e) {
        emit(UseCardError('创建目标失败: $e'));
      }
    }
  }
  
  void _onCancelCardUse(CancelCardUse event, Emitter<UseCardState> emit) {
    emit(UseCardInitial());
  }
} 