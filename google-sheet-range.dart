class GoogleSheetRange {
  String sheetName = '';
  String startCol = 'A';
  String endCol = 'A';
  int startRow = 1;
  int endRow = 1;

  GoogleSheetRange(
    String sheetName, 
    String startCol, int startRow,
    String endCol, int endRow) {
    this.sheetName = sheetName;
    this.startCol = startCol;
    this.startRow = startRow;
    this.endCol = endCol;
    this.endRow = endRow;
  }

  GoogleSheetRange.Create(String sheetName, int startColIdx, int startRow, int endColIdx, int endRow){
    this.sheetName = sheetName;
    this.startCol = GetColumnLetter(startColIdx);
    this.startRow = startRow;
    this.endCol = GetColumnLetter(endColIdx);
    this.endRow = endRow;
  }

  @override
  String toString() {
    return '$sheetName!$startCol$startRow:$endCol$endRow';
  }

  static String GetColumnLetter(int index) {
    String columnLetter = '';
    int tempIndex = index; // Google Sheets 열 번호는 1부터 시작

    while (tempIndex > 0) {
      tempIndex -= 1;
      int remainder = tempIndex % 26;
      columnLetter = String.fromCharCode(65 + remainder) + columnLetter;
      tempIndex = tempIndex ~/ 26;
    }

    return columnLetter;
  }
}
