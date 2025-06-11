part of 'folder_bloc.dart';

abstract class FolderEvent extends Equatable {
  const FolderEvent();

  @override
  List<Object?> get props => [];
}

class LoadFolders extends FolderEvent {}

class AddFolderRequested extends FolderEvent {
  // No specific path here, will be picked by user
  const AddFolderRequested();
}

// Event triggered when a folder path has been selected by the user
class FolderPathSelected extends FolderEvent {
  final String path;
  final String name; // Name of the folder directory
  const FolderPathSelected({required this.path, required this.name});

  @override
  List<Object?> get props => [path, name];
}

class DeleteFolder extends FolderEvent {
  final int folderId;
  const DeleteFolder({required this.folderId});

  @override
  List<Object?> get props => [folderId];
}

// Internal event to update folder list after DB changes or progress updates
class _FoldersUpdated extends FolderEvent {
  final List<Folder> folders;
  const _FoldersUpdated(this.folders);

  @override
  List<Object?> get props => [folders];
}

// Event to manually trigger a refresh of folder progress
// This will now cause the BLoC to re-check all folders in an 'indexing' or 'pending_sync' state.
class RefreshFolderProgress extends FolderEvent {}

class SyncAllFolders extends FolderEvent {} 