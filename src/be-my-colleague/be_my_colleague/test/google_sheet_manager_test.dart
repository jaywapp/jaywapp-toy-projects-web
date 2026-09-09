import 'package:flutter_test/flutter_test.dart';
import 'package:jaywapp_google_sheet/google_sheet_manager.dart';

class MemorySheetManager extends GoogleSheetManager {
  final List<List<Object?>> rows;
  MemorySheetManager(this.rows) : super(null, '');
  @override
  Future<List<List<Object?>>?> GetActiveValues(String sheetName) async => rows;
}

void main() {
  test('null account reads and writes do not contact Sheets', () async {
    final manager = GoogleSheetManager(null, '');
    expect(await manager.GetActiveValues('Data'), isEmpty);
    await manager.Update('Data', 1, []);
    await manager.Appand('Data', []);
  });
  test('predicate filtering retains matching rows in order', () async {
    final manager = MemorySheetManager([['a', 1], ['b', 2], ['a', 3]]);
    expect(await manager.GetRows('Data', (row) => row.first == 'a'), [['a', 1], ['a', 3]]);
  });
  test('column matching includes the last column and skips short rows', () async {
    final manager = MemorySheetManager([[], ['short'], ['a', 2], ['b', 2, 'tail']]);
    expect(await manager.GetRowsByCellValue('Data', 2, 2), [['a', 2], ['b', 2, 'tail']]);
  });
  test('index lookup includes the last column and returns a one-based row', () async {
    final manager = MemorySheetManager([[], ['target']]);
    expect(await manager.GetIndex('Data', 1, 'target'), 2);
    expect(await manager.GetIndex('Data', 1, null), -1);
    expect(await manager.GetIndex('Data', 1, 'missing'), -1);
  });
  test('nonpositive column indices return no matches', () async {
    final manager = MemorySheetManager([['target']]);
    for (final index in [0, -1]) {
      expect(await manager.GetRowsByCellValue('Data', index, 'target'), isEmpty);
      expect(await manager.GetIndex('Data', index, 'target'), -1);
    }
  });
  test('empty sheet appends at first row', () async {
    expect(await MemorySheetManager([]).GetLastIndex('Data'), 1);
    expect(await MemorySheetManager([['a'], ['b']]).GetLastIndex('Data'), 3);
  });
}
