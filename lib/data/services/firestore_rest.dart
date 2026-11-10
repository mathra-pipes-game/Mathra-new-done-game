import 'dart:convert';
import 'dart:io';

import 'package:pipes/data/services/firebase_config.dart';

/// Tiny Firestore REST helper shared by the shop / license code.
///
/// Every response carries a `Date` header from Google's servers. We use it
/// to compute [serverOffsetMs], so subscription expiry is checked against
/// SERVER time and not the phone clock (changing the phone date does not
/// extend a plan).
class Fs {
  Fs._();


  static int serverOffsetMs = 0;
  static int get nowMs => DateTime.now().millisecondsSinceEpoch + serverOffsetMs;

  static String get _base =>
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents';

  static Future<dynamic> _send(String method, String url, [Object? body]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.openUrl(method, Uri.parse(url));
      req.headers.contentType = ContentType.json;
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      final date = res.headers.value('date');
      if (date != null) {
        try {
          serverOffsetMs =
              HttpDate.parse(date).millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
        } catch (_) {}
      }
      if (res.statusCode == 404) return null;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('Firestore ${res.statusCode}: $text');
      }
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  /// Returns the document's `fields` map, or null if it does not exist.
  static Future<Map<String, dynamic>?> getFields(String path) async {
    if (!FirebaseConfig.isConfigured) return null;
    final r = await _send('GET', '$_base/$path?key=${FirebaseConfig.apiKey}');
    if (r == null) return null;
    return ((r as Map)['fields'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  }

  /// Create (or overwrite the listed fields of) a document.
  static Future<void> patch(String path, Map<String, Map<String, dynamic>> fields) {
    final mask = fields.keys.map((f) => 'updateMask.fieldPaths=$f').join('&');
    return _send('PATCH', '$_base/$path?$mask&key=${FirebaseConfig.apiKey}', {'fields': fields});
  }

  /// Create a NEW document with a chosen id (fails if it already exists).
  static Future<void> create(
      String collection, String id, Map<String, Map<String, dynamic>> fields) {
    return _send(
      'POST',
      '$_base/$collection?documentId=$id&key=${FirebaseConfig.apiKey}',
      {'fields': fields},
    );
  }

  /// Atomically adds 1 to a counter field (used for website/app visits).
  static Future<void> increment(String path, String field) {
    return _send('POST', '$_base:commit?key=${FirebaseConfig.apiKey}', {
      'writes': [
        {
          'transform': {
            'document': 'projects/${FirebaseConfig.projectId}/databases/(default)/documents/$path',
            'fieldTransforms': [
              {
                'fieldPath': field,
                'increment': {'integerValue': '1'}
              }
            ],
          }
        }
      ],
    });
  }

  // ── encode / decode helpers ──
  static Map<String, dynamic> s(String v) => {'stringValue': v};
  static Map<String, dynamic> i(int v) => {'integerValue': '$v'};
  static Map<String, dynamic> b(bool v) => {'booleanValue': v};

  static String str(Map? f, String k, [String d = '']) {
    final v = f?[k];
    return (v is Map && v['stringValue'] != null) ? '${v['stringValue']}' : d;
  }

  static bool boolv(Map? f, String k, [bool d = false]) {
    final v = f?[k];
    return (v is Map && v['booleanValue'] != null) ? v['booleanValue'] == true : d;
  }

  static int intv(Map? f, String k, [int d = 0]) {
    final v = f?[k];
    return (v is Map && v['integerValue'] != null) ? (int.tryParse('${v['integerValue']}') ?? d) : d;
  }
}
