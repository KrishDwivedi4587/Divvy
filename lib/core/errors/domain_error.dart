/// Reasons the calculation engine rejects structurally invalid data.
enum DomainErrorCode {
  notAnInteger('NOT_AN_INTEGER'),
  notFinite('NOT_FINITE'),
  negativeAmount('NEGATIVE_AMOUNT'),
  unsafeMagnitude('UNSAFE_MAGNITUDE'),
  invalidBasisPoints('INVALID_BASIS_POINTS'),
  duplicateId('DUPLICATE_ID'),
  unknownPerson('UNKNOWN_PERSON'),
  unknownItem('UNKNOWN_ITEM'),
  noPeople('NO_PEOPLE'),
  invalidQuantity('INVALID_QUANTITY');

  const DomainErrorCode(this.wireName);

  /// The identifier the original TypeScript engine used for this code.
  final String wireName;
}

/// Thrown for structurally invalid domain data: a programmer or data-integrity
/// error, not something a user can type.
///
/// The engine deliberately uses two error strategies:
///  * Invalid *domain data* throws [DomainError]. It means a bug upstream, and
///    failing loudly beats silently producing wrong money.
///  * Invalid *user input* (see `parseAmount`) returns a typed result, because
///    the UI has to render an inline message rather than crash.
class DomainError implements Exception {
  const DomainError(this.code, this.message);

  final DomainErrorCode code;
  final String message;

  @override
  String toString() => 'DomainError(${code.wireName}): $message';
}
