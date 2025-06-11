import 'dart:io';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/models/folder_model.dart';
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:path/path.dart' as p;
import 'package:mosaic_search/core/background_services/background_indexing_service.dart'; // For re-queueing
import 'package:workmanager/workmanager.dart';

class FolderSyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> syncFolder(Folder folder, {Function(String, int, int)? onProgress}) async {
    if (folder.id == null) return;

    print('[FolderSyncService] Starting sync for folder: ${folder.path}');
    onProgress?.call('syncing_start', 0, 0);

    Map<String, int> dbImageTimestamps = await _dbHelper.getImagePathsAndTimestamps(folder.id!);
    List<File> currentFileSystemImages = [];
    Set<String> currentFileSystemPaths = {};

    try {
      final dir = Directory(folder.path);
      if (!await dir.exists()) {
        print('[FolderSyncService] Directory ${folder.path} does not exist during sync.');
        await _dbHelper.updateFolderStatus(folder.id!, 'error_path_not_found');
        onProgress?.call('error_path_not_found', 0, 0);
        return;
      }
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          String extension = p.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
            currentFileSystemImages.add(entity);
            currentFileSystemPaths.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('[FolderSyncService] Error listing files during sync for ${folder.path}: $e');
      await _dbHelper.updateFolderStatus(folder.id!, 'error_listing_files');
       onProgress?.call('error_listing_files', 0, 0);
      return;
    }

    List<String> imagesToReIndex = [];
    List<ImageMetadata> newImagesToInsert = [];

    // Check for new or modified images
    for (File fsImageFile in currentFileSystemImages) {
      FileStat stats = await fsImageFile.stat();
      int currentTimestamp = stats.modified.millisecondsSinceEpoch;

      if (dbImageTimestamps.containsKey(fsImageFile.path)) {
        // Existing image, check if modified
        if (dbImageTimestamps[fsImageFile.path]! < currentTimestamp) {
          print('[FolderSyncService] Image modified, needs re-indexing: ${fsImageFile.path}');
          imagesToReIndex.add(fsImageFile.path);
        }
        dbImageTimestamps.remove(fsImageFile.path); // Remove from map to track processed DB images
      } else {
        // New image
        print('[FolderSyncService] New image found: ${fsImageFile.path}');
        newImagesToInsert.add(ImageMetadata(
          folderId: folder.id!,
          filePath: fsImageFile.path,
          fileName: p.basename(fsImageFile.path),
          dateModified: currentTimestamp,
          isIndexed: false, // Will be indexed by background service
        ));
      }
    }

    // Check for deleted images (those remaining in dbImageTimestamps)
    List<String> deletedImagePaths = dbImageTimestamps.keys.toList();
    for (String deletedPath in deletedImagePaths) {
      print('[FolderSyncService] Image deleted: $deletedPath');
      ImageMetadata? imgToDelete = await _dbHelper.getImageByPath(deletedPath);
      if (imgToDelete != null && imgToDelete.id != null) {
        await _dbHelper.deleteImage(imgToDelete.id!); // Cascading delete handles related data
      }
    }

    // Process new images
    if (newImagesToInsert.isNotEmpty) {
      for (var newImage in newImagesToInsert) {
        await _dbHelper.insertImageMetadata(newImage); 
      }
      print('[FolderSyncService] Added ${newImagesToInsert.length} new images to DB for folder ${folder.name}');
    }

    // Update existing images that need re-indexing
    if (imagesToReIndex.isNotEmpty) {
      for (String path in imagesToReIndex) {
        ImageMetadata? image = await _dbHelper.getImageByPath(path);
        if (image != null && image.id != null) {
          FileStat stats = await File(path).stat(); // Get fresh stats
          await _dbHelper.updateImageMetadata(image.copyWith(
            isIndexed: false, // Mark for re-indexing
            dateModified: stats.modified.millisecondsSinceEpoch,
          ));
          // Cascading deletes are not needed here, as the background service will overwrite labels/text/objects/entities for this imageId
        }
      }
       print('[FolderSyncService] Marked ${imagesToReIndex.length} images for re-indexing in folder ${folder.name}');
    }
    
    // After DB updates, re-trigger background indexing for the folder if there were new or changed files
    if (newImagesToInsert.isNotEmpty || imagesToReIndex.isNotEmpty) {
        print('[FolderSyncService] Changes detected, re-triggering background indexing for folder ${folder.name}');
        // Update folder status to reflect it's pending re-indexing or has new items
        // The background service itself will update total/indexed counts accurately when it runs.
        await _dbHelper.updateFolderStatus(folder.id!, 'pending_sync'); 

        // Re-register WorkManager task for this folder
        // This ensures even if a previous task completed, it will run again for new/modified items.
        final workManager = Workmanager();
        await workManager.registerOneOffTask(
          "${BackgroundIndexingService.imageProcessingTask}_${folder.id!}_${DateTime.now().millisecondsSinceEpoch}", // Unique name including timestamp
          BackgroundIndexingService.imageProcessingTask,
          inputData: {BackgroundIndexingService.folderIdKey: folder.id!},
          constraints: Constraints(
            // networkType: NetworkType.connected, // Example: if network is needed for ML models
            // requiresStorageNotLow: true,
            networkType: NetworkType.not_required,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace, // Replace if a task with the same unique name exists
        );
    } else {
         // If no new, modified, or deleted images, and folder was in a good state, ensure it's 'ready'
         // However, total_images and indexed_images need to be accurate.
         // Let's fetch them directly.
         int totalImagesInFs = currentFileSystemImages.length;
         List<ImageMetadata> indexedImagesInDb = await _dbHelper.getAllImagesInFolder(folder.id!, onlyNotIndexed: false);
         int actualIndexedCount = indexedImagesInDb.where((img) => img.isIndexed).length;

         await _dbHelper.updateFolderStatus(folder.id!, 'ready', totalImages: totalImagesInFs, indexedImages: actualIndexedCount);
         print('[FolderSyncService] No changes detected for folder ${folder.name}. Status set to ready.');
    }
    onProgress?.call('syncing_complete', currentFileSystemImages.length, newImagesToInsert.length + imagesToReIndex.length);
    print('[FolderSyncService] Sync completed for folder: ${folder.path}');
  }
} 