import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mosaic_search/features/folder_view/bloc/folder_view_bloc.dart';
import 'package:mosaic_search/features/image_preview/presentation/screens/image_preview_screen.dart';
import 'package:mosaic_search/models/folder_model.dart';

class FolderViewScreen extends StatefulWidget {
  final Folder folder;
  const FolderViewScreen({super.key, required this.folder});

  @override
  State<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.folder.id != null) {
      context.read<FolderViewBloc>().add(LoadFolderContent(folderId: widget.folder.id!));
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchBox(BuildContext context, FolderViewState folderViewState) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: const Color(0xFF0027FF), // Match HomeScreen top area color
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (query) {
          if (query.isNotEmpty) {
            context.read<FolderViewBloc>().add(SearchInFolderChanged(query: query));
          } else {
            context.read<FolderViewBloc>().add(ClearFolderSearch());
          }
        },
        style: GoogleFonts.dmSans(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search in ${widget.folder.name}',
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[700]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name, style: GoogleFonts.dmSans()),
        backgroundColor: const Color(0xFF0027FF), // Match HomeScreen top area color
        elevation: 0,
      ),
      body: Column(
        children: [
          BlocBuilder<FolderViewBloc, FolderViewState>(
            builder: (context, state) {
              return _buildSearchBox(context, state);
            }
          ),
          Expanded(
            child: BlocBuilder<FolderViewBloc, FolderViewState>(
              builder: (context, state) {
                if (state.status == FolderViewStatus.loading && state.images.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == FolderViewStatus.error) {
                  return Center(child: Text('Error: ${state.errorMessage ?? "Unknown error"}'));
                }
                if (state.images.isEmpty) {
                  if (state.currentSearchQuery != null && state.currentSearchQuery!.isNotEmpty) {
                     return const Center(child: Text('No results found in this folder.'));
                  }
                  return const Center(child: Text('This folder is empty or has no indexed images yet.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: state.images.length,
                  itemBuilder: (context, index) {
                    final image = state.images[index];
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
                        child: Image.file(
                          File(image.filePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 