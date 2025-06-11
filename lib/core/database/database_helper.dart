import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:mosaic_search/models/folder_model.dart';
import 'package:mosaic_search/models/image_metadata_model.dart';
import 'package:mosaic_search/models/image_label_model.dart';
import 'package:mosaic_search/models/image_text_entry_model.dart';
import 'package:mosaic_search/models/image_object_model.dart';
import 'package:mosaic_search/models/image_entity_model.dart';

class DatabaseHelper {
  static const _databaseName = "MosaicSearch.db";
  static const _databaseVersion = 3;

  // Table names
  static const tableFolders = 'folders';
  static const tableImages = 'images';
  static const tableImageLabels = 'image_labels';
  static const tableImageTextEntries = 'image_text_entries';
  static const tableImageObjects = 'image_objects';
  static const tableImageEntities = 'image_entities';

  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // This opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onConfigure: _onConfigure, // Enable foreign keys
    );
  }

  // Enable foreign keys
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // SQL code to create the database tables
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableFolders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            status TEXT NOT NULL,
            total_images INTEGER NOT NULL DEFAULT 0,
            indexed_images INTEGER NOT NULL DEFAULT 0
          )
          ''');

    await db.execute('''
          CREATE TABLE $tableImages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_id INTEGER NOT NULL,
            file_path TEXT NOT NULL UNIQUE,
            file_name TEXT NOT NULL,
            date_modified INTEGER NOT NULL, 
            is_indexed INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (folder_id) REFERENCES $tableFolders (id) ON DELETE CASCADE
          )
          ''');

    await db.execute('''
          CREATE TABLE $tableImageLabels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_id INTEGER NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            FOREIGN KEY (image_id) REFERENCES $tableImages (id) ON DELETE CASCADE
          )
          ''');
    // Create an index on the label column for faster searching
    await db.execute('CREATE INDEX idx_label ON $tableImageLabels(label);');

    await db.execute('''
          CREATE TABLE $tableImageTextEntries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_id INTEGER NOT NULL,
            recognized_text TEXT NOT NULL,
            FOREIGN KEY (image_id) REFERENCES $tableImages (id) ON DELETE CASCADE
          )
          ''');
    // Create a FTS5 virtual table for full-text search on recognized_text
    // This allows for efficient searching of text within the recognized_text column.
    await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS ${tableImageTextEntries}_fts 
          USING fts5(recognized_text, content='$tableImageTextEntries', content_rowid='id');
          ''');

    // Triggers to keep FTS table in sync with image_text_entries table
    await db.execute('''
        CREATE TRIGGER ${tableImageTextEntries}_ai AFTER INSERT ON $tableImageTextEntries BEGIN
          INSERT INTO ${tableImageTextEntries}_fts (rowid, recognized_text) VALUES (new.id, new.recognized_text);
        END;
        ''');
    await db.execute('''
        CREATE TRIGGER ${tableImageTextEntries}_ad AFTER DELETE ON $tableImageTextEntries BEGIN
          DELETE FROM ${tableImageTextEntries}_fts WHERE rowid=old.id;
        END;
        ''');
    await db.execute('''
        CREATE TRIGGER ${tableImageTextEntries}_au AFTER UPDATE ON $tableImageTextEntries BEGIN
          UPDATE ${tableImageTextEntries}_fts SET recognized_text=new.recognized_text WHERE rowid=old.id;
        END;
        ''');

    // New table for Image Objects
    await db.execute('''
          CREATE TABLE $tableImageObjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_id INTEGER NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            bounding_box_left REAL,
            bounding_box_top REAL,
            bounding_box_right REAL,
            bounding_box_bottom REAL,
            tracking_id INTEGER,
            FOREIGN KEY (image_id) REFERENCES $tableImages (id) ON DELETE CASCADE
          )
          ''');
    // Create an index on the object label column for faster searching
    await db.execute('CREATE INDEX idx_object_label ON $tableImageObjects(label);');

    // New table for Image Entities
    await db.execute('''
          CREATE TABLE $tableImageEntities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_id INTEGER NOT NULL,
            text TEXT NOT NULL,
            type TEXT NOT NULL, -- Storing EntityType.name as string
            confidence_score REAL,
            raw_value_string TEXT,
            FOREIGN KEY (image_id) REFERENCES $tableImages (id) ON DELETE CASCADE
          )
          ''');
    // Create indexes for faster searching on entities
    await db.execute('CREATE INDEX idx_entity_text ON $tableImageEntities(text);');
    await db.execute('CREATE INDEX idx_entity_type ON $tableImageEntities(type);');
  }

  // --- Folder Operations ---
  Future<int> insertFolder(Folder folder) async {
    Database db = await instance.database;
    return await db.insert(tableFolders, folder.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Folder?> getFolderByPath(String path) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableFolders,
        where: 'path = ?', whereArgs: [path], limit: 1);
    if (maps.isNotEmpty) {
      return Folder.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Folder>> getAllFolders() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableFolders, orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return Folder.fromMap(maps[i]);
    });
  }

  Future<Folder?> getFolderById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableFolders,
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) {
      return Folder.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateFolder(Folder folder) async {
    Database db = await instance.database;
    return await db.update(tableFolders, folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<int> deleteFolder(int id) async {
    Database db = await instance.database;
    // ON DELETE CASCADE will handle associated images, labels, and text entries
    return await db.delete(tableFolders, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateFolderStatus(int folderId, String status, {int? totalImages, int? indexedImages}) async {
    Database db = await instance.database;
    Map<String, dynamic> values = {'status': status};
    if (totalImages != null) values['total_images'] = totalImages;
    if (indexedImages != null) values['indexed_images'] = indexedImages;
    return await db.update(tableFolders, values, where: 'id = ?', whereArgs: [folderId]);
  }

  Future<int> incrementIndexedImagesCount(int folderId, {int incrementBy = 1}) async {
    Database db = await instance.database;
    return await db.rawUpdate(
      'UPDATE $tableFolders SET indexed_images = indexed_images + ? WHERE id = ?',
      [incrementBy, folderId]
    );
  }

  // --- ImageMetadata Operations ---
  Future<int> insertImageMetadata(ImageMetadata image) async {
    Database db = await instance.database;
    return await db.insert(tableImages, image.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<ImageMetadata?> getImageByPath(String filePath) async {
     Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableImages,
        where: 'file_path = ?', whereArgs: [filePath], limit: 1);
    if (maps.isNotEmpty) {
      return ImageMetadata.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ImageMetadata>> getAllImagesInFolder(int folderId, {bool onlyNotIndexed = false}) async {
    Database db = await instance.database;
    String? whereClause = 'folder_id = ?';
    List<dynamic> whereArgs = [folderId];
    if (onlyNotIndexed) {
      whereClause += ' AND is_indexed = 0';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableImages, 
      where: whereClause, 
      whereArgs: whereArgs, 
      orderBy: 'file_name ASC'
    );
    return List.generate(maps.length, (i) {
      return ImageMetadata.fromMap(maps[i]);
    });
  }

  /// Fetches a map of file_path to date_modified for all images in a folder.
  /// Useful for quickly checking for new/modified files.
  Future<Map<String, int>> getImagePathsAndTimestamps(int folderId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableImages,
      columns: ['file_path', 'date_modified'],
      where: 'folder_id = ?',
      whereArgs: [folderId],
    );
    return {for (var map in maps) map['file_path'] as String: map['date_modified'] as int};
  }
  
  Future<int> updateImageMetadata(ImageMetadata image) async {
    Database db = await instance.database;
    return await db.update(tableImages, image.toMap(), where: 'id = ?', whereArgs: [image.id]);
  }

  Future<int> setImageAsIndexed(int imageId) async {
    Database db = await instance.database;
    return await db.update(tableImages, {'is_indexed': 1}, where: 'id = ?', whereArgs: [imageId]);
  }

  Future<int> deleteImage(int id) async {
    Database db = await instance.database;
    // ON DELETE CASCADE will handle associated labels and text entries
    return await db.delete(tableImages, where: 'id = ?', whereArgs: [id]);
  }

  // --- ImageLabel Operations ---
  Future<int> insertImageLabel(ImageLabel label) async {
    Database db = await instance.database;
    return await db.insert(tableImageLabels, label.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertImageLabels(List<ImageLabel> labels) async {
    Database db = await instance.database;
    Batch batch = db.batch();
    for (var label in labels) {
      batch.insert(tableImageLabels, label.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ImageLabel>> getImageLabels(int imageId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableImageLabels,
        where: 'image_id = ?', whereArgs: [imageId]);
    return List.generate(maps.length, (i) {
      return ImageLabel.fromMap(maps[i]);
    });
  }

  Future<int> deleteImageLabels(int imageId) async {
    Database db = await instance.database;
    return await db.delete(tableImageLabels, where: 'image_id = ?', whereArgs: [imageId]);
  }

  // --- ImageTextEntry Operations ---
  Future<int> insertImageTextEntry(ImageTextEntry textEntry) async {
    Database db = await instance.database;
    return await db.insert(tableImageTextEntries, textEntry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<void> insertImageTextEntries(List<ImageTextEntry> textEntries) async {
    Database db = await instance.database;
    Batch batch = db.batch();
    for (var entry in textEntries) {
      batch.insert(tableImageTextEntries, entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ImageTextEntry>> getImageTextEntries(int imageId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableImageTextEntries,
        where: 'image_id = ?', whereArgs: [imageId]);
    return List.generate(maps.length, (i) {
      return ImageTextEntry.fromMap(maps[i]);
    });
  }

  Future<int> deleteImageTextEntries(int imageId) async {
    Database db = await instance.database;
    return await db.delete(tableImageTextEntries, where: 'image_id = ?', whereArgs: [imageId]);
  }

  // --- ImageObject Operations ---
  Future<void> insertImageObjects(List<ImageObject> objects) async {
    Database db = await instance.database;
    Batch batch = db.batch();
    for (var obj in objects) {
      batch.insert(tableImageObjects, obj.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteImageObjects(int imageId) async {
    Database db = await instance.database;
    return await db.delete(tableImageObjects, where: 'image_id = ?', whereArgs: [imageId]);
  }

  // --- ImageEntity Operations ---
  Future<void> insertImageEntities(List<ImageEntity> entities) async {
    Database db = await instance.database;
    Batch batch = db.batch();
    for (var entity in entities) {
      batch.insert(tableImageEntities, entity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteImageEntities(int imageId) async {
    Database db = await instance.database;
    return await db.delete(tableImageEntities, where: 'image_id = ?', whereArgs: [imageId]);
  }

  // --- Search Operations ---
  Future<List<ImageMetadata>> searchImages(String searchTerm) async {
    Database db = await instance.database;
    // Sanitize searchTerm for FTS query
    final String ftsQuery = searchTerm.replaceAll("'", "''") + '*'; // Add wildcard for prefix search

    // Query for image_ids matching the search term in different tables
    // 1. Search in image_labels
    final String labelSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageLabels WHERE label LIKE ?';
    List<Map<String, dynamic>> labelResults = await db.rawQuery(labelSearchQuery, ['%$searchTerm%']);
    Set<int> imageIds = labelResults.map((map) => map['image_id'] as int).toSet();

    // 2. Search in image_text_entries (FTS)
    final String textSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageTextEntries WHERE id IN (SELECT rowid FROM ${tableImageTextEntries}_fts WHERE recognized_text MATCH ?)';
    List<Map<String, dynamic>> textResults = await db.rawQuery(textSearchQuery, [ftsQuery]);
    imageIds.addAll(textResults.map((map) => map['image_id'] as int).toSet());

    // 3. Search in image_objects
    final String objectSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageObjects WHERE label LIKE ?';
    List<Map<String, dynamic>> objectResults = await db.rawQuery(objectSearchQuery, ['%$searchTerm%']);
    imageIds.addAll(objectResults.map((map) => map['image_id'] as int).toSet());

    // 4. Search in image_entities (text and type)
    final String entityTextSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageEntities WHERE text LIKE ? OR type LIKE ?';
    List<Map<String, dynamic>> entityResults = await db.rawQuery(entityTextSearchQuery, ['%$searchTerm%', '%$searchTerm%']);
    imageIds.addAll(entityResults.map((map) => map['image_id'] as int).toSet());

    if (imageIds.isEmpty) {
      return [];
    }

    // Fetch ImageMetadata for the matched image_ids
    String idsPlaceholder = List.filled(imageIds.length, '?').join(',');
    final String imageQuery = 
      'SELECT * FROM $tableImages WHERE id IN ($idsPlaceholder) ORDER BY date_modified DESC';
    List<Map<String, dynamic>> imageMaps = await db.rawQuery(imageQuery, imageIds.toList());
    
    return imageMaps.map((map) => ImageMetadata.fromMap(map)).toList();
  }

  // New method to search images within a specific folder
  Future<List<ImageMetadata>> searchImagesInFolder({required int folderId, required String searchTerm}) async {
    Database db = await instance.database;
    final String ftsQuery = searchTerm.replaceAll("'", "''") + '*';

    Set<int> imageIds = {};

    // 1. Search in image_labels
    final String labelSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageLabels WHERE image_id IN (SELECT id FROM $tableImages WHERE folder_id = ?) AND label LIKE ?';
    List<Map<String, dynamic>> labelResults = await db.rawQuery(labelSearchQuery, [folderId, '%$searchTerm%']);
    imageIds.addAll(labelResults.map((map) => map['image_id'] as int).toSet());

    // 2. Search in image_text_entries (FTS)
    final String textSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageTextEntries WHERE image_id IN (SELECT id FROM $tableImages WHERE folder_id = ?) AND id IN (SELECT rowid FROM ${tableImageTextEntries}_fts WHERE recognized_text MATCH ?)';
    List<Map<String, dynamic>> textResults = await db.rawQuery(textSearchQuery, [folderId, ftsQuery]);
    imageIds.addAll(textResults.map((map) => map['image_id'] as int).toSet());

    // 3. Search in image_objects
    final String objectSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageObjects WHERE image_id IN (SELECT id FROM $tableImages WHERE folder_id = ?) AND label LIKE ?';
    List<Map<String, dynamic>> objectResults = await db.rawQuery(objectSearchQuery, [folderId, '%$searchTerm%']);
    imageIds.addAll(objectResults.map((map) => map['image_id'] as int).toSet());

    // 4. Search in image_entities (text and type)
    final String entityTextSearchQuery = 
      'SELECT DISTINCT image_id FROM $tableImageEntities WHERE image_id IN (SELECT id FROM $tableImages WHERE folder_id = ?) AND (text LIKE ? OR type LIKE ?)';
    List<Map<String, dynamic>> entityResults = await db.rawQuery(entityTextSearchQuery, [folderId, '%$searchTerm%', '%$searchTerm%']);
    imageIds.addAll(entityResults.map((map) => map['image_id'] as int).toSet());

    if (imageIds.isEmpty) {
      return [];
    }

    String idsPlaceholder = List.filled(imageIds.length, '?').join(',');
    final String imageQuery = 
      'SELECT * FROM $tableImages WHERE folder_id = ? AND id IN ($idsPlaceholder) ORDER BY date_modified DESC';
    List<Map<String, dynamic>> imageMaps = await db.rawQuery(imageQuery, [folderId, ...imageIds.toList()]);
    
    return imageMaps.map((map) => ImageMetadata.fromMap(map)).toList();
  }

  // Method to clear all data (useful for development/testing or if user wants to reset)
  Future<void> clearAllData() async {
    Database db = await instance.database;
    await db.delete(tableFolders); // Cascading deletes should handle the rest
    // Or, delete from each table explicitly if preferred, though cascade should work
    // await db.delete(tableImages);
    // await db.delete(tableImageLabels);
    // await db.delete(tableImageTextEntries);
    // Note: FTS table is tied to image_text_entries, so it will be cleared by trigger or when image_text_entries is empty.
  }

} 