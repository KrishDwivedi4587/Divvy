import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/settlement.dart';

Paise p(int n) => Paise(n);

Person person(String id, [String? name]) {
  final n = name ?? id;
  return Person(
    id: id,
    name: n,
    colorIndex: 0,
    initials: n.substring(0, n.length < 2 ? n.length : 2).toUpperCase(),
  );
}

BillItem item(String id, String name, int lineTotal, {int quantity = 1}) {
  return BillItem(
    id: id,
    name: name,
    quantity: quantity,
    unitPrice: Paise(lineTotal ~/ quantity),
    lineTotal: Paise(lineTotal),
  );
}

Adjustment adjustment(
  String id, {
  required AdjustmentMode mode,
  required int value,
  required int order,
  AdjustmentKind kind = AdjustmentKind.tax,
  AdjustmentBase base = AdjustmentBase.itemsSubtotal,
  bool isNegative = false,
  String? label,
}) {
  return Adjustment(
    id: id,
    label: label ?? id,
    kind: kind,
    mode: mode,
    value: value,
    order: order,
    base: base,
    isNegative: isNegative,
  );
}

Bill bill({
  List<Person> people = const [],
  List<BillItem> items = const [],
  Map<String, List<String>> assignments = const {},
  List<Adjustment> adjustments = const [],
}) {
  return Bill(
    id: 'bill-1',
    title: 'Test bill',
    createdAt: DateTime.utc(2026, 9, 1),
    people: people,
    items: items,
    assignments: assignments,
    adjustments: adjustments,
  );
}

int totalOf(Settlement s) => s.perPerson.fold(0, (a, x) => a + x.total.value);

Map<String, PersonSettlement> byId(Settlement s) => {
  for (final x in s.perPerson) x.personId: x,
};
