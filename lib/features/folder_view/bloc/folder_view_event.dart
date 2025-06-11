part of 'folder_view_bloc.dart';

abstract class FolderViewEvent extends Equatable {
  const FolderViewEvent();

  @override
  List<Object?> get props => [];
}

class LoadFolderContent extends FolderViewEvent {
  final int folderId;
  const LoadFolderContent({required this.folderId});

  @override
  List<Object?> get props => [folderId];
}

class SearchInFolderChanged extends FolderViewEvent {
  final String query;
  const SearchInFolderChanged({required this.query});

  @override
  List<Object?> get props => [query];
}

class ClearFolderSearch extends FolderViewEvent {} 