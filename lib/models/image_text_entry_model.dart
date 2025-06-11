class ImageTextEntry {
  final int? id;
  final int imageId;
  final String recognizedText;

  const ImageTextEntry({
    this.id,
    required this.imageId,
    required this.recognizedText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_id': imageId,
      'recognized_text': recognizedText,
    };
  }

 factory ImageTextEntry.fromMap(Map<String, dynamic> map) {
    return ImageTextEntry(
      id: map['id'] as int?,
      imageId: map['image_id'] as int,
      recognizedText: map['recognized_text'] as String,
    );
  }

  ImageTextEntry copyWith({
    int? id,
    int? imageId,
    String? recognizedText,
  }) {
    return ImageTextEntry(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      recognizedText: recognizedText ?? this.recognizedText,
    );
  }
} 