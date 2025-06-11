import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mosaic_search/features/search/bloc/search_bloc.dart';
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:mosaic_search/features/image_preview/presentation/screens/image_preview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Optionally, clear previous search or load initial popular searches if desired
    // context.read<SearchBloc>().add(ClearSearch()); 
    // If you want to clear search when screen is first opened
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'E.g., beach, dog, receipt...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  suffixIcon: BlocBuilder<SearchBloc, SearchState>(
                    builder: (context, state) {
                      if (state.currentQuery.isNotEmpty) {
                        return IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<SearchBloc>().add(ClearSearch());
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                onChanged: (query) {
                  context.read<SearchBloc>().add(SearchQueryChanged(query));
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state.status == SearchStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == SearchStatus.error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: ${state.errorMessage ?? 'Unknown error'}',
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (state.status == SearchStatus.empty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No photos found matching your query. Try different keywords!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (state.status == SearchStatus.loaded) {
                    if (state.searchResults.isEmpty) {
                       // This case should ideally be covered by SearchStatus.empty
                      return const Center(
                         child: Text(
                          'No results. Type to search from your indexed photos.',
                           style: TextStyle(fontSize: 16, color: Colors.grey),
                           textAlign: TextAlign.center,
                          )
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 2x2 grid
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 1.0, // Square items
                      ),
                      itemCount: state.searchResults.length,
                      itemBuilder: (context, index) {
                        final imageMeta = state.searchResults[index];
                        return _buildImageThumbnail(context, imageMeta);
                      },
                    );
                  }
                  // Initial state or other unhandled states
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Start typing to search your photos.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, ImageMetadata imageMeta) {
    final imageFile = File(imageMeta.filePath);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewScreen(imagePath: imageMeta.filePath),
          ),
        );
      },
      child: Card(
        elevation: 2.0,
        clipBehavior: Clip.antiAlias, // Ensures the image respects card boundaries
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<bool>(
                future: imageFile.exists(),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print("Error loading image for thumbnail ${imageMeta.filePath}: $error");
                        return const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey, size: 40));
                      },
                    );
                  } else if (snapshot.hasError || snapshot.data == false) {
                     return const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40));
                  }
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.0)); // Loading state for file check
                }),
            // Optional: Add an overlay with filename or other info
            // Positioned(
            //   bottom: 0,
            //   left: 0,
            //   right: 0,
            //   child: Container(
            //     padding: const EdgeInsets.all(4.0),
            //     color: Colors.black.withOpacity(0.5),
            //     child: Text(
            //       imageMeta.fileName,
            //       style: const TextStyle(color: Colors.white, fontSize: 10),
            //       maxLines: 1,
            //       overflow: TextOverflow.ellipsis,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
} 