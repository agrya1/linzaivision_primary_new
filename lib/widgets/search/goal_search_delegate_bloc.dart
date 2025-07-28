import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/goal.dart';
import '../../bloc/search/search_bloc.dart';
import '../../bloc/search/search_event.dart';
import '../../bloc/search/search_state.dart';

/// 基于BLoC的目标搜索代理
class GoalSearchDelegateBloc extends SearchDelegate<Goal?> {
  final SearchBloc searchBloc;

  GoalSearchDelegateBloc(this.searchBloc) {
    // 初始化时加载搜索历史
    searchBloc.add(LoadSearchHistory());
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          searchBloc.add(ClearSearch());
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // 执行搜索
    if (query.isNotEmpty) {
      searchBloc.add(PerformSearch(query));
    }
    
    return _buildSearchResultsWithBloc();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // 如果查询为空，显示搜索历史
    if (query.isEmpty) {
      return _buildSearchHistoryWithBloc();
    }
    
    // 否则执行搜索
    searchBloc.add(PerformSearch(query));
    return _buildSearchResultsWithBloc();
  }

  /// 使用BLoC构建搜索结果
  Widget _buildSearchResultsWithBloc() {
    return BlocBuilder<SearchBloc, SearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is SearchResults) {
          final results = state.results;
          
          if (results.isEmpty) {
            return const Center(
              child: Text('没有找到匹配的目标'),
            );
          }
          
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(results[index].title),
                subtitle: Text(
                  results[index].description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => close(context, results[index]),
              );
            },
          );
        } else if (state is SearchError) {
          return Center(
            child: Text('搜索出错: ${state.message}'),
          );
        } else {
          return const Center(
            child: Text('请输入搜索关键词'),
          );
        }
      },
    );
  }

  /// 使用BLoC构建搜索历史
  Widget _buildSearchHistoryWithBloc() {
    return BlocBuilder<SearchBloc, SearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        if (state is SearchHistoryLoaded) {
          final history = state.history;
          
          if (history.isEmpty) {
            return const Center(
              child: Text('没有搜索历史'),
            );
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '搜索历史',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        searchBloc.add(ClearSearchHistory());
                      },
                      child: const Text('清除'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(history[index]),
                      onTap: () {
                        query = history[index];
                        searchBloc.add(PerformSearch(query));
                        showResults(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
} 