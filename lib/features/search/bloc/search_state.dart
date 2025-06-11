part of 'search_bloc.dart';

enum SearchStatus { initial, loading, loaded, error, empty }

class SearchState extends Equatable {
  final String currentQuery;
  final List<ImageMetadata> searchResults;
  final SearchStatus status;
  final String? errorMessage;

  const SearchState({
    this.currentQuery = '',
    this.searchResults = const [],
    this.status = SearchStatus.initial,
    this.errorMessage,
  });

  SearchState copyWith({
    String? currentQuery,
    List<ImageMetadata>? searchResults,
    SearchStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SearchState(
      currentQuery: currentQuery ?? this.currentQuery,
      searchResults: searchResults ?? this.searchResults,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [currentQuery, searchResults, status, errorMessage];
} 