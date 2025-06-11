class ImageObject {
  final int? id;
  final int imageId;
  final String label;
  final double confidence;
  // Bounding box (optional, but good to have if we want to display it later)
  // Storing as simple LTRB (Left, Top, Right, Bottom)
  final double? boundingBoxLeft;
  final double? boundingBoxTop;
  final double? boundingBoxRight;
  final double? boundingBoxBottom;
  final int? trackingId; // From DetectedObject, might be null

  const ImageObject({
    this.id,
    required this.imageId,
    required this.label,
    required this.confidence,
    this.boundingBoxLeft,
    this.boundingBoxTop,
    this.boundingBoxRight,
    this.boundingBoxBottom,
    this.trackingId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_id': imageId,
      'label': label,
      'confidence': confidence,
      'bounding_box_left': boundingBoxLeft,
      'bounding_box_top': boundingBoxTop,
      'bounding_box_right': boundingBoxRight,
      'bounding_box_bottom': boundingBoxBottom,
      'tracking_id': trackingId,
    };
  }

  factory ImageObject.fromMap(Map<String, dynamic> map) {
    return ImageObject(
      id: map['id'] as int?,
      imageId: map['image_id'] as int,
      label: map['label'] as String,
      confidence: map['confidence'] as double,
      boundingBoxLeft: map['bounding_box_left'] as double?,
      boundingBoxTop: map['bounding_box_top'] as double?,
      boundingBoxRight: map['bounding_box_right'] as double?,
      boundingBoxBottom: map['bounding_box_bottom'] as double?,
      trackingId: map['tracking_id'] as int?,
    );
  }

  ImageObject copyWith({
    int? id,
    int? imageId,
    String? label,
    double? confidence,
    double? boundingBoxLeft,
    double? boundingBoxTop,
    double? boundingBoxRight,
    double? boundingBoxBottom,
    int? trackingId,
  }) {
    return ImageObject(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      boundingBoxLeft: boundingBoxLeft ?? this.boundingBoxLeft,
      boundingBoxTop: boundingBoxTop ?? this.boundingBoxTop,
      boundingBoxRight: boundingBoxRight ?? this.boundingBoxRight,
      boundingBoxBottom: boundingBoxBottom ?? this.boundingBoxBottom,
      trackingId: trackingId ?? this.trackingId,
    );
  }
} 