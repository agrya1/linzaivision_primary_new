import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/search_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

/// 搜索BLoC
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository repository;
  
  SearchBloc({required this.repository}) : super(SearchInitial()) {
    on<PerformSearch>(_onPerformSearch);
    on<ClearSearch>(_onClearSearch);
    on<LoadSearchHistory>(_onLoadSearchHistory);
    on<AddSearchHistory>(_onAddSearchHistory);
    on<ClearSearchHistory>(_onClearSearchHistory);
  }
  
  /// 处理执行搜索事件
  Future<void> _onPerformSearch(PerformSearch event, Emitter<SearchState> emit) async {
    if (event.query.isEmpty) {
      emit(const SearchResults(results: [], query: ''));
      return;
    }
    
    emit(SearchLoading());
    
    try {
      final results = await repository.searchGoals(event.query);
      emit(SearchResults(results: results, query: event.query));
      
      // 添加到搜索历史
      add(AddSearchHistory(event.query));
    } catch (e) {
      emit(SearchError('搜索失败: $e'));
    }
  }
  
  /// 处理清除搜索事件
  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchResults(results: [], query: ''));
  }
  
  /// 处理加载搜索历史事件
  Future<void> _onLoadSearchHistory(LoadSearchHistory event, Emitter<SearchState> emit) async {
    try {
      final history = await repository.getSearchHistory();
      emit(SearchHistoryLoaded(history));
    } catch (e) {
      emit(SearchError('加载搜索历史失败: $e'));
    }
  }
  
  /// 处理添加搜索历史事件
  Future<void> _onAddSearchHistory(AddSearchHistory event, Emitter<SearchState> emit) async {
    try {
      await repository.addSearchHistory(event.query);
      
      // 重新加载搜索历史
      add(LoadSearchHistory());
    } catch (e) {
      emit(SearchError('添加搜索历史失败: $e'));
    }
  }
  
  /// 处理清除搜索历史事件
  Future<void> _onClearSearchHistory(ClearSearchHistory event, Emitter<SearchState> emit) async {
    try {
      await repository.clearSearchHistory();
      emit(const SearchHistoryLoaded([]));
    } catch (e) {
      emit(SearchError('清除搜索历史失败: $e'));
    }
  }
} 