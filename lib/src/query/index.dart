export "query.dart";

class Order {
  /// Reverts the order from ascending (default) to descending.
  static final descending = 1;

  /// Makes upper case letters (e.g. "Z") be sorted before lower case letters (e.g. "a").
  /// If not specified, the default is case insensitive for ASCII characters.
  static final caseSensitive = 2;

  /// For scalars only: changes the comparison to unsigned (default is signed).
  static final unsigned = 4;

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  static final nullsLast = 8;

  /// null values should be treated equal to zero (scalars only).
  static final nullsAsZero = 16;
}
