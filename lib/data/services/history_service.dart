import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import '../db/app_db.dart'; // Pastikan import AppDb masuk

class HistoryService {
  static Future<void> exportTransactionHistory({
    required List<Map<String, dynamic>> data,
    required List<Map<String, dynamic>> allDataForSummary,
  }) async {
    var excel = Excel.createExcel();

    // --- 1. SETUP SHEETS ---
    // Rename sheet default (Sheet1) agar menjadi sheet paling depan
    excel.rename('Sheet1', 'Registered Items');
    Sheet sheetItem = excel['Registered Items'];
    Sheet sheet1 = excel['History Data'];
    Sheet sheet2 = excel['Summary per Item'];

    // --- STYLE DEFINITIONS ---
    // Style Hijau untuk Header Item
    CellStyle headerStyleItem = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'), // Green
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      bold: true,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle headerStyle1 = CellStyle(
      backgroundColorHex: ExcelColor.black,
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      bold: true,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle headerStyle2 = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      bold: true,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle rowWhiteStyle = CellStyle(
      backgroundColorHex: ExcelColor.white,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle rowGreyStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // --- SHEET 0: REGISTERED ITEMS (Sheet Paling Depan) ---
    List<String> itemHeaders = ["No", "Item Code", "Item Description", "Quota", "Unit"];
    for (var i = 0; i < itemHeaders.length; i++) {
      var cell = sheetItem.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(itemHeaders[i]);
      cell.cellStyle = headerStyleItem;
    }

    // Ambil data item dari database
    final List<Map<String, dynamic>> dbItems = await AppDb.instance.getAllItems();
    for (int i = 0; i < dbItems.length; i++) {
      var item = dbItems[i];
      CellStyle currentStyle = (i % 2 == 0) ? rowWhiteStyle : rowGreyStyle;
      List<CellValue> values = [
        IntCellValue(i + 1),
        TextCellValue(item['code'].toString()),
        TextCellValue(item['description'] ?? "-"),
        DoubleCellValue(double.tryParse(item['limit_value'].toString()) ?? 0.0),
        TextCellValue(item['uom'] ?? "-"),
      ];
      for (int col = 0; col < values.length; col++) {
        var cell = sheetItem.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
        cell.value = values[col];
        cell.cellStyle = currentStyle;
      }
    }
    _autoFitColumnWidth(sheetItem, itemHeaders.length, dbItems.length + 1);

    // --- SHEET 1: HISTORY DATA ---
    List<String> headers = ["No", "Item Code", "Description", "Document", "Usage", "Date"];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle1;
    }

    for (int i = 0; i < data.length; i++) {
      var tx = data[i];
      CellStyle currentStyle = (i % 2 == 0) ? rowWhiteStyle : rowGreyStyle;
      List<CellValue> values = [
        IntCellValue(i + 1),
        TextCellValue(tx['item_code'].toString()),
        TextCellValue(tx['description'] ?? "-"),
        TextCellValue(tx['doc_number'] ?? "-"),
        DoubleCellValue(double.tryParse(tx['value'].toString()) ?? 0.0),
        TextCellValue(tx['date'].toString()),
      ];
      for (int col = 0; col < values.length; col++) {
        var cell = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
        cell.value = values[col];
        cell.cellStyle = currentStyle;
      }
    }
    _autoFitColumnWidth(sheet1, headers.length, data.length + 1);

    // --- SHEET 2: SUMMARY MATRIX (Logika Matrix Anda Tetap Sama) ---
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    List<String> dateHeaders = List.generate(daysInMonth, (i) => (i + 1).toString());
    List<String> matrixHeaders = ["Item Code", "Quota", ...dateHeaders, "Quota Used", "Remaining"];
    
    for (var i = 0; i < matrixHeaders.length; i++) {
      var cell = sheet2.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(matrixHeaders[i]);
      cell.cellStyle = headerStyle2;
    }

    Map<String, Map<int, double>> matrixData = {};
    Map<String, double> itemLimits = {};

    for (var tx in allDataForSummary) {
      String code = tx['item_code'].toString();
      double val = double.tryParse(tx['value'].toString()) ?? 0.0;
      double limit = double.tryParse(tx['limit_value']?.toString() ?? '0.0') ?? 0.0;
      DateTime date = DateTime.parse(tx['date']);
      
      if (date.month == now.month && date.year == now.year) {
        itemLimits[code] = limit;
        matrixData.putIfAbsent(code, () => {});
        matrixData[code]![date.day] = (matrixData[code]![date.day] ?? 0) + val;
      }
    }

    int rowIdx = 1;
    matrixData.forEach((itemCode, dayMap) {
      CellStyle currentStyle = (rowIdx % 2 != 0) ? rowWhiteStyle : rowGreyStyle;
      double totalUsed = 0;
      double initialLimit = itemLimits[itemCode] ?? 0.0;

      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))..value = TextCellValue(itemCode)..cellStyle = currentStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))..value = DoubleCellValue(initialLimit)..cellStyle = currentStyle;

      for (int day = 1; day <= daysInMonth; day++) {
        double dayValue = dayMap[day] ?? 0.0;
        totalUsed += dayValue;
        var cellDay = sheet2.cell(CellIndex.indexByColumnRow(columnIndex: day + 1, rowIndex: rowIdx));
        cellDay.value = dayValue > 0 ? DoubleCellValue(dayValue) : TextCellValue("-");
        cellDay.cellStyle = currentStyle;
      }

      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: daysInMonth + 2, rowIndex: rowIdx))..value = DoubleCellValue(totalUsed)..cellStyle = currentStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: daysInMonth + 3, rowIndex: rowIdx))..value = DoubleCellValue(initialLimit - totalUsed)..cellStyle = currentStyle;

      rowIdx++;
    });

    _autoFitColumnWidth(sheet2, matrixHeaders.length, rowIdx);

    // --- SAVE AND OPEN ---
    var fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/History_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(fileBytes);
    await OpenFile.open(path);
  }

  static void _autoFitColumnWidth(Sheet sheet, int maxColumns, int maxRows) {
    for (int col = 0; col < maxColumns; col++) {
      double maxChars = 0;
      for (int row = 0; row < maxRows; row++) {
        var cellValue = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value;
        if (cellValue != null) {
          double length = cellValue.toString().length.toDouble();
          if (length > maxChars) maxChars = length;
        }
      }
      sheet.setColumnWidth(col, maxChars + 5.0);
    }
  }
}