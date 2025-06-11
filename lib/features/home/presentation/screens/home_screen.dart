import 'dart:io'; // Added for File operations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:mosaic_search/features/folder_management/bloc/folder_bloc.dart';
import 'package:mosaic_search/models/folder_model.dart';
// import 'package:mosaic_search/features/search/presentation/screens/search_screen.dart'; // Commented out for now
import 'package:mosaic_search/features/search/bloc/search_bloc.dart'; // Added SearchBloc import
import 'package:mosaic_search/models/image_metadata_model.dart'; // Ensure ImageMetadata is imported if SearchBloc uses it directly
import 'package:mosaic_search/features/image_preview/presentation/screens/image_preview_screen.dart'; // Import for ImagePreviewScreen
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart'; // Import swipe cell
import 'package:mosaic_search/features/folder_view/presentation/screens/folder_view_screen.dart'; // Added import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<FolderBloc>().add(LoadFolders());
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    // This is to catch when the keyboard is dismissed by system back button, for example
    if (!_searchFocusNode.hasFocus && _isSearchActive) {
      setState(() {
        _isSearchActive = false;
      });
    }
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
    });
    _searchFocusNode.requestFocus();
  }

  void _deactivateSearch() {
    setState(() {
      _isSearchActive = false;
      _searchController.clear();
      context.read<SearchBloc>().add(ClearSearch());
    });
    _searchFocusNode.unfocus();
  }
  
  Widget _buildTopHeaderArea() {
    // In search mode, we need to position the search box differently
    if (_isSearchActive) {
      return Container(
        color: const Color(0xFF0027FF),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status bar spacer
            SizedBox(height: MediaQuery.of(context).padding.top),
            
            // Search box with its own padding
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), // 16px padding for search bar
              child: _buildSearchField(),
            ),
          ],
        ),
      );
    } 
    
    // Normal mode with logo and search box
    return Container(
      color: const Color(0xFF0027FF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGreetingHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0), // 16px padding for search bar
            child: _buildSearchField(),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Container(
      height: 140, // Increased height to accommodate more top padding
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        top: MediaQuery.of(context).padding.top + 60, // Increased top padding to 60px plus status bar
        bottom: 8
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.center,
            child: Image.asset(
              'asset/app-icon.png',
              height: 28,
              width: 28,
              errorBuilder: (ctx, e, st) => const Icon(Icons.search, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mosaic Search',
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Separate the TextField into its own method for reuse
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onTap: _activateSearch,
      onChanged: (query) {
        if (query.isNotEmpty) {
          context.read<SearchBloc>().add(SearchQueryChanged(query));
        } else {
          context.read<SearchBloc>().add(ClearSearch());
        }
      },
      style: GoogleFonts.dmSans(color: Colors.black, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search for Dog, Car, Cake',
        hintStyle: GoogleFonts.dmSans(color: Colors.grey[700], fontSize: 16),
        prefixIcon: _isSearchActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                onPressed: _deactivateSearch,
              )
            : const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // New widget for the "Folders" label and add icon row
  Widget _buildFoldersHeader(BuildContext context) {
    return Container(
      height: 80.0, // Increased height for more vertical padding
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Added 32px top/bottom padding
      margin: const EdgeInsets.only(top: 24.0), // Keep existing top margin
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Folders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Tooltip(
            message: 'Import New Folder',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  context.read<FolderBloc>().add(const AddFolderRequested());
                },
                borderRadius: BorderRadius.circular(24.0),
                // Increased padding for larger touch target
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: const Icon(Icons.add, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set the system UI overlay style for the status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Make status bar transparent
      statusBarIconBrightness: Brightness.light, // For light icons (white)
      statusBarBrightness: Brightness.dark, // For iOS (dark background = light text)
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopHeaderArea(),
          Expanded(
            child: _isSearchActive
                ? BlocBuilder<SearchBloc, SearchState>(
                    builder: (context, searchState) {
                      if (searchState.status == SearchStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (searchState.status == SearchStatus.error) {
                        return Center(child: Text('Error: ${searchState.errorMessage ?? "Unknown error"}'));
                      }
                      if (searchState.status == SearchStatus.loaded) {
                        if (searchState.searchResults.isEmpty && _searchController.text.isNotEmpty) {
                          return const Center(child: Text('No results found.'));
                        }
                        if (searchState.searchResults.isEmpty && _searchController.text.isEmpty) {
                           return const Center(child: Text('Type to start searching...'));
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), // Consistent 24px padding
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, 
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 1.0, 
                          ),
                          itemCount: searchState.searchResults.length,
                          itemBuilder: (context, index) {
                            final image = searchState.searchResults[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImagePreviewScreen(imagePath: image.filePath),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 0.0,
                                clipBehavior: Clip.antiAlias, 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Image.file(
                                        File(image.filePath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      if (searchState.status == SearchStatus.empty && _searchController.text.isNotEmpty) {
                         return const Center(child: Text('No results found.')); 
                      } 
                      return const Center(child: Text('Type to start searching...'));
                    },
                  )
                : Column( 
                    children: [
                      _buildFoldersHeader(context),
                      const SizedBox(height: 8.0),
                      Expanded(
                        child: BlocConsumer<FolderBloc, FolderState>(
                          listener: (context, state) {
                            if (state.status == FolderStatus.error && state.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${state.errorMessage}')),
                              );
                            }
                            if (state.status == FolderStatus.selecting) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening folder picker...')),
                              );
                            }
                          },
                          builder: (context, state) {
                            if (state.status == FolderStatus.loading && state.folders.isEmpty) {
                              return const Center(child: CircularProgressIndicator());
                            }
                
                            if (state.folders.isEmpty && state.status != FolderStatus.loading) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0), // Consistent 24px padding
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Click the + sign to add folders',
                                        style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey[700]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                
                            // Display list of folders
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0), // Added vertical padding
                              clipBehavior: Clip.none, // Don't clip overflow
                              itemCount: state.folders.length,
                              itemBuilder: (context, index) {
                                final folder = state.folders[index];
                                return _buildFolderItem(context, folder, state); 
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _isSearchActive ? null : null, // FAB removed for now, add button is in _buildFoldersHeader
    );
  }

  Widget _buildFolderItem(BuildContext context, Folder folder, FolderState blocState) {
    final Color pathStatusColor = const Color.fromRGBO(131, 140, 140, 1); // hsla(180, 5%, 53%, 1)
    final TextStyle textStyle = GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w500, // Medium
    );

    bool isProcessing = folder.status == 'indexing' || 
                        folder.status == 'pending_indexing' || 
                        folder.status == 'pending_sync' ||
                        folder.status == 'pending';
    double progress = 0.0;
    if (folder.totalImages > 0) {
      progress = folder.indexedImages / folder.totalImages;
    }

    Widget folderItemContent = Container(
      height: 82.0, // Adjusted from 90.0
      padding: const EdgeInsets.only(right: 24.0), // Updated to 24px right padding
      child: Row(
        children: [
          Container( // Container for the image
            width: 80, 
            height: 82, // Adjusted from 90 to 82 (72px image + 5 + 5 padding)
            alignment: Alignment.center,
            child: Image.asset(
              'asset/folder.png',
              width: 80,
              height: 72, // Adjusted from 80 to 72
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) => const Icon(Icons.folder_copy_outlined, size: 52, color: Colors.grey), // Adjusted fallback icon size
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Text(folder.name, style: textStyle.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2), 
                Text(folder.path, style: textStyle.copyWith(color: pathStatusColor), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2), 
                if (isProcessing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: progress.isNaN || progress.isInfinite ? null : progress, backgroundColor: Colors.grey[300], valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF0026F9)), minHeight: 2),
                      const SizedBox(height: 1),
                      Text('Processing... (${folder.indexedImages}/${folder.totalImages})', style: textStyle.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ],
                  )
                else if (folder.status == 'ready')
                  Text('Ready for search (${folder.totalImages} images)', style: textStyle.copyWith(color: pathStatusColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)
                else if (folder.status.startsWith('error'))
                  Text('Error: ${folder.status.replaceAll('error_', '').replaceAll('_', ' ')}', style: textStyle.copyWith(color: Theme.of(context).colorScheme.error), overflow: TextOverflow.ellipsis)
                else 
                  Text('[DEBUG] Raw Status: ' + (folder.status ?? "NULL_STATUS"), style: textStyle.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, backgroundColor: Colors.black54), overflow: TextOverflow.ellipsis), 
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: SwipeActionCell(
        key: ObjectKey(folder.id ?? folder.path),
        trailingActions: <SwipeAction>[
          SwipeAction(
            icon: const Icon(Icons.delete, color: Colors.white, size: 28),
            onTap: (CompletionHandler handler) async {
              bool? deleteConfirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: Text('Are you sure you want to remove the folder "${folder.name}"? \n\nThis will remove its entry and all associated indexed data from the app. The original photos on your device will not be affected.'),
                    actions: <Widget>[
                      TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
                      TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'), onPressed: () => Navigator.of(dialogContext).pop(true)),
                    ],
                  );
                },
              );

              if (deleteConfirmed == true) {
                if (folder.id != null) {
                   context.read<FolderBloc>().add(DeleteFolder(folderId: folder.id!));
                   await handler(true);
                } else {
                  print("Error: Folder ID is null, cannot delete.");
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Error: Could not delete folder, ID missing.')),
                   );
                   await handler(false);
                }
              } else {
                await handler(false);
              }
            },
            color: Colors.red,
            performsFirstActionWithFullSwipe: true,
          ),
        ],
        child: GestureDetector(
          onTap: () {
            if (folder.id != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FolderViewScreen(folder: folder),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Folder ID is missing, cannot open folder.')),
              );
            }
          },
          child: folderItemContent,
        ),
      ),
    );
  }
} 