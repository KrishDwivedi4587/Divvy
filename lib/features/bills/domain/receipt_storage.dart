/// Where bill photos are kept, as the rest of the app sees it.
abstract interface class ReceiptStorage {
  /// Copies the photo at [sourcePath] into app storage for [billId] and returns
  /// its path **relative to the storage root**. Only that relative path is ever
  /// saved: the absolute location of an iOS app container changes between
  /// installs and updates, which would orphan every stored receipt.
  Future<String> save({required String sourcePath, required String billId});

  /// The absolute path for a stored relative path, or null if the file is gone
  /// or the path is not a safe relative path.
  Future<String?> resolve(String relativePath);

  /// Deletes a stored photo. A missing file is not an error. Returns whether a
  /// file was actually removed.
  Future<bool> delete(String relativePath);

  /// Deletes every stored photo.
  Future<void> deleteAll();
}
