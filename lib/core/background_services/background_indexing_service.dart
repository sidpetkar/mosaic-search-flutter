import 'dart:io';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/core/ml_kit_services/ml_kit_analyzer.dart';
import 'package:mosaic_search/models/image_label_model.dart' as db_label;
import 'package:mosaic_search/models/image_text_entry_model.dart' as db_text;
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' show RecognizedText, TextElement;
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:mosaic_search/models/image_object_model.dart' as db_object;
import 'package:mosaic_search/models/image_entity_model.dart' as db_entity;


class BackgroundIndexingService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final MlKitAnalyzer _mlKitAnalyzer = MlKitAnalyzer(); // Consider making this injectable or a singleton if appropriate

  // Task identifier for WorkManager
  static const String imageProcessingTask = "mosaicSearchImageProcessingTask";
  static const String folderIdKey = "folderId";

  Future<bool> processFolder(int folderId) async {
    print('[BackgroundIndexingService] Starting processing for folder ID: $folderId');
    final folder = await _dbHelper.getFolderById(folderId); // Assuming getFolderById exists
    if (folder == null) {
      print('[BackgroundIndexingService] Folder with ID $folderId not found.');
      return false;
    }

    await _dbHelper.updateFolderStatus(folderId, 'indexing');
    
    List<File> imageFiles = [];
    try {
      final dir = Directory(folder.path);
      if (!await dir.exists()) {
         print('[BackgroundIndexingService] Directory ${folder.path} does not exist.');
         await _dbHelper.updateFolderStatus(folderId, 'error_path_not_found');
         return false;
      }
      // List all files, then filter for common image types
      // Consider making image extensions configurable
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          String extension = p.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
            imageFiles.add(entity);
          }
        }
      }
       await _dbHelper.updateFolderStatus(folder.id!, 'indexing', totalImages: imageFiles.length, indexedImages: 0);
       print('[BackgroundIndexingService] Found ${imageFiles.length} images in ${folder.path}');
    } catch (e) {
      print('[BackgroundIndexingService] Error listing images in ${folder.path}: $e');
      await _dbHelper.updateFolderStatus(folderId, 'error_listing_files');
      return false;
    }

    int processedImageCount = 0;
    for (File imageFile in imageFiles) {
      try {
        // 1. Check if image already exists and is indexed (or by date_modified)
        ImageMetadata? existingImage = await _dbHelper.getImageByPath(imageFile.path);
        FileStat stats = await imageFile.stat();
        int lastModified = stats.modified.millisecondsSinceEpoch;

        if (existingImage != null && existingImage.isIndexed && existingImage.dateModified == lastModified) {
          print('[BackgroundIndexingService] Skipping already indexed and unchanged image: ${imageFile.path}');
          processedImageCount++;
          await _dbHelper.incrementIndexedImagesCount(folderId);
          continue;
        }

        int imageId;
        if (existingImage == null) {
          ImageMetadata newImage = ImageMetadata(
            folderId: folderId,
            filePath: imageFile.path,
            fileName: p.basename(imageFile.path),
            dateModified: lastModified,
            isIndexed: false,
          );
          imageId = await _dbHelper.insertImageMetadata(newImage);
          if (imageId == 0) { // conflict or error
            print('[BackgroundIndexingService] Failed to insert image metadata or already exists: ${imageFile.path}');
            // Attempt to get it again if insert returned 0 due to conflict
            existingImage = await _dbHelper.getImageByPath(imageFile.path);
            if (existingImage == null || existingImage.id == null) continue; // Critical error, skip
            imageId = existingImage.id!;
            // Update date modified if it changed
            if (existingImage.dateModified != lastModified) {
                await _dbHelper.updateImageMetadata(existingImage.copyWith(dateModified: lastModified, isIndexed: false));
            }
          }
        } else {
          imageId = existingImage.id!;
           // If image exists but wasn't indexed or was modified, reset its indexed state and update modified date
          if (!existingImage.isIndexed || existingImage.dateModified != lastModified) {
             await _dbHelper.updateImageMetadata(existingImage.copyWith(dateModified: lastModified, isIndexed: false));
             // Potentially delete old labels and text entries if re-indexing from scratch
             // For now, we assume new labels/text will overwrite or add if schema allows
          }
        }

        // 2. Process with ML Kit
        print('[BackgroundIndexingService] Processing image: ${imageFile.path}');
        final MlKitResult mlResult = await _mlKitAnalyzer.processImage(imageFile.path);

        // 3. Save ML Kit results to DB
        // Save labels
        List<db_label.ImageLabel> dbLabels = mlResult.labels.map((mlLabel) => 
          db_label.ImageLabel(
            imageId: imageId,
            label: mlLabel.label,
            confidence: mlLabel.confidence
          )
        ).toList();
        if (dbLabels.isNotEmpty) await _dbHelper.insertImageLabels(dbLabels);

        // Save detected objects
        List<db_object.ImageObject> dbObjects = [];
        for (var mlObject in mlResult.objects) {
          for (var label in mlObject.labels) {
            if (label.confidence >= MlKitAnalyzer.defaultObjectConfidenceThreshold) {
              dbObjects.add(db_object.ImageObject(
                imageId: imageId,
                label: label.text,
                confidence: label.confidence,
                boundingBoxLeft: mlObject.boundingBox.left,
                boundingBoxTop: mlObject.boundingBox.top,
                boundingBoxRight: mlObject.boundingBox.right,
                boundingBoxBottom: mlObject.boundingBox.bottom,
                trackingId: mlObject.trackingId,
              ));
            }
          }
        }
        if (dbObjects.isNotEmpty) {
          await _dbHelper.insertImageObjects(dbObjects);
        }

        // Save text entries
        String fullText = mlResult.textElements.map((e) => e.text).join(' \n');
        if (fullText.trim().isNotEmpty) {
          db_text.ImageTextEntry textEntry = db_text.ImageTextEntry(
            imageId: imageId,
            recognizedText: fullText.trim()
          );
          await _dbHelper.insertImageTextEntry(textEntry);
        }
        
        // Save Entities (New)
        List<db_entity.ImageEntity> dbEntities = mlResult.entities.map((mlEntity) => 
          db_entity.ImageEntity(
            imageId: imageId,
            text: mlEntity.text,
            type: mlEntity.entities.isNotEmpty ? mlEntity.entities.first.type : EntityType.unknown,
            rawValueString: mlEntity.text,
          )
        ).toList();
        if (dbEntities.isNotEmpty) {
          await _dbHelper.insertImageEntities(dbEntities);
        }
        
        // 4. Mark image as indexed
        await _dbHelper.setImageAsIndexed(imageId);
        processedImageCount++;
        await _dbHelper.incrementIndexedImagesCount(folderId);
        print('[BackgroundIndexingService] Finished processing ${imageFile.path}. Progress: $processedImageCount/${imageFiles.length}');

      } catch (e, stacktrace) {
        print('[BackgroundIndexingService] Error processing file ${imageFile.path}: $e');
        print(stacktrace);
        // Optionally mark this specific image as failed in DB or log it
      }
      // Add a small delay to allow other isolates/processes to access the DB
      await Future.delayed(const Duration(milliseconds: 50)); // Added delay
    }

    // await _mlKitAnalyzer.dispose(); // Dispose analyzer when folder processing is done.
    // MlKitAnalyzer is now a member variable, it should be disposed when BackgroundIndexingService itself is no longer needed,
    // or if we create a new instance per folder processing call, then it should be disposed here.
    // For now, assuming it's a longer-lived instance tied to the service. If it were created IN processFolder, it should be disposed here.
    // Let's assume it's created per call for now and dispose it.
    await _mlKitAnalyzer.dispose(); 


    if (processedImageCount == imageFiles.length) {
      await _dbHelper.updateFolderStatus(folderId, 'ready');
      print('[BackgroundIndexingService] Successfully processed all images in folder ID: $folderId');
    } else {
      await _dbHelper.updateFolderStatus(folderId, 'partial_error'); // Or some other status
      print('[BackgroundIndexingService] Finished processing folder ID: $folderId with some errors.');
    }
    return true;
  }
} 