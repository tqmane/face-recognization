import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'engine.dart';

class MockEngine implements InferenceEngine {
  MockEngine({this.provider = 'cpu'});

  final String provider;
  final _random = Random();

  @override
  String get name => 'mock';

  @override
  Future<InferenceResult> infer(Uint8List imageBytes) async {
    final delay = 5 + _random.nextInt(20);
    await Future<void>.delayed(Duration(milliseconds: delay));
    return InferenceResult(
      predictions: [Prediction(label: 'mock', score: 1.0)],
      latencyMs: delay,
      provider: provider,
      note: 'placeholder result; replace with real engine',
    );
  }
}
