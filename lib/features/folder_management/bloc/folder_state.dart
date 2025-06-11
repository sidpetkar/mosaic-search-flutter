part of 'folder_bloc.dart';

enum FolderStatus { initial, loading, loaded, error, selecting, adding, deleting }

class FolderState extends Equatable {
  final List<Folder> folders;
  final FolderStatus status;
  final String? errorMessage;

  const FolderState({
    this.folders = const [],
    this.status = FolderStatus.initial,
    this.errorMessage,
  });

  FolderState copyWith({
    List<Folder>? folders,
    FolderStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false, // Utility to clear error on next state
  }) {
    return FolderState(
      folders: folders ?? this.folders,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [folders, status, errorMessage];
} 