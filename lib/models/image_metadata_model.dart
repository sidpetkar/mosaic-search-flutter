class ImageMetadata {
  final int? id;
  final int folderId;
  final String filePath;
  final String fileName;
  final int dateModified; // Store as millisecondsSinceEpoch
  final bool isIndexed;

  const ImageMetadata({
    this.id,
    required this.folderId,
    required this.filePath,
    required this.fileName,
    required this.dateModified,
    this.isIndexed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folder_id': folderId,
      'file_path': filePath,
      'file_name': fileName,
      'date_modified': dateModified,
      'is_indexed': isIndexed ? 1 : 0,
    };
  }

  factory ImageMetadata.fromMap(Map<String, dynamic> map) {
    return ImageMetadata(
      id: map['id'] as int?,
      folderId: map['folder_id'] as int,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      dateModified: map['date_modified'] as int,
      isIndexed: (map['is_indexed'] as int) == 1,
    );
  }

  ImageMetadata copyWith({
    int? id,
    int? folderId,
    String? filePath,
    String? fileName,
    int? dateModified,
    bool? isIndexed,
  }) {
    return ImageMetadata(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      dateModified: dateModified ?? this.dateModified,
      isIndexed: isIndexed ?? this.isIndexed,
    );
  }
} 