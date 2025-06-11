import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:mosaic_search/models/folder_model.dart';
import 'package:rxdart/rxdart.dart';

part 'folder_view_event.dart';
part 'folder_view_state.dart';

class FolderViewBloc extends Bloc<FolderViewEvent, FolderViewState> {
  final DatabaseHelper _databaseHelper;
  late int _currentFolderId; // To store the ID of the folder being viewed

  FolderViewBloc({required DatabaseHelper databaseHelper}) 
      : _databaseHelper = databaseHelper,
        super(const FolderViewState()) {
    on<LoadFolderContent>(_onLoadFolderContent);
    on<SearchInFolderChanged>(_onSearchInFolderChanged, transformer: _debounceEvent());
    on<ClearFolderSearch>(_onClearFolderSearch);
  }

  EventTransformer<Event> _debounceEvent<Event>() {
    return (events, mapper) => events.debounceTime(const Duration(milliseconds: 300)).asyncExpand(mapper);
  }

  Future<void> _onLoadFolderContent(LoadFolderContent event, Emitter<FolderViewState> emit) async {
    _currentFolderId = event.folderId;
    emit(state.copyWith(status: FolderViewStatus.loading, currentFolder: null, images: []));
    try {
      final folder = await _databaseHelper.getFolderById(_currentFolderId);
      if (folder == null) {
        emit(state.copyWith(status: FolderViewStatus.error, errorMessage: 'Folder not found.'));
        return;
      }
      final images = await _databaseHelper.getAllImagesInFolder(_currentFolderId);
      emit(state.copyWith(status: FolderViewStatus.loaded, images: images, currentFolder: folder, clearSearchQuery: true));
    } catch (e) {
      emit(state.copyWith(status: FolderViewStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onSearchInFolderChanged(SearchInFolderChanged event, Emitter<FolderViewState> emit) async {
    if (event.query.isEmpty) {
      add(ClearFolderSearch());
      return;
    }
    emit(state.copyWith(status: FolderViewStatus.loading, currentSearchQuery: event.query));
    try {
      // This new DB method will be created in the next step
      final images = await _databaseHelper.searchImagesInFolder(folderId: _currentFolderId, searchTerm: event.query);
      emit(state.copyWith(status: FolderViewStatus.loaded, images: images));
    } catch (e) {
      emit(state.copyWith(status: FolderViewStatus.error, errorMessage: e.toString(), images: []));
    }
  }

  Future<void> _onClearFolderSearch(ClearFolderSearch event, Emitter<FolderViewState> emit) async {
    emit(state.copyWith(status: FolderViewStatus.loading, clearSearchQuery: true, images: []));
    try {
      final images = await _databaseHelper.getAllImagesInFolder(_currentFolderId);
      emit(state.copyWith(status: FolderViewStatus.loaded, images: images));
    } catch (e) {
      emit(state.copyWith(status: FolderViewStatus.error, errorMessage: e.toString()));
    }
  }
} 