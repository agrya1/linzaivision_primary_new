import 'package:equatable/equatable.dart';
import '../../models/goal.dart';

/// 搜索状态基类
abstract class SearchState extends Equatable {
  const SearchState();
  
  @override
  List<Object?> get props => [];
}

/// 初始搜索状态
class SearchInitial extends SearchState {}

/// 搜索加载中状态
class SearchLoading extends SearchState {}

/// 搜索结果状态
class SearchResults extends SearchState {
  final List<Goal> results;
  final String query;
  
  const SearchResults({
    required this.results,
    required this.query,
  });
  
  @override
  List<Object?> get props => [results, query];
}

/// 搜索历史状态
class SearchHistoryLoaded extends SearchState {
  final List<String> history;
  
  const SearchHistoryLoaded(this.history);
  
  @override
  List<Object?> get props => [history];
}

/// 搜索错误状态
class SearchError extends SearchState {
  final String message;
  
  const SearchError(this.message);
  
  @override
  List<Object?> get props => [message];
} 