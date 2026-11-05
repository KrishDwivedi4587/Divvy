import 'package:sqflite/sqflite.dart';

import '../../core/utils/currency.dart';
import '../../features/bills/domain/bill_repository.dart';
import '../../features/bills/domain/engine/money.dart';
import '../../features/bills/domain/models/bill.dart';
import '../../features/bills/domain/models/bill_record.dart';
import '../../features/people/domain/saved_person.dart';

class SqliteBillRepository implements BillRepository {
  SqliteBillRepository(this._db);

  final Database _db;

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String s) {
    final parts = s.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  @override
  Future<void> save(BillRecord r) async {
    // One transaction: if any insert fails (a bad foreign key, a constraint,
    // an exception thrown mid-way) every earlier insert is rolled back.
    await _db.transaction((txn) async {
      await txn.insert('bills', {
        'id': r.id,
        'title': r.title,
        'merchant': r.merchant,
        'bill_date': _dateText(r.billDate),
        'created_at': r.createdAt.toUtc().toIso8601String(),
        'currency': r.currency.code,
        'split_mode': r.splitMode.wireName,
        'receipt_path': r.receiptPath,
        'ocr_text': r.ocrText,
        // Set after the participants exist; the column references them.
        'payer_participant_id': null,
        'items_subtotal': r.itemsSubtotal.value,
        'grand_total': r.grandTotal.value,
        'unassigned_total': r.unassignedTotal.value,
      });

      for (var i = 0; i < r.participants.length; i++) {
        final p = r.participants[i];
        await txn.insert('bill_participants', {
          'id': p.id,
          'bill_id': r.id,
          'person_id': p.personId,
          'name': p.name,
          'initials': p.initials,
          'color_index': p.colorIndex,
          'position': i,
          'subtotal': r.participantSubtotals[p.id]?.value ?? 0,
          'total': r.participantTotals[p.id]?.value ?? 0,
          'settled_at': p.settledAt?.toUtc().toIso8601String(),
        });
      }

      for (var i = 0; i < r.items.length; i++) {
        final item = r.items[i];
        await txn.insert('bill_items', {
          'id': item.id,
          'bill_id': r.id,
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice.value,
          'line_total': item.lineTotal.value,
          'source': item.source.wireName,
          'ocr_confidence': item.ocrConfidence,
          'raw_text': item.rawText,
          'position': i,
        });
        for (final participantId in r.assignments[item.id] ?? const []) {
          await txn.insert('item_allocations', {
            'item_id': item.id,
            'participant_id': participantId,
          });
        }
      }

      for (final a in r.adjustments) {
        await txn.insert('bill_adjustments', {
          'id': a.id,
          'bill_id': r.id,
          'label': a.label,
          'kind': a.kind.wireName,
          'mode': a.mode.wireName,
          'value': a.value,
          'position': a.order,
          'base': a.base.wireName,
          'is_negative': a.isNegative ? 1 : 0,
        });
      }

      if (r.payerParticipantId != null) {
        await txn.update(
          'bills',
          {'payer_participant_id': r.payerParticipantId},
          where: 'id = ?',
          whereArgs: [r.id],
        );
      }
    });
  }

  @override
  Future<BillRecord?> byId(String id) async {
    final bills = await _db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (bills.isEmpty) return null;
    final b = bills.single;

    final participantRows = await _db.query(
      'bill_participants',
      where: 'bill_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final itemRows = await _db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final allocationRows = await _db.rawQuery(
      'SELECT a.item_id, a.participant_id FROM item_allocations a '
      'JOIN bill_items i ON i.id = a.item_id WHERE i.bill_id = ?',
      [id],
    );
    final adjustmentRows = await _db.query(
      'bill_adjustments',
      where: 'bill_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );

    final assignments = <String, List<String>>{
      for (final r in itemRows) r['id']! as String: <String>[],
    };
    for (final r in allocationRows) {
      assignments[r['item_id']! as String]!.add(r['participant_id']! as String);
    }

    return BillRecord(
      id: b['id']! as String,
      title: b['title']! as String,
      merchant: b['merchant'] as String?,
      billDate: _parseDate(b['bill_date']! as String),
      createdAt: DateTime.parse(b['created_at']! as String),
      currency: Currency.fromCode(b['currency'] as String?),
      splitMode: SplitMode.fromWire(b['split_mode']! as String),
      receiptPath: b['receipt_path'] as String?,
      ocrText: b['ocr_text'] as String?,
      payerParticipantId: b['payer_participant_id'] as String?,
      itemsSubtotal: Paise(b['items_subtotal']! as int),
      grandTotal: Paise(b['grand_total']! as int),
      unassignedTotal: Paise(b['unassigned_total']! as int),
      participants: [for (final r in participantRows) _participant(r)],
      participantSubtotals: {
        for (final r in participantRows)
          r['id']! as String: Paise(r['subtotal']! as int),
      },
      participantTotals: {
        for (final r in participantRows)
          r['id']! as String: Paise(r['total']! as int),
      },
      items: [for (final r in itemRows) _item(r)],
      assignments: assignments,
      adjustments: [for (final r in adjustmentRows) _adjustment(r)],
    );
  }

  BillParticipant _participant(Map<String, Object?> r) {
    return BillParticipant(
      id: r['id']! as String,
      personId: r['person_id'] as String?,
      name: r['name']! as String,
      initials: r['initials']! as String,
      colorIndex: r['color_index']! as int,
      settledAt: r['settled_at'] == null
          ? null
          : DateTime.parse(r['settled_at']! as String),
    );
  }

  BillItem _item(Map<String, Object?> r) {
    return BillItem(
      id: r['id']! as String,
      name: r['name']! as String,
      quantity: r['quantity']! as int,
      unitPrice: Paise(r['unit_price']! as int),
      lineTotal: Paise(r['line_total']! as int),
      source: ItemSource.fromWire(r['source']! as String),
      ocrConfidence: (r['ocr_confidence'] as num?)?.toDouble(),
      rawText: r['raw_text'] as String?,
    );
  }

  Adjustment _adjustment(Map<String, Object?> r) {
    return Adjustment(
      id: r['id']! as String,
      label: r['label']! as String,
      kind: AdjustmentKind.fromWire(r['kind']! as String),
      mode: AdjustmentMode.fromWire(r['mode']! as String),
      value: r['value']! as int,
      order: r['position']! as int,
      base: AdjustmentBase.fromWire(r['base']! as String),
      isNegative: (r['is_negative']! as int) == 1,
    );
  }

  /// People who still owe the payer: not the payer, not yet settled.
  static const _unsettledCount =
      '(SELECT COUNT(*) FROM bill_participants p WHERE p.bill_id = b.id '
      'AND b.payer_participant_id IS NOT NULL '
      'AND p.id != b.payer_participant_id AND p.settled_at IS NULL)';

  /// Escapes LIKE wildcards with `!` so a search for "50%" matches the text
  /// "50%" instead of everything starting with 50.
  static String _like(String q) {
    final escaped = q
        .replaceAll('!', '!!')
        .replaceAll('%', '!%')
        .replaceAll('_', '!_');
    return '%$escaped%';
  }

  Future<List<BillSummary>> _summaries(
    String where,
    List<Object?> args, {
    int? limit,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT b.id, b.title, b.merchant, b.bill_date, b.currency, '
      'b.grand_total, b.receipt_path, $_unsettledCount AS unsettled '
      'FROM bills b ${where.isEmpty ? '' : 'WHERE $where'} '
      'ORDER BY b.bill_date DESC, b.created_at DESC, b.id DESC '
      '${limit == null ? '' : 'LIMIT $limit'}',
      args,
    );
    if (rows.isEmpty) return const [];

    final ids = [for (final r in rows) r['id']! as String];
    final marks = List.filled(ids.length, '?').join(',');
    final nameRows = await _db.rawQuery(
      'SELECT bill_id, name FROM bill_participants '
      'WHERE bill_id IN ($marks) ORDER BY bill_id, position',
      ids,
    );
    final names = <String, List<String>>{};
    for (final r in nameRows) {
      names
          .putIfAbsent(r['bill_id']! as String, () => [])
          .add(r['name']! as String);
    }

    return [
      for (final r in rows)
        BillSummary(
          id: r['id']! as String,
          title: r['title']! as String,
          merchant: r['merchant'] as String?,
          billDate: _parseDate(r['bill_date']! as String),
          currency: Currency.fromCode(r['currency'] as String?),
          grandTotal: Paise(r['grand_total']! as int),
          participantNames: names[r['id']! as String] ?? const [],
          unsettledCount: r['unsettled']! as int,
          hasReceipt: r['receipt_path'] != null,
        ),
    ];
  }

  @override
  Future<List<BillSummary>> list({
    String query = '',
    BillStatusFilter status = BillStatusFilter.all,
    int? limit,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];

    final q = query.trim();
    if (q.isNotEmpty) {
      clauses.add(
        "(b.title LIKE ? ESCAPE '!' OR b.merchant LIKE ? ESCAPE '!' "
        'OR EXISTS (SELECT 1 FROM bill_participants p WHERE p.bill_id = b.id '
        "AND p.name LIKE ? ESCAPE '!'))",
      );
      args.addAll([_like(q), _like(q), _like(q)]);
    }
    switch (status) {
      case BillStatusFilter.all:
        break;
      case BillStatusFilter.unsettled:
        clauses.add('$_unsettledCount > 0');
      case BillStatusFilter.settled:
        clauses.add('$_unsettledCount = 0');
    }
    return _summaries(clauses.join(' AND '), args, limit: limit);
  }

  @override
  Future<List<BillSummary>> forPerson(String personId) {
    return _summaries(
      'EXISTS (SELECT 1 FROM bill_participants p '
      'WHERE p.bill_id = b.id AND p.person_id = ?)',
      [personId],
    );
  }

  @override
  Future<void> rename(String billId, String title) async {
    await _db.update(
      'bills',
      {'title': title},
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  @override
  Future<void> setSettled(
    String participantId, {
    required bool settled,
    required DateTime at,
  }) async {
    await _db.update(
      'bill_participants',
      {'settled_at': settled ? at.toUtc().toIso8601String() : null},
      where: 'id = ?',
      whereArgs: [participantId],
    );
  }

  @override
  Future<String?> delete(String billId) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'bills',
        columns: ['receipt_path'],
        where: 'id = ?',
        whereArgs: [billId],
      );
      if (rows.isEmpty) return null;
      await txn.delete('bills', where: 'id = ?', whereArgs: [billId]);
      return rows.single['receipt_path'] as String?;
    });
  }

  @override
  Future<int> count() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM bills'),
        ) ??
        0;
  }

  @override
  Future<List<PersonBalance>> balances() async {
    final selfRows = await _db.query(
      'people',
      columns: ['id'],
      where: 'is_self = 1',
    );
    if (selfRows.isEmpty) return const [];
    final selfId = selfRows.single['id']! as String;

    // Unsettled amounts where the account holder paid: others owe them.
    final owedToMe = await _db.rawQuery(
      'SELECT p.person_id AS person_id, b.currency AS currency, '
      'SUM(p.total) AS amount FROM bill_participants p '
      'JOIN bills b ON b.id = p.bill_id '
      'JOIN bill_participants payer ON payer.id = b.payer_participant_id '
      'WHERE payer.person_id = ? AND p.id != payer.id '
      'AND p.settled_at IS NULL AND p.person_id IS NOT NULL '
      'GROUP BY p.person_id, b.currency',
      [selfId],
    );

    // Unsettled amounts where someone else paid: the account holder owes them.
    final iOwe = await _db.rawQuery(
      'SELECT payer.person_id AS person_id, b.currency AS currency, '
      'SUM(p.total) AS amount FROM bill_participants p '
      'JOIN bills b ON b.id = p.bill_id '
      'JOIN bill_participants payer ON payer.id = b.payer_participant_id '
      'WHERE p.person_id = ? AND p.id != payer.id '
      'AND p.settled_at IS NULL AND payer.person_id IS NOT NULL '
      'GROUP BY payer.person_id, b.currency',
      [selfId],
    );

    final net = <String, Map<Currency, int>>{};
    void add(List<Map<String, Object?>> rows, int sign) {
      for (final r in rows) {
        final person = r['person_id']! as String;
        if (person == selfId) continue;
        final currency = Currency.fromCode(r['currency'] as String?);
        final byCurrency = net.putIfAbsent(person, () => {});
        byCurrency[currency] =
            (byCurrency[currency] ?? 0) + sign * (r['amount']! as int);
      }
    }

    add(owedToMe, 1);
    add(iOwe, -1);

    return [
      for (final e in net.entries)
        PersonBalance(e.key, {
          for (final c in e.value.entries) c.key: Paise(c.value),
        }),
    ];
  }

  @override
  Future<List<ActivityEvent>> recentActivity({int limit = 8}) async {
    final rows = await _db.rawQuery(
      "SELECT 'bill' AS kind, b.id AS bill_id, b.title AS title, "
      'b.currency AS currency, NULL AS person_name, '
      'b.grand_total AS amount, b.created_at AS at FROM bills b '
      'UNION ALL '
      "SELECT 'paid', b.id, b.title, b.currency, p.name, p.total, p.settled_at "
      'FROM bill_participants p JOIN bills b ON b.id = p.bill_id '
      'WHERE p.settled_at IS NOT NULL '
      'AND p.id != b.payer_participant_id '
      'ORDER BY at DESC LIMIT ?',
      [limit],
    );
    return [
      for (final r in rows)
        ActivityEvent(
          kind: r['kind'] == 'paid'
              ? ActivityKind.paidBack
              : ActivityKind.billCreated,
          billId: r['bill_id']! as String,
          billTitle: r['title']! as String,
          currency: Currency.fromCode(r['currency'] as String?),
          amount: Paise(r['amount']! as int),
          at: DateTime.parse(r['at']! as String),
          personName: r['person_name'] as String?,
        ),
    ];
  }
}
