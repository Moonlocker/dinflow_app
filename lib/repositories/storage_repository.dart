import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload/remoção de arquivos em buckets públicos do Supabase Storage.
class StorageRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> uploadPublic({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> remove({required String bucket, required List<String> paths}) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
  }
}
