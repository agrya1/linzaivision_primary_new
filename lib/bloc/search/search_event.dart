import 'package:equatable/equatable.dart';

/// 搜索事件基类
abstract class SearchEvent extends Equatable {
  const SearchEvent();
  
  @override
  List<Object?> get props => [];
}

/// 执行搜索事件
class PerformSearch extends SearchEvent {
  final String query;
  
  const PerformSearch(this.query);
  
  @override
  List<Object?> get props => [query];
}

/// 清除搜索事件
class ClearSearch extends SearchEvent {}

/// 加载搜索历史事件
class LoadSearchHistory extends SearchEvent {}

/// 添加搜索历史事件
class AddSearchHistory extends SearchEvent {
  final String query;
  
  const AddSearchHistory(this.query);
  
  @override
  List<Object?> get props => [query];
}

/// 清除搜索历史事件
class ClearSearchHistory extends SearchEvent {} 