import 'dart:async';
import 'dart:io'; // Added import for Platform
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart'; // Import for ListEquality
import 'package:file_picker/file_picker.dart';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/core/permissions/permission_service.dart';
import 'package:mosaic_search/models/folder_model.dart';
import 'package:workmanager/workmanager.dart';
import 'package:mosaic_search/core/background_services/background_indexing_service.dart';
import 'package:mosaic_search/core/folder_sync_service.dart';
import 'package:path/path.dart' as p; // Added for p.basename

part 'folder_event.dart';
part 'folder_state.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final DatabaseHelper _databaseHelper;
  final PermissionService _permissionService;
  final FolderSyncService _folderSyncService;
  Timer? _progressTimer;

  FolderBloc({
    required DatabaseHelper databaseHelper, 
    required PermissionService permissionService, 
    required FolderSyncService folderSyncService
  }) : _databaseHelper = databaseHelper,
       _permissionService = permissionService,
       _folderSyncService = folderSyncService,
       super(const FolderState()) {
    on<LoadFolders>(_onLoadFolders);
    on<AddFolderRequested>(_onAddFolderRequested);
    on<FolderPathSelected>(_onFolderPathSelected);
    on<DeleteFolder>(_onDeleteFolder);
    on<_FoldersUpdated>(_onFoldersUpdated);
    on<RefreshFolderProgress>(_onRefreshFolderProgress);
    on<SyncAllFolders>(_onSyncAllFolders);

    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state.folders.isEmpty || state.folders.any((f) => 
          f.status != 'ready' && 
          f.status != 'error_path_not_found' && 
          f.status != 'error_listing_files' && 
          f.status != 'error')) {
        add(RefreshFolderProgress());
      }
    });
  }

  @override
  Future<void> close() {
    _progressTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadFolders(LoadFolders event, Emitter<FolderState> emit) async {
    emit(state.copyWith(status: FolderStatus.loading));
    try {
      final folders = await _databaseHelper.getAllFolders();
      emit(state.copyWith(status: FolderStatus.loaded, folders: folders));
      if (folders.isNotEmpty) {
        add(SyncAllFolders());
      }
    } catch (e) {
      emit(state.copyWith(status: FolderStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onAddFolderRequested(AddFolderRequested event, Emitter<FolderState> emit) async {
    emit(state.copyWith(status: FolderStatus.selecting, clearErrorMessage: true));
    bool permissionGranted = await _permissionService.requestStoragePermission();
    if (!permissionGranted) {
      emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Storage permission denied.'));
      return;
    }
    
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Folder to Import',
      );
      if (selectedDirectory != null) {
        final directoryName = p.basename(selectedDirectory);
        add(FolderPathSelected(path: selectedDirectory, name: directoryName));
      } else {
        emit(state.copyWith(status: FolderStatus.loaded));
      }
    } catch (e) {
      emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Error picking folder: ${e.toString()}'));
    }
  }

  Future<void> _onFolderPathSelected(FolderPathSelected event, Emitter<FolderState> emit) async {
    emit(state.copyWith(status: FolderStatus.adding));
    final Folder newFolder = Folder(
      path: event.path,
      name: event.name,
      status: 'pending',
      totalImages: 0,
      indexedImages: 0
    );

    try {
      final existingFolder = await _databaseHelper.getFolderByPath(event.path);
      if (existingFolder != null) {
        emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Folder already imported.'));
        final folders = await _databaseHelper.getAllFolders();
        emit(state.copyWith(status: FolderStatus.loaded, folders: folders));
        return;
      }

      int folderId = await _databaseHelper.insertFolder(newFolder);
      if (folderId == 0) {
        emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Failed to add folder (DB error or already exists).'));
        final folders = await _databaseHelper.getAllFolders();
        emit(state.copyWith(status: FolderStatus.loaded, folders: folders));
        return;
      }

      final allFolders = await _databaseHelper.getAllFolders();
      emit(state.copyWith(status: FolderStatus.loaded, folders: allFolders));
      
      final folderToSync = allFolders.firstWhere((f) => f.id == folderId, orElse: () => newFolder.copyWith(id: folderId));
      await _folderSyncService.syncFolder(folderToSync);

      final refreshedFolders = await _databaseHelper.getAllFolders();
      emit(state.copyWith(status: FolderStatus.loaded, folders: refreshedFolders));

    } catch (e) {
      emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Failed to save or sync folder: ${e.toString()}'));
      final folders = await _databaseHelper.getAllFolders();
      emit(state.copyWith(status: FolderStatus.loaded, folders: folders));
    }
  }

  Future<void> _onDeleteFolder(DeleteFolder event, Emitter<FolderState> emit) async {
    emit(state.copyWith(status: FolderStatus.deleting));
    try {
      await _databaseHelper.deleteFolder(event.folderId);
      final folders = await _databaseHelper.getAllFolders();
      emit(state.copyWith(status: FolderStatus.loaded, folders: folders));
    } catch (e) {
      emit(state.copyWith(status: FolderStatus.error, errorMessage: 'Failed to delete folder: ${e.toString()}'));
    }
  }

  Future<void> _onFoldersUpdated(_FoldersUpdated event, Emitter<FolderState> emit) async {
    emit(state.copyWith(folders: event.folders, status: FolderStatus.loaded));
  }

  Future<void> _onRefreshFolderProgress(RefreshFolderProgress event, Emitter<FolderState> emit) async {
    try {
      final List<Folder> dbFolders = await _databaseHelper.getAllFolders();
      
      if (!const ListEquality().equals(dbFolders, state.folders)) {
        print("[FolderBloc] RefreshFolderProgress: Changes detected, emitting new state.");
        for(var i=0; i<dbFolders.length; i++){
          if(i < state.folders.length){
            if(dbFolders[i] != state.folders[i]){
              print("Diff at index $i: DB: ${dbFolders[i]}, State: ${state.folders[i]}");
            }
          } else {
            print("Diff at index $i: DB: ${dbFolders[i]}, State: <no corresponding element>");
          }
        }
        emit(state.copyWith(folders: List<Folder>.from(dbFolders), status: FolderStatus.loaded));
      } else {
        // print("[FolderBloc] RefreshFolderProgress: No changes detected.");
      }
    } catch (e) {
      print("[FolderBloc] Error refreshing folder progress: $e");
    }
  }

  Future<void> _onSyncAllFolders(SyncAllFolders event, Emitter<FolderState> emit) async {
    print('[FolderBloc] Starting SyncAllFolders');
    List<Folder> foldersToSync = List.from(state.folders);
    if (foldersToSync.isEmpty) {
      foldersToSync = await _databaseHelper.getAllFolders();
      if (foldersToSync.isEmpty) {
        print('[FolderBloc] SyncAllFolders: No folders to sync.');
        return;
      }
      emit(state.copyWith(folders: List<Folder>.from(foldersToSync), status: FolderStatus.loaded));
    }
    
    bool anyFolderChangedBySync = false;
    for (Folder folder in foldersToSync) {
      if (folder.id != null) {
        try {
          await _folderSyncService.syncFolder(folder, onProgress: (status, total, changed) {
            print('[FolderBloc] Sync progress for ${folder.name}: $status, total: $total, changed: $changed');
            if (changed > 0) anyFolderChangedBySync = true;
          });
        } catch (e) {
          print('[FolderBloc] Error syncing folder ${folder.name}: $e');
        }
      }
    }
    final latestFolders = await _databaseHelper.getAllFolders();
    emit(state.copyWith(folders: List<Folder>.from(latestFolders), status: FolderStatus.loaded));
    print('[FolderBloc] Finished SyncAllFolders. Emitted latest folders.');
  }
} 