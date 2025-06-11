part of 'folder_view_bloc.dart';

enum FolderViewStatus { initial, loading, loaded, error }

class FolderViewState extends Equatable {
  final FolderViewStatus status;
  final List<ImageMetadata> images;
  final String? currentSearchQuery; // To keep track of the search term
  final String? errorMessage;
  final Folder? currentFolder; // To store the folder details

  const FolderViewState({
    this.status = FolderViewStatus.initial,
    this.images = const [],
    this.currentSearchQuery,
    this.errorMessage,
    this.currentFolder,
  });

  FolderViewState copyWith({
    FolderViewStatus? status,
    List<ImageMetadata>? images,
    String? currentSearchQuery,
    bool clearSearchQuery = false, // Utility to clear search
    String? errorMessage,
    bool clearErrorMessage = false,
    Folder? currentFolder,
  }) {
    return FolderViewState(
      status: status ?? this.status,
      images: images ?? this.images,
      currentSearchQuery: clearSearchQuery ? null : currentSearchQuery ?? this.currentSearchQuery,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      currentFolder: currentFolder ?? this.currentFolder,
    );
  }

  @override
  List<Object?> get props => [status, images, currentSearchQuery, errorMessage, currentFolder];
} 