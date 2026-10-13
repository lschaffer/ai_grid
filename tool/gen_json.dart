// ignore_for_file: avoid_print
import 'dart:io';
import 'package:ai_grid/src/data/sample_dataset_1000.dart';

void main() {
  final json = SampleSalesData.generateJson(count: 1000);
  File('example/assets/sales_1000.json').writeAsStringSync(json);
  print('Wrote sales_1000.json (${json.length} bytes)');
}
