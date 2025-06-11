import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

class MlKitResult {
  final List<ImageLabel> labels;
  final List<TextElement> textElements; // Now pre-filtered by confidence
  final List<DetectedObject> objects; // Add this for detected objects
  final List<EntityAnnotation> entities; // Add this for extracted entities

  MlKitResult({
    required this.labels,
    required this.textElements,
    required this.objects,
    required this.entities,
  });
}

class MlKitAnalyzer {
  final ImageLabeler _imageLabeler;
  final TextRecognizer _textRecognizer;
  final ObjectDetector _objectDetector;
  final EntityExtractor _entityExtractor;
  bool _isDisposed = false;

  // Define a default confidence threshold for text elements
  static const double defaultTextConfidenceThreshold = 0.7;
  // Define a default confidence threshold for image labels
  static const double defaultLabelConfidenceThreshold = 0.65;
  // Confidence for object detection labels (if classification is enabled)
  static const double defaultObjectConfidenceThreshold = 0.5;

  MlKitAnalyzer() :
    // Initialize with default options. Custom options can be passed if needed.
    // e.g., ImageLabelerOptions(confidenceThreshold: 0.75)
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: defaultLabelConfidenceThreshold)),
    // Initialize with the script for Latin-based languages. Others can be added.
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin),
    // Initialize ObjectDetector with default options (single image, base model, classification enabled, no tracking)
    // Mode.singleImage is for processing static images.
    // ClassifyObjects: true to get labels for detected objects.
    // MultipleObjects: true to detect all prominent objects.
    _objectDetector = ObjectDetector(options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      )),
    _entityExtractor = EntityExtractor(language: EntityExtractorLanguage.english);

  Future<List<ImageLabel>> getImageLabels(String imagePath) async {
    if (_isDisposed) return [];
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      // The labeler is already initialized with a confidence threshold
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      return labels;
    } catch (e) {
      print('Error processing image for labels: $e');
      return [];
    }
  }

  Future<RecognizedText> getRecognizedText(String imagePath) async {
    if (_isDisposed) return RecognizedText(text: '', blocks: []);
    final inputImage = InputImage.fromFilePath(imagePath);
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText;
    } catch (e) {
      print('Error processing image for text: $e');
      return RecognizedText(text: '', blocks: []);
    }
  }

  /// Processes an image and returns both labels and recognized text elements.
  /// This is more efficient if you need both, as it only creates InputImage once.
  Future<MlKitResult> processImage(String imagePath) async {
    if (_isDisposed) return MlKitResult(labels: [], textElements: [], objects: [], entities: []);
    final inputImage = InputImage.fromFilePath(imagePath);
    
    List<ImageLabel> labels = [];
    RecognizedText recognizedText = RecognizedText(text: '', blocks: []);
    List<DetectedObject> detectedObjects = [];

    try {
      // Labels are already filtered by confidence by the labeler's options
      labels = await _imageLabeler.processImage(inputImage);
    } catch (e) {
      print('Error processing image for labels during combined processing: $e');
    }

    try {
      recognizedText = await _textRecognizer.processImage(inputImage);
    } catch (e) {
      print('Error processing image for text during combined processing: $e');
    }

    try {
      detectedObjects = await _objectDetector.processImage(inputImage);
    } catch (e) {
      print('Error processing image for objects during combined processing: $e');
    }
    
    List<TextElement> filteredTextElements = [];
    String fullRecognizedText = ""; // For Entity Extraction
    for (TextBlock block in recognizedText.blocks) {
      fullRecognizedText += block.text + "\n"; // Concatenate text from all blocks
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          if (element.confidence != null && element.confidence! >= defaultTextConfidenceThreshold) {
            filteredTextElements.add(element);
          }
        }
      }
    }
    if (recognizedText.blocks.isNotEmpty && filteredTextElements.isEmpty) {
        print('[MlKitAnalyzer] Image $imagePath had text blocks but no elements met confidence threshold $defaultTextConfidenceThreshold');
    }

    // Filter detected objects based on their label confidence
    List<DetectedObject> filteredObjects = [];
    for (var obj in detectedObjects) {
      if (obj.labels.isNotEmpty) {
        // Consider the first label's confidence, or iterate if multiple labels per object matter
        if (obj.labels.first.confidence >= defaultObjectConfidenceThreshold) {
          filteredObjects.add(obj);
        }
      }
    }
    if (detectedObjects.isNotEmpty && filteredObjects.isEmpty) {
      print('[MlKitAnalyzer] Image $imagePath had detected objects but no labels met confidence threshold $defaultObjectConfidenceThreshold');
    }

    // 4. Get Entities from recognized text
    List<EntityAnnotation> entityAnnotations = [];
    if (fullRecognizedText.trim().isNotEmpty) {
        try {
           // Add a timeout to prevent indefinite blocking if model download hangs
           entityAnnotations = await _entityExtractor.annotateText(fullRecognizedText.trim())
              .timeout(const Duration(seconds: 15), onTimeout: () {
                print('[MlKitAnalyzer] Entity extraction timed out for image: $imagePath. Proceeding without entities for this image.');
                return []; // Return empty list on timeout
              });
        } catch (e) {
            print('[MlKitAnalyzer] Error during entity extraction for image $imagePath: $e. Proceeding without entities for this image.');
            entityAnnotations = []; // Ensure it's an empty list on other errors too
        }
    }

    return MlKitResult(labels: labels, textElements: filteredTextElements, objects: filteredObjects, entities: entityAnnotations);
  }


  Future<void> dispose() async {
    if (!_isDisposed) {
      await _imageLabeler.close();
      await _textRecognizer.close();
      await _objectDetector.close();
      await _entityExtractor.close();
      _isDisposed = true;
    }
  }
} 