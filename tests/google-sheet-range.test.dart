import '../src/jaywapp-dart-google-sheet/google-sheet-range.dart';

void expectEqual(Object actual, Object expected) {
  if (actual != expected) throw StateError('Expected $expected, got $actual');
}

void main() {
  final cases = <int, String>{-1: '', 0: '', 1: 'A', 26: 'Z', 27: 'AA',
    52: 'AZ', 53: 'BA', 702: 'ZZ', 703: 'AAA', 18278: 'ZZZ'};
  for (final entry in cases.entries) {
    expectEqual(GoogleSheetRange.GetColumnLetter(entry.key), entry.value);
  }
  expectEqual(GoogleSheetRange('Sheet1', 'A', 1, 'Z', 10).toString(), 'Sheet1!A1:Z10');
  expectEqual(GoogleSheetRange.Create('Data', 27, 2, 703, 99).toString(), 'Data!AA2:AAA99');
  expectEqual(GoogleSheetRange('', 'A', 1, 'A', 1).toString(), '!A1:A1');
  print('PASS 13 GoogleSheetRange conversion and formatting cases');
}
