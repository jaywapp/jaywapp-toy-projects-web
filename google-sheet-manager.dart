import 'dart:ffi';
import 'package:be_my_colleague/Service/GoogleHttpClient.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:google_sign_in/google_sign_in.dart';
import 'google-sheet-range.dart';

class GoogleSheetManager {
  GoogleSignInAccount? account;
  String sheetID = '';

  GoogleSheetManager(GoogleSignInAccount? googleAccount, String googleSheetID) {
    account = googleAccount;
    sheetID = googleSheetID;
  }

  Future<sheets.SheetsApi> GetApi() async {
    final headers = await account?.authHeaders ?? new Map<String, String>();
    final authenticatedClient = GoogleHttpClient(headers);
    final sheetsApi = sheets.SheetsApi(authenticatedClient);

    return sheetsApi;
  }

  Future<List<List<Object?>>?> GetActiveValues(String sheetName) async {
    if (account == null) return List.empty();

    final sheetsApi = await GetApi();

    try {
      var sheets = sheetsApi.spreadsheets;

      final spreadsheet = await sheetsApi.spreadsheets.get(sheetID);
      final sheet = spreadsheet.sheets!
          .firstWhere((sheet) => sheet.properties!.title == sheetName);

      final int rowCount = sheet.properties!.gridProperties!.rowCount!;
      final int colCount = sheet.properties!.gridProperties!.columnCount!;

      final range =
          GoogleSheetRange.Create(sheetName, 1, 1, colCount, rowCount);
      final rangeStr = range.toString();

      var response = await sheets.values.get(sheetID, rangeStr);
      var values = response.values;

      return values;
    } catch (e) {
      return List.empty();
    }
  }

  Future<List<List<Object?>>?> GetRows(
      String sheetName, Bool Function(List<Object?>) checker) async {
    List<List<Object?>> result = [];
    var values = await GetActiveValues(sheetName) ?? List.empty();

    for (int i = 0; i < values.length; i++) {
      var row = values[i];

      if (checker(row) == true) {
        result.add(row);
      }
    }

    return result;
  }

  Future<void> Update(String sheetName, int index, List<Object?> row) async {
    if (account == null) return;

    final sheetsApi = await GetApi();

    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(sheetID);
      final sheet = spreadsheet.sheets!
          .firstWhere((sheet) => sheet.properties!.title == sheetName);
      final int colCount = sheet.properties!.gridProperties!.columnCount!;

      var range = GoogleSheetRange.Create(sheetName, 1, index, colCount, index)
          .toString();

      List<List<Object?>> values = [];
      values.add(row);

      var valueRange = sheets.ValueRange(
        range: range,
        values: values,
      );
      await sheetsApi.spreadsheets.values
          .update(valueRange, sheetID, range, valueInputOption: 'RAW');
    } catch (e) {}
  }

  Future<List<List<Object?>>?> GetRowsByCellValue(
      String sheetName, int columnIndex, Object value) async {
    List<List<Object?>> result = [];
    var values = await GetActiveValues(sheetName) ?? List.empty();
    var idx = columnIndex - 1;

    for (int i = 0; i < values.length; i++) {
      var row = values[i];

      if (row.length <= columnIndex && row[idx] == value) {
        result.add(row);
      }
    }

    return result;
  }

  Future<int> GetIndex(String sheetName, int columnIndex, Object? value) async {
    if (value == null) return -1;

    var values = await GetActiveValues(sheetName) ?? List.empty();
    var idx = columnIndex - 1;

    for (int i = 0; i < values.length; i++) {
      var row = values[i];

      if (row.length > columnIndex) {
        if (row[idx] == value) {
          return i + 1;
        }
      }
    }

    return -1;
  }

   Future<int> GetLastIndex(String sheetName) async {
    var values = await GetActiveValues(sheetName) ?? List.empty();
    return values.length + 1;
  }

  Future<void> Appand(String sheetName, List<Object?> row) async{
    
    if (account == null) return;
    
    final sheetsApi = await GetApi();
    var index = await GetLastIndex(sheetName);

    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(sheetID);
      final sheet = spreadsheet.sheets!
          .firstWhere((sheet) => sheet.properties!.title == sheetName);
      final int colCount = sheet.properties!.gridProperties!.columnCount!;

      var range = GoogleSheetRange.Create(sheetName, 1, index, colCount, index)
          .toString();

      List<List<Object?>> values = [];
      values.add(row);

      var valueRange = sheets.ValueRange(
        range: range,
        values: values,
      );
      await sheetsApi.spreadsheets.values
          .update(valueRange, sheetID, range, valueInputOption: 'RAW');
    } catch (e) {}

  }
}
