import 'dart:io';

import 'package:path/path.dart' as p;

import '../../features/bills/domain/receipt_storage.dart';

/// Keeps bill photos under `<root>/receipts/`.
class LocalReceiptStorage implements ReceiptStorage {
  LocalReceiptStorage(this._root);

  final Directory _root;

  static const String folder = 'receipts';

  Directory get _receipts => Directory(p.join(_root.path, folder));

  /// Rejects absolute paths and anything that climbs out of the receipts
  /// folder. Stored paths come from our own database, but a path is a path:
  /// it is checked before it is used to read or delete a file.
  bool _isSafe(String relative) {
    if (relative.isEmpty || p.isAbsolute(relative)) return false;
    final parts = relative.split('/');
    if (parts.any((s) => s == '..' || s.isEmpty)) return false;
    return parts.first == folder;
  }

  @override
  Future<String> save({
    required String sourcePath,
    required String billId,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Photo not found', sourcePath);
    }
    await _receipts.create(recursive: true);

    final extension = p.extension(sourcePath).toLowerCase();
    final name = '$billId${extension.isEmpty ? '.jpg' : extension}';
    final target = File(p.join(_receipts.path, name));

    // Copy to a temporary name first, then rename, so a crash mid-copy never
    // leaves a half-written photo under a name the database will point at.
    final partial = File('${target.path}.part');
    await source.copy(partial.path);
    await partial.rename(target.path);
    return '$folder/$name';
  }

  @override
  Future<String?> resolve(String relativePath) async {
    if (!_isSafe(relativePath)) return null;
    final file = File(p.joinAll([_root.path, ...relativePath.split('/')]));
    return await file.exists() ? file.path : null;
  }

  @override
  Future<bool> delete(String relativePath) async {
    if (!_isSafe(relativePath)) return false;
    final file = File(p.joinAll([_root.path, ...relativePath.split('/')]));
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<void> deleteAll() async {
    if (await _receipts.exists()) await _receipts.delete(recursive: true);
  }
}
