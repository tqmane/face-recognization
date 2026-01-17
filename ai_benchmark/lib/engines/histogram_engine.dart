import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'inference_engine.dart';

class HistogramEngine implements InferenceEngine {
  @override
  String get name => 'Color Histogram (CPU)';

  @override
  Future<void> initialize() async {
    // No initialization needed
  }

  @override
  void dispose() {
    // Nothing to dispose
  }

  @override
  Future<double> compareImages(String imagePath1, String imagePath2) async {
    final img1 = await _loadImage(imagePath1);
    final img2 = await _loadImage(imagePath2);

    if (img1 == null || img2 == null) return 0.0;

    final hist1 = _calculateHistogram(img1);
    final hist2 = _calculateHistogram(img2);

    return _cosineSimilarity(hist1, hist2);
  }

  Future<img.Image?> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      print('Error loading image: $path, $e');
      return null;
    }
  }

  List<double> _calculateHistogram(img.Image image) {
    // 8 bins per channel (8x8x8 = 512 dimensions)
    final bins = List<double>.filled(512, 0.0);
    
    for (final pixel in image) {
      final r = pixel.r.toInt() >> 5; // 0-7
      final g = pixel.g.toInt() >> 5;
      final b = pixel.b.toInt() >> 5;
      
      final index = (r << 6) | (g << 3) | b;
      bins[index]++;
    }

    // Normalize
    final totalPixels = image.width * image.height;
    for (int i = 0; i < bins.length; i++) {
      bins[i] /= totalPixels;
    }
    
    return bins;
  }

  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      normA += vec1[i] * vec1[i];
      normB += vec2[i] * vec2[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
