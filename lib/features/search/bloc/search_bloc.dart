import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:rxdart/rxdart.dart'; // For debounce

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final DatabaseHelper _dbHelper;

  SearchBloc({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper,
        super(const SearchState()) {
    on<SearchQueryChanged>(_onSearchQueryChanged, transformer: _debounceSearch());
    on<ClearSearch>(_onClearSearch);
  }

  // Debounce to prevent firing search queries on every keystroke
  EventTransformer<SearchQueryChanged> _debounceSearch<SearchQueryChanged>() {
    return (events, mapper) => events.debounceTime(const Duration(milliseconds: 500)).asyncExpand(mapper);
  }

  Future<void> _onSearchQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(currentQuery: '', searchResults: [], status: SearchStatus.initial, clearErrorMessage: true));
      return;
    }

    emit(state.copyWith(currentQuery: event.query, status: SearchStatus.loading, clearErrorMessage: true));
    try {
      final results = await _dbHelper.searchImages(event.query);
      if (results.isEmpty) {
        emit(state.copyWith(status: SearchStatus.empty, searchResults: []));
      } else {
        emit(state.copyWith(status: SearchStatus.loaded, searchResults: results));
      }
    } catch (e) {
      emit(state.copyWith(status: SearchStatus.error, errorMessage: e.toString(), searchResults: []));
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState()); // Reset to initial state
  }
} 