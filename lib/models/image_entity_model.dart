import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

class ImageEntity {
  final int? id;
  final int imageId;
  final String text; // The text of the entity
  final EntityType type; // e.g., address, datetime, email, flight, etc.
  final double? confidenceScore; // Available for some entity types like flight, IBAN
  // Raw entity values (e.g., DateTimeEntity, MoneyEntity) can be complex. 
  // For simplicity, we'll store the main recognized text and its type.
  // If more detail is needed later, we can expand this to store parts of rawValue.
  final String? rawValueString; // String representation of raw value if needed

  const ImageEntity({
    this.id,
    required this.imageId,
    required this.text,
    required this.type,
    this.confidenceScore,
    this.rawValueString,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_id': imageId,
      'text': text,
      'type': type.name, // Store enum as string
      'confidence_score': confidenceScore,
      'raw_value_string': rawValueString,
    };
  }

  factory ImageEntity.fromMap(Map<String, dynamic> map) {
    return ImageEntity(
      id: map['id'] as int?,
      imageId: map['image_id'] as int,
      text: map['text'] as String,
      type: EntityType.values.firstWhere((e) => e.name == map['type'], orElse: () => EntityType.unknown),
      confidenceScore: map['confidence_score'] as double?,
      rawValueString: map['raw_value_string'] as String?,
    );
  }

  ImageEntity copyWith({
    int? id,
    int? imageId,
    String? text,
    EntityType? type,
    double? confidenceScore,
    String? rawValueString,
  }) {
    return ImageEntity(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      text: text ?? this.text,
      type: type ?? this.type,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawValueString: rawValueString ?? this.rawValueString,
    );
  }

  @override
  String toString() {
    return 'ImageEntity(id: $id, imageId: $imageId, text: \'$text\', type: $type, confidence: $confidenceScore)';
  }
} 