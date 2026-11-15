import '../../../core/utils/ids.dart';
import '../domain/bill_draft.dart';
import '../domain/bill_repository.dart';
import '../domain/models/bill_record.dart';
import '../domain/receipt_storage.dart';

/// Thrown when asked to save a bill that is not complete or consistent.
class BillNotSavable implements Exception {
  const BillNotSavable(this.problems);

  final List<BillProblem> problems;

  @override
  String toString() => 'BillNotSavable($problems)';
}

/// Saving and deleting bills together with their receipt photos.
///
/// The database and the file system cannot share one transaction, so the order
/// is chosen to fail safe: the photo is copied first, the bill is saved in a
/// single database transaction, and if that fails the copied photo is removed.
/// The worst case is a failed save that leaves nothing behind.
class BillService {
  BillService({
    required this._bills,
    required this._storage,
    required this._clock,
    required this._newId,
  });

  final BillRepository _bills;
  final ReceiptStorage _storage;
  final Clock _clock;
  final IdGenerator _newId;

  Future<BillRecord> save(BillDraft draft) async {
    final now = _clock();
    final problems = draft.problems(now);
    if (problems.isNotEmpty) throw BillNotSavable(problems);

    final id = _newId();
    String? receiptPath;
    final image = draft.imagePath;
    if (image != null) {
      receiptPath = await _storage.save(sourcePath: image, billId: id);
    }

    try {
      final record = draft.toRecord(id: id, now: now, receiptPath: receiptPath);
      await _bills.save(record);
      return record;
    } catch (_) {
      if (receiptPath != null) await _storage.delete(receiptPath);
      rethrow;
    }
  }

  /// Deletes the bill, then its photo.
  Future<void> delete(String billId) async {
    final receipt = await _bills.delete(billId);
    if (receipt != null) await _storage.delete(receipt);
  }
}
