class Folder {
  final int? id;
  final String path;
  final String name;
  String status; // 'indexing', 'ready', 'error'
  int totalImages;
  int indexedImages;

  Folder({
    this.id,
    required this.path,
    required this.name,
    this.status = 'indexing',
    this.totalImages = 0,
    this.indexedImages = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'status': status,
      'total_images': totalImages,
      'indexed_images': indexedImages,
    };
  }

 factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      path: map['path'] as String,
      name: map['name'] as String,
      status: map['status'] as String,
      totalImages: map['total_images'] as int,
      indexedImages: map['indexed_images'] as int,
    );
  }

  //copyWith method
  Folder copyWith({
    int? id,
    String? path,
    String? name,
    String? status,
    int? totalImages,
    int? indexedImages,
  }) {
    return Folder(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      status: status ?? this.status,
      totalImages: totalImages ?? this.totalImages,
      indexedImages: indexedImages ?? this.indexedImages,
    );
  }
} 