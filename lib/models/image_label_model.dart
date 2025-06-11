class ImageLabel {
  final int? id;
  final int imageId;
  final String label;
  final double confidence;

  const ImageLabel({
    this.id,
    required this.imageId,
    required this.label,
    required this.confidence,
  });

   Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_id': imageId,
      'label': label,
      'confidence': confidence,
    };
  }

  factory ImageLabel.fromMap(Map<String, dynamic> map) {
    return ImageLabel(
      id: map['id'] as int?,
      imageId: map['image_id'] as int,
      label: map['label'] as String,
      confidence: map['confidence'] as double,
    );
  }

  ImageLabel copyWith({
    int? id,
    int? imageId,
    String? label,
    double? confidence,
  }) {
    return ImageLabel(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
    );
  }
} 