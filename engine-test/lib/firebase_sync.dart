import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/result_record.dart';

class FirebaseSync {
  FirebaseSync({required String databaseUrl, required this.idToken})
      : databaseUrl = _normalize(databaseUrl);

  final String databaseUrl;
  final String idToken;

  Future<void> uploadResult(String runId, ResultRecord record) async {
    final uri = _buildUri(runId, record.imageId);
    final response = await http.put(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(record.toJson()),
    );

    if (response.statusCode >= 400) {
      throw Exception(
          'Firebase upload failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<List<ResultRecord>> fetchRun(String runId,
      {String? imageId}) async {
    final uri = _buildFetchUri(runId, imageId);
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception(
          'Firebase fetch failed (${response.statusCode}): ${response.body}');
    }
    if (response.body.trim() == 'null' || response.body.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(response.body);

    if (imageId != null) {
      if (decoded is! Map<String, dynamic>) return [];
      return [
        ResultRecord.fromJson({
          ...decoded,
          'runId': runId,
          'imageId': imageId,
        })
      ];
    }

    if (decoded is! Map<String, dynamic>) return [];
    final records = <ResultRecord>[];
    decoded.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        records.add(ResultRecord.fromJson({
          ...value,
          'runId': runId,
          'imageId': key,
        }));
      }
    });
    return records;
  }

  Uri _buildUri(String runId, String imageId) {
    return Uri.parse('$databaseUrl/runs/$runId/$imageId.json?auth=$idToken');
  }

  Uri _buildFetchUri(String runId, String? imageId) {
    if (imageId != null) {
      return Uri.parse('$databaseUrl/runs/$runId/$imageId.json?auth=$idToken');
    }
    return Uri.parse('$databaseUrl/runs/$runId.json?auth=$idToken');
  }
}

String _normalize(String url) {
  if (url.endsWith('/')) return url.substring(0, url.length - 1);
  return url;
}
